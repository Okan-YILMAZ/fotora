import AppKit
import FotoraCore
import Foundation

/// Destek ve bakım: tanı raporu, her şeyi kaldırma.
@MainActor
enum Bakim {
    /// Sunucudaki surum.txt: ilk satır son sürüm ("1.1"), ikinci satır indirme sayfası. Yalnız düğmeyle çağrılır;
    /// Mac'ten çıkan tek şey bu dosyanın isteğidir.
    static func guncellemeDenetle(_ sunucu: String) async -> String {
        let simdi = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        guard let (veri, cevap) = try? await URLSession.shared.data(from: URL(string: sunucu)!.appendingPathComponent("surum.txt")) else {
            return L("Denetlenemedi; internet bağlantınızı kontrol edin.", "Could not check; please check your internet connection.")
        }
        guard (cevap as? HTTPURLResponse)?.statusCode == 200,
              let satirlar = String(data: veri, encoding: .utf8)?.split(whereSeparator: \.isNewline).map({ $0.trimmingCharacters(in: .whitespaces) }),
              let son = satirlar.first, !son.isEmpty else {
            return L("Sürüm bilgisi şu an alınamadı; daha sonra yeniden deneyin.", "Version information is not available right now; please try again later.")
        }
        guard son.compare(simdi, options: .numeric) == .orderedDescending else {
            return L("Fotora güncel.", "Fotora is up to date.")
        }
        let sayfa = satirlar.count > 1 ? satirlar[1] : "getfotora.com"
        return L("Fotora \(son) çıktı: \(sayfa)", "Fotora \(son) is available: \(sayfa)")
    }

    /// Fotoğraf adı, yolu ya da katalog adı içermeyen tanı raporu; Masaüstü'ne yazılır ve Finder'da gösterilir.
    static func taniRaporu(_ u: Uygulama) {
        var s: [String] = ["Fotora tanı raporu / diagnostic report", "Tarih: \(Date().formatted(.iso8601))",
                           "Bu dosyayı destek@getfotora.com adresine gönderin. / Please send this file to destek@getfotora.com.", ""]
        let b = Bundle.main
        s.append("Fotora: \(b.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "geliştirme")")
        let os = ProcessInfo.processInfo.operatingSystemVersion
        s.append("macOS: \(os.majorVersion).\(os.minorVersion).\(os.patchVersion)")
        s.append("İşlemci: \(Sistem.sysctl("machdep.cpu.brand_string"))")
        s.append(String(format: "Bellek: %.0f GB", Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824))
        s.append("Lightroom Classic: \(Sistem.lrcSurumu() ?? "bulunamadı")")
        s.append("Eklenti açık: \(Lightroom.eklentiAcik ? "evet" : "hayır")")
        s.append("Dil: \(Dil.kod)")
        s.append("Model: \(u.model); model dosyaları: " + Uygulama.modelParcalari.map {
            FileManager.default.fileExists(atPath: u.modelKlasoru.appendingPathComponent($0).path) ? "\($0) ✓" : "\($0) EKSİK"
        }.joined(separator: ", "))
        s.append(String(format: "Kayıt yeri: %@, boş %.0f GB", u.kayitYeriAdi, Sistem.bosAlanGB(u.kayitYeri)))
        s.append("Kurulum bitti: \(u.kurulumBitti), ilk tarama bitti: \(u.ilkTaramaBitti)")
        s.append("Tarama durumu: \(u.tarama)")
        if let i = u.ilerleme { s.append(String(format: "Son tarama hızı: %.1f kare/sn", i.hiz)) }
        let kataloglar = (try? FileManager.default.contentsOfDirectory(at: u.kayitYeri.appendingPathComponent("kataloglar"),
                                                                       includingPropertiesForKeys: nil)) ?? []
        s.append("Taranmış katalog sayısı: \(kataloglar.count)")
        if let k = u.katalog {
            s.append("Açık katalogda: \(k.ozet.toplam) kare (\(k.ozet.asil) asıl, \(k.ozet.sanal) sanal, \(k.ozet.video) video)")
        }
        s.append("Taranmış: \(u.taranmisSayisi), bekleyen disk: \(u.bekleyenDiskler.values.reduce(0, +))")
        // Neden türlerine göre sayılar; dosya adları yazılmaz.
        var turler: [String: Int] = [:]
        for r in u.sorunlular { turler["\(r.durum): \(r.neden.components(separatedBy: ":").first ?? r.neden)", default: 0] += 1 }
        s.append("Sorunlu kareler: " + (turler.isEmpty ? "yok" : turler.map { "\($0.key) ×\($0.value)" }.sorted().joined(separator: "; ")))
        if let h = u.taramaHatasi { s.append("Son hata: \(h)") }
        let dosya = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop/Fotora-tani-\(Int(Date().timeIntervalSince1970)).txt")
        let metin = s.joined(separator: "\n")
        try? metin.write(to: dosya, atomically: true, encoding: .utf8)
        NSWorkspace.shared.activateFileViewerSelecting([dosya])
        // E-posta programında hazır ileti açılır; göndermek kullanıcının elinde (kendiliğinden hiçbir şey gönderilmez).
        var e = URLComponents(string: "mailto:destek@getfotora.com")!
        e.queryItems = [URLQueryItem(name: "subject", value: L("Fotora tanı raporu", "Fotora diagnostic report")),
                        URLQueryItem(name: "body", value: L("Sorunu kısaca anlatın:\n\n\n", "Briefly describe the problem:\n\n\n") + metin)]
        if let u = e.url { NSWorkspace.shared.open(u) }
    }

