import Foundation

/// Listedeki kareleri tarar; bitmişleri atlar, her partiyi diske yazar (kesintide en çok bir parti kaybolur).
public final class Tarayici {
    public struct Ilerleme {
        public let biten: Int, toplam: Int, hata: Int, bekleyen: Int
        public let hiz: Double // kare/sn, bu oturumda
        public var kalanSaniye: Double? { hiz > 0 ? Double(toplam - biten) / hiz : nil }
    }

    let model: GoruntuModeli
    public let dizin: Dizin
    public var parti = 64
    public var esZamanli = 6
    public private(set) var durdur = false

    public init(model: GoruntuModeli, dizin: Dizin) {
        self.model = model
        self.dizin = dizin
    }

    public func iptal() { durdur = true }

    /// Disk okuma dahil gerçek hızı ölçer (kare/sn); dizine yazmaz. Süre tahmini için.
    public func olc(_ ornek: [Kare]) -> Double {
        let t0 = Date()
        DispatchQueue.concurrentPerform(iterations: ornek.count) { i in
            _ = try? model.vektor(dosya: ornek[i].yol)
        }
        return Double(ornek.count) / max(Date().timeIntervalSince(t0), 0.001)
    }

    public func tara(_ kareler: [Kare], bildir: (Ilerleme) -> Void) throws {
        let bitti = dizin.bitenler()
        let kalan = kareler.filter { !bitti.contains($0.uuid) }
        var biten = kareler.count - kalan.count, hata = 0, bekleyen = 0, buOturum = 0
        let t0 = Date()
        // Sürekli akış: en çok `esZamanli` kare aynı anda okunur ve modelden geçer. Biten kare yerine hemen yenisi
        // başlar; yavaş bir dosya (ör. ağdaki büyük TIFF) yalnız kendi yerini meşgul eder, diğerleri beklemez.
        // Sonuçlar `parti` kadar birikince tek işlemde diske yazılır (kesintide en çok bir parti kaybolur).
        let sinir = DispatchSemaphore(value: esZamanli)
        let kuyruk = DispatchQueue(label: "fotora.tarama", attributes: .concurrent)
        let isler = DispatchGroup()
        let kilit = NSLock()
        var tampon: [(Kare, Dizin.Sonuc)] = []

        func bosalt(hepsi: Bool) throws {
            kilit.lock()
            guard hepsi || tampon.count >= parti else { kilit.unlock(); return }
            let yazilacak = tampon
            tampon.removeAll()
            kilit.unlock()
            guard !yazilacak.isEmpty else { return }
            try dizin.yaz(yazilacak)
            for (_, r) in yazilacak {
                switch r {
                case .tamam: biten += 1
                case .hata: hata += 1
                case .bekliyor: bekleyen += 1
                }
            }
            buOturum += yazilacak.count
            bildir(Ilerleme(biten: biten, toplam: kareler.count - hata - bekleyen, hata: hata, bekleyen: bekleyen,
                            hiz: Double(buOturum) / Date().timeIntervalSince(t0)))
        }

        for kare in kalan {
            if durdur { break }
            sinir.wait()
            isler.enter()
            kuyruk.async {
                let r: Dizin.Sonuc
                do {
                    r = .tamam(try self.model.vektor(dosya: kare.yol))
                } catch GoruntuHatasi.diskYok(let d) {
                    r = .bekliyor("Disk bağlı değil: \(d)")
                } catch {
                    r = .hata("\(error)")
                }
                kilit.lock(); tampon.append((kare, r)); kilit.unlock()
                sinir.signal()
                isler.leave()
            }
            try bosalt(hepsi: false)
        }
        isler.wait()
        try bosalt(hepsi: true)
    }
}
