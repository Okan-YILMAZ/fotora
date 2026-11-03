import Foundation

/// LrC eklentisini kurar ve eklentinin yazdığı fotoğraf listesini bulur.
enum Lightroom {
    static let moduller = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Adobe/Lightroom/Modules")
    /// Eklentinin listeyi yazdığı yer (KareListesi.lua); liste küçük olduğu için hep Mac'in kendi diskinde.
    static let listeler = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Fotora/kataloglar")

    /// Uygulamanın içindeki eklenti; geliştirmede (uygulama paketi yokken) depo içindeki kopya: çalışan dosyadan
    /// yukarı doğru ilk "eklenti/Fotora.lrplugin".
    static var eklentiKaynagi: URL {
        if let r = Bundle.main.resourceURL?.appendingPathComponent("Fotora.lrplugin"),
           FileManager.default.fileExists(atPath: r.path) { return r }
        var d = Bundle.main.executableURL!.resolvingSymlinksInPath().deletingLastPathComponent()
        while d.path != "/" {
            let e = d.appendingPathComponent("eklenti/Fotora.lrplugin")
            if FileManager.default.fileExists(atPath: e.path) { return e }
            d.deleteLastPathComponent()
        }
        return d.appendingPathComponent("eklenti/Fotora.lrplugin") // yok; kurulum hatası olarak görünür
    }

    /// LrC, Modules klasöründeki eklentileri kendiliğinden yükler. Var olan kopya yenisiyle değiştirilir.
    static func eklentiyiKur() throws {
        let hedef = moduller.appendingPathComponent("Fotora.lrplugin")
        try FileManager.default.createDirectory(at: moduller, withIntermediateDirectories: true)
        if FileManager.default.fileExists(atPath: hedef.path) { try FileManager.default.removeItem(at: hedef) }
        try FileManager.default.copyItem(at: eklentiKaynagi, to: hedef)
        menuDiliniAyarla()
    }

    /// Fotora güncellenince kurulu eklenti de yenilenir (sürümü uygulamanınkinden farklıysa); LrC yeniden açılınca geçerli.
    /// Eklenti hiç kurulmamışsa dokunulmaz: o iş sihirbazın.
    static func eklentiyiGuncelle() {
        func surum(_ info: URL) -> String? {
            (try? String(contentsOf: info, encoding: .utf8))?.components(separatedBy: "\n").first { $0.contains("VERSION =") }
        }
        let kurulu = moduller.appendingPathComponent("Fotora.lrplugin/Info.lua")
        guard let eski = surum(kurulu), eski != surum(eklentiKaynagi.appendingPathComponent("Info.lua")) else { return }
        try? eklentiyiKur()
    }

    /// LrC menü adlarını Info.lua'dan açılışta bir kez okur; dile göre kendisi değiştiremez. Bu yüzden kurulu
    /// eklentinin Info.lua'sındaki adları Fotora'nın diline göre biz yazarız; LrC yeniden açılınca geçerli olur.
    static func menuDiliniAyarla() {
        let info = moduller.appendingPathComponent("Fotora.lrplugin/Info.lua")
        guard var s = try? String(contentsOf: info, encoding: .utf8) else { return }
        let adlar = [("Ara.lua", L("Gündelik Dille Ara…", "Search in Everyday Language…")),
                     ("Benzer.lua", L("Benzerlerini Bul", "Find Similar")),
                     ("Gruplar.lua", L("Benzer Grupları Bul…", "Find Similar Groups…")),
                     ("OneGetir.lua", L("Sıralı Sonuçları Öne Getir", "Bring Sorted Results to Front")),
                     ("KareListesi.lua", L("Fotoğraf Listesini Eşitle", "Sync Photo List"))]
        for (dosya, ad) in adlar {
            s = s.replacingOccurrences(of: #"\{ title = '[^']*', file = '\#(dosya)' \}"#,
                                       with: "{ title = '\(ad)', file = '\(dosya)' }", options: .regularExpression)
        }
        try? s.write(to: info, atomically: true, encoding: .utf8)
    }

    /// Eklenti açıkken (Baslat.lua) bu dosya vardır; Disable edilince silinir (Kapat.lua).
    static var eklentiAcik: Bool {
        FileManager.default.fileExists(atPath: listeler.deletingLastPathComponent().appendingPathComponent("eklenti.json").path)
    }

    struct Ozet: Decodable {
        let katalog: String
        let toplam: Int
        let asil: Int
        let sanal: Int
        let video: Int
    }

    struct Katalog {
        let klasor: URL
        let ozet: Ozet
        let tarih: Date
        var ad: String { URL(fileURLWithPath: ozet.katalog).lastPathComponent }
        var liste: URL { klasor.appendingPathComponent("liste.jsonl") }
        /// Katalog yolunun MD5'i (eklentinin klasör adı); dizin de aynı adla tutulur.
        var kimlik: String { klasor.lastPathComponent }
    }

    /// En son hazırlanmış liste (birden çok katalog varsa en yenisi; diğerleri kullanıcı isterse taranır).
    static func sonListe() -> Katalog? { tumListeler().max { $0.tarih < $1.tarih } }

    static func liste(_ kimlik: String) -> Katalog? { tumListeler().first { $0.kimlik == kimlik } }

    static func tumListeler() -> [Katalog] {
        let k = (try? FileManager.default.contentsOfDirectory(at: listeler, includingPropertiesForKeys: nil)) ?? []
        return k.compactMap { d -> Katalog? in
            let o = d.appendingPathComponent("liste.json")
            guard let veri = try? Data(contentsOf: o), let ozet = try? JSONDecoder().decode(Ozet.self, from: veri),
                  let t = try? o.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate else { return nil }
            return Katalog(klasor: d, ozet: ozet, tarih: t)
        }
    }
}