    /// Fotora'nın oluşturduğu her şeyi Çöp Sepeti'ne taşır (geri alınabilir), ayarları siler ve uygulamayı kapatır.
    /// Kullanıcının seçtiği kayıt klasörünün kendisine dokunulmaz, yalnız içindeki Fotora klasörleri taşınır.
    /// Fotoğraflara, kataloğa ve LrC'deki "Fotora" koleksiyonlarına dokunulmaz.
    static func herSeyiKaldir(_ u: Uygulama) {
        let fm = FileManager.default
        let ev = fm.homeDirectoryForCurrentUser
        let hedefler = [
            u.kayitYeri.appendingPathComponent("modeller"),
            u.kayitYeri.appendingPathComponent("kataloglar"),
            ev.appendingPathComponent("Library/Application Support/Fotora"),
            Lightroom.moduller.appendingPathComponent("Fotora.lrplugin"),
        ].filter { fm.fileExists(atPath: $0.path) }

        let uyari = NSAlert()
        uyari.alertStyle = .warning
        uyari.messageText = L("Fotora'yı kaldır", "Remove Fotora")
        uyari.informativeText = L("""
            Şunlar Çöp Sepeti'ne taşınacak (gerekirse geri alabilirsiniz):
            \(hedefler.map { "• " + $0.path }.joined(separator: "\n"))
            Ayrıca Fotora'nın ayarları silinecek.

            Fotoğraflarınıza ve kataloğunuza dokunulmaz. Lightroom'daki "Fotora" koleksiyonlarını isterseniz Lightroom'dan silebilirsiniz. Son olarak Fotora uygulamasını Uygulamalar klasöründen Çöp Sepeti'ne sürükleyin.
            """, """
            The following will be moved to the Trash (you can restore them if needed):
            \(hedefler.map { "• " + $0.path }.joined(separator: "\n"))
            Fotora's settings will also be deleted.

            Your photos and catalog are not touched. You can delete the "Fotora" collections in Lightroom if you like. Finally, drag the Fotora app from Applications to the Trash.
            """)
        uyari.addButton(withTitle: L("Kaldır", "Remove"))
        uyari.addButton(withTitle: L("Vazgeç", "Cancel"))
        NSApp.activate()
        guard uyari.runModal() == .alertFirstButtonReturn else { return }
        u.duraklat()
        for h in hedefler { try? fm.trashItem(at: h, resultingItemURL: nil) }
        if let id = Bundle.main.bundleIdentifier { UserDefaults.standard.removePersistentDomain(forName: id) }
        NSApp.terminate(nil)
    }
}
