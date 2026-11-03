import Accelerate
import CoreML
import Foundation
import SQLite3
import Tokenizers

/// Metin kolu: arama cümlesini görüntü vektörleriyle aynı uzaya çevirir.
/// SigLIP küçük harfle eğitildi; 64 parçaya kesilir ya da <pad> (0) ile doldurulur, sonuna <eos> eklenir (tokenizer ayarı).
public final class MetinModeli {
    let model: MLModel
    let tok: Tokenizer
    static let uzunluk = 64

    /// klasor: metin.mlpackage ve tokenizer.json / tokenizer_config.json'ın bulunduğu model klasörü.
    public init(klasor: URL, onbellek: URL) async throws {
        model = try GoruntuModeli.yukle(paket: klasor.appendingPathComponent("metin.mlpackage"), onbellek: onbellek)
        tok = try await AutoTokenizer.from(modelFolder: klasor)
    }

    public func parcalar(_ metin: String) -> [Int] {
        var ids = Array(tok.encode(text: metin.lowercased()).prefix(Self.uzunluk))
        ids += Array(repeating: 0, count: Self.uzunluk - ids.count)
        return ids
    }

    public func vektor(_ metin: String) throws -> [Float] {
        let girdi = try MLMultiArray(shape: [1, NSNumber(value: Self.uzunluk)], dataType: .int32)
        for (i, id) in parcalar(metin).enumerated() { girdi[i] = NSNumber(value: id) }
        let c = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["input_ids": girdi]))
        guard let v = c.featureValue(for: "vektor")?.multiArrayValue else { throw GoruntuHatasi.okunamadi }
        return GoruntuModeli.birimVektor(v)
    }
}

/// Dizindeki bütün vektörler bellekte (yarım hassasiyet: 200 bin kare ~0,46 GB); arama düz tarama.
/// ponytail: 200 bin karede tek arama yaklaşık 0,1-0,3 sn; milyonlarca karede yaklaşık-komşu dizini gerekir.
public final class AramaDizini: @unchecked Sendable { // açıldıktan sonra değişmez
    public let kimlikler: [String]
    let sira: [String: Int]
    let vektorler: [Float16] // satır satır, her satır `boyut` sayı
    public let boyut: Int

    public init(_ dizin: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(dizin.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK else {
            throw NSError(domain: "Arama", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dizin açılamadı: \(dizin.path)"])
        }
        defer { sqlite3_close(db) }
        var s: OpaquePointer?
        defer { sqlite3_finalize(s) }
        guard sqlite3_prepare_v2(db, "SELECT uuid, vektor FROM kare WHERE durum='tamam'", -1, &s, nil) == SQLITE_OK else {
            throw NSError(domain: "Arama", code: 2, userInfo: [NSLocalizedDescriptionKey: "Dizin okunamadı: \(String(cString: sqlite3_errmsg(db)))"])
        }
        var k: [String] = [], v: [Float16] = [], b = 0
        while sqlite3_step(s) == SQLITE_ROW {
            let n = Int(sqlite3_column_bytes(s, 1)) / 2
            if b == 0 { b = n }
            guard n == b, let p = sqlite3_column_blob(s, 1) else { continue }
            k.append(String(cString: sqlite3_column_text(s, 0)))
            v.append(contentsOf: UnsafeBufferPointer(start: p.assumingMemoryBound(to: Float16.self), count: n))
        }
        kimlikler = k
        sira = Dictionary(k.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        vektorler = v
        boyut = b
    }

    public func vektor(_ uuid: String) -> [Float]? {
        guard let i = sira[uuid] else { return nil }
        return vektorler[i * boyut..<(i + 1) * boyut].map(Float.init)
    }

    /// En benzer `adet` kare: (uuid, benzerlik), benzerlik azalan. `kapsam` verilirse yalnız o kareler arasında.
    public func ara(_ q: [Float], adet: Int, haric: Set<String> = [], kapsam: Set<String>? = nil) -> [(uuid: String, benzerlik: Float)] {
        let n = kimlikler.count, b = boyut
        var skor = [Float](repeating: 0, count: n)
        let q16 = q.map(Float16.init)
        vektorler.withUnsafeBufferPointer { m in
            skor.withUnsafeMutableBufferPointer { s in
                DispatchQueue.concurrentPerform(iterations: 8) { parca in
                    var i = parca
                    while i < n {
                        var t: Float = 0
                        let satir = i * b
                        for j in 0..<b { t += Float(m[satir + j]) * Float(q16[j]) }
                        s[i] = t
                        i += 8
                    }
                }
            }
        }
        return skor.indices.filter { !haric.contains(kimlikler[$0]) && kapsam?.contains(kimlikler[$0]) != false }
            .sorted { skor[$0] > skor[$1] }.prefix(adet)
            .map { (kimlikler[$0], skor[$0]) }
    }

    /// Birbirine çok benzeyen kareleri gruplar (kapsam nil ise bütün dizin). Sıra korunur: sıradaki ilk boşta kalan kare
    /// grubu açar, ona en az `esik` kadar benzeyen boştaki kareler gruba girer. Zincirleme birleştirme yapılmaz:
    /// Okan'ın arşivinde 0,98'de bile seriler zincirlenip 2.000+ karelik gruplar çıkardı (10 Ekim 2026 ölçümü).
    /// Dönen: en az iki kareli gruplar ve kapsamda olup dizinde olmayan (taranmamış) kare sayısı.
    /// ponytail: kapsam × kapsam düz çarpım (200 bin karede ~1 dk, ~1 GB bellek); milyonlarca karede yaklaşık-komşu gerekir.
    public func gruplar(_ kapsam: [String]?, esik: Float) -> (gruplar: [[String]], taranmamis: Int) {
        let satirlar = kapsam.map { $0.compactMap { sira[$0] } } ?? Array(kimlikler.indices)
        let m = satirlar.count, b = boyut
        guard m > 1 else { return ([], (kapsam?.count ?? m) - m) }
        var M = [Float](repeating: 0, count: m * b)
        for (r, i) in satirlar.enumerated() { for j in 0..<b { M[r * b + j] = Float(vektorler[i * b + j]) } }
        var grup = [Bool](repeating: false, count: m)
        var sonuc: [[String]] = []
        let blok = 256
        var C = [Float](repeating: 0, count: blok * m)
        var i0 = 0
        while i0 < m {
            let n = min(blok, m - i0), N = m - i0 // yalnız i0 ve sonrası: önceki kareler zaten bir grupta
            if grup[i0..<i0 + n].contains(false) {
                M.withUnsafeBufferPointer { mp in
                    C.withUnsafeMutableBufferPointer { cp in
                        let a = mp.baseAddress! + i0 * b
                        cblas_sgemm(CblasRowMajor, CblasNoTrans, CblasTrans, Int32(n), Int32(N), Int32(b),
                                    1, a, Int32(b), a, Int32(b), 0, cp.baseAddress!, Int32(N))
                    }
                }
                for r in 0..<n where !grup[i0 + r] {
                    let i = i0 + r
                    grup[i] = true
                    var g = [i]
                    for j in i + 1 ..< m where !grup[j] && C[r * N + j - i0] >= esik { grup[j] = true; g.append(j) }
                    if g.count > 1 { sonuc.append(g.map { kimlikler[satirlar[$0]] }) }
                }
            }
            i0 += n
        }
        return (sonuc, (kapsam?.count ?? m) - m)
    }
}
