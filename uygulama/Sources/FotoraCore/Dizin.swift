import Foundation
import SQLite3

/// Arama dizini: tek bir SQLite dosyası. Her kare bir satır; vektör yarım hassasiyetle (2 bayt x 1152).
/// Durum: tamam | hata | bekliyor (disk bağlı değil). Kaldığı yerden devam bu tablodan.
public final class Dizin {
    var db: OpaquePointer?
    let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    public init(_ url: URL, model: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard sqlite3_open(url.path, &db) == SQLITE_OK else { throw hata("açılamadı") }
        try calistir("""
            PRAGMA journal_mode=WAL;
            CREATE TABLE IF NOT EXISTS bilgi (anahtar TEXT PRIMARY KEY, deger TEXT);
            CREATE TABLE IF NOT EXISTS kare (uuid TEXT PRIMARY KEY, yol TEXT NOT NULL, durum TEXT NOT NULL,
                hata TEXT, vektor BLOB, zaman REAL);
            """)
        // İlk sürümler modeli paket adıyla ("goruntu.mlpackage") kaydediyordu; o dizinler So400m'indir.
        if deger("model") == "goruntu.mlpackage" && model == "so400m" { try calistir("UPDATE bilgi SET deger='so400m' WHERE anahtar='model'") }
        if let eski = deger("model"), eski != model {
            throw hata("bu dizin başka bir modelle oluşturulmuş (\(eski)); yeni model yeni dizin ister")
        }
        try calistir("INSERT OR REPLACE INTO bilgi VALUES ('model', '\(model.replacingOccurrences(of: "'", with: "''"))')")
    }

    deinit { sqlite3_close(db) }

    func hata(_ m: String) -> NSError {
        NSError(domain: "Dizin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Dizin \(m): \(String(cString: sqlite3_errmsg(db)))"])
    }

    func calistir(_ sql: String) throws {
        guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw hata("komut") }
    }

    func deger(_ anahtar: String) -> String? {
        var s: OpaquePointer?
        defer { sqlite3_finalize(s) }
        sqlite3_prepare_v2(db, "SELECT deger FROM bilgi WHERE anahtar=?", -1, &s, nil)
        sqlite3_bind_text(s, 1, anahtar, -1, SQLITE_TRANSIENT)
        return sqlite3_step(s) == SQLITE_ROW ? String(cString: sqlite3_column_text(s, 0)) : nil
    }

    /// Bitmiş (tamam) karelerin kimlikleri; bunlar yeniden taranmaz.
    public func bitenler() -> Set<String> {
        var s: OpaquePointer?
        defer { sqlite3_finalize(s) }
        sqlite3_prepare_v2(db, "SELECT uuid FROM kare WHERE durum='tamam'", -1, &s, nil)
        var k = Set<String>()
        while sqlite3_step(s) == SQLITE_ROW { k.insert(String(cString: sqlite3_column_text(s, 0))) }
        return k
    }

    /// Dizindeki bütün karelerin kimlikleri (durumu ne olursa olsun).
    public func kimlikler() -> Set<String> {
        var s: OpaquePointer?
        defer { sqlite3_finalize(s) }
        sqlite3_prepare_v2(db, "SELECT uuid FROM kare", -1, &s, nil)
        var k = Set<String>()
        while sqlite3_step(s) == SQLITE_ROW { k.insert(String(cString: sqlite3_column_text(s, 0))) }
        return k
    }

    /// Katalogdan silinen kareleri dizinden çıkarır (fotoğrafın kendisine dokunulmaz).
    public func sil(_ kimlikler: [String]) throws {
        try calistir("BEGIN")
        var s: OpaquePointer?
        sqlite3_prepare_v2(db, "DELETE FROM kare WHERE uuid=?", -1, &s, nil)
        defer { sqlite3_finalize(s) }
        for k in kimlikler {
            sqlite3_reset(s)
            sqlite3_bind_text(s, 1, k, -1, SQLITE_TRANSIENT)
            guard sqlite3_step(s) == SQLITE_DONE else { try? calistir("ROLLBACK"); throw hata("silinemedi") }
        }
        try calistir("COMMIT")
    }

    /// Okunamayan ya da diski bekleyen kareler: (kimlik, yol, durum, neden).
    public func sorunlular() -> [(uuid: String, yol: String, durum: String, neden: String)] {
        var s: OpaquePointer?
        defer { sqlite3_finalize(s) }
        sqlite3_prepare_v2(db, "SELECT uuid, yol, durum, IFNULL(hata,'') FROM kare WHERE durum!='tamam' ORDER BY yol", -1, &s, nil)
        var r: [(String, String, String, String)] = []
        while sqlite3_step(s) == SQLITE_ROW {
            r.append((String(cString: sqlite3_column_text(s, 0)), String(cString: sqlite3_column_text(s, 1)),
                      String(cString: sqlite3_column_text(s, 2)), String(cString: sqlite3_column_text(s, 3))))
        }
        return r
    }

    public enum Sonuc { case tamam([Float]), hata(String), bekliyor(String) }

    /// Bir partiyi tek işlemde yazar (yarım parti kalmaz).
    public func yaz(_ sonuclar: [(Kare, Sonuc)]) throws {
        try calistir("BEGIN")
        var s: OpaquePointer?
        sqlite3_prepare_v2(db, "INSERT OR REPLACE INTO kare VALUES (?,?,?,?,?,?)", -1, &s, nil)
        defer { sqlite3_finalize(s) }
        let simdi = Date().timeIntervalSince1970
        for (k, r) in sonuclar {
            sqlite3_reset(s)
            sqlite3_bind_text(s, 1, k.uuid, -1, SQLITE_TRANSIENT)
            sqlite3_bind_text(s, 2, k.yol, -1, SQLITE_TRANSIENT)
            switch r {
            case .tamam(let v):
                sqlite3_bind_text(s, 3, "tamam", -1, SQLITE_TRANSIENT)
                sqlite3_bind_null(s, 4)
                let yarim = v.map { Float16($0) }
                yarim.withUnsafeBytes { b in _ = sqlite3_bind_blob(s, 5, b.baseAddress, Int32(b.count), SQLITE_TRANSIENT) }
            case .hata(let m), .bekliyor(let m):
                if case .hata = r { sqlite3_bind_text(s, 3, "hata", -1, SQLITE_TRANSIENT) } else { sqlite3_bind_text(s, 3, "bekliyor", -1, SQLITE_TRANSIENT) }
                sqlite3_bind_text(s, 4, m, -1, SQLITE_TRANSIENT)
                sqlite3_bind_null(s, 5)
            }
            sqlite3_bind_double(s, 6, simdi)
            guard sqlite3_step(s) == SQLITE_DONE else { try? calistir("ROLLBACK"); throw hata("yazılamadı") }
        }
        try calistir("COMMIT")
    }
}
