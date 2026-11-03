import Foundation

/// Eklentinin yazdığı liste.jsonl'deki bir satır (KareListesi.lua).
public struct Kare: Decodable {
    public let uuid: String
    public let yol: String
    public let bicim: String
    public let sanal: Bool
    public let asil_uuid: String?
    /// LrC'nin kare numarası (localIdentifier); liste biçimi 2'den beri (10 Ekim 2026).
    public let yerel: Int?

    public init(uuid: String, yol: String, bicim: String, sanal: Bool, asil_uuid: String?, yerel: Int? = nil) {
        self.uuid = uuid; self.yol = yol; self.bicim = bicim; self.sanal = sanal; self.asil_uuid = asil_uuid; self.yerel = yerel
    }

    /// Aynı kare, başka bir dosyadan okunacak şekilde (ör. LrC'nin önizlemesi).
    public func yolla(_ yeni: String) -> Kare { Kare(uuid: uuid, yol: yeni, bicim: bicim, sanal: sanal, asil_uuid: asil_uuid, yerel: yerel) }
}

public enum Liste {
    /// Sanal kopyalar taranmaz (asıl karenin vektörünü kullanır); burada elenir.
    public static func oku(_ url: URL) throws -> [Kare] {
        // Eklenti listeyi yenilerken dosya bir anlığına yerinde olmayabilir; kısa süre beklenir.
        for _ in 0..<10 where !FileManager.default.fileExists(atPath: url.path) { Thread.sleep(forTimeInterval: 1) }
        let veri = try String(contentsOf: url, encoding: .utf8)
        let cozucu = JSONDecoder()
        return try veri.split(separator: "\n").compactMap { satir in
            let k = try cozucu.decode(Kare.self, from: Data(satir.utf8))
            return k.sanal ? nil : k
        }
    }

    /// Kare numarası → dizindeki kimlik (sanal kopya için asıl karenin kimliği). Eski biçimli listede boş döner.
    public static func numaralar(_ url: URL) throws -> [Int: String] {
        let veri = try String(contentsOf: url, encoding: .utf8)
        let cozucu = JSONDecoder()
        var s: [Int: String] = [:]
        for satir in veri.split(separator: "\n") {
            let k = try cozucu.decode(Kare.self, from: Data(satir.utf8))
            if let n = k.yerel, let u = k.sanal ? k.asil_uuid : k.uuid { s[n] = u }
        }
        return s
    }
}
