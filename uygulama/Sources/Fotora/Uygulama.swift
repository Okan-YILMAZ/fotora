import FotoraCore
import Foundation
import IOKit.ps
import SwiftUI

/// Uygulamanın bütün durumu: kurulum adımları, ayarlar, tarama.
@MainActor
final class Uygulama: ObservableObject {
    static var adimlar: [String] { [L("Hoş geldiniz", "Welcome"), L("Mac kontrolü", "Mac check"), L("Gizlilik", "Privacy"), L("Lightroom", "Lightroom"), L("Model", "Model"), L("İndirme", "Download"), L("Tarama", "Scan")] }

    // Ayarlar (kalıcı)
    @AppStorage("kurulumBitti") var kurulumBitti = false
    @AppStorage("kayitYeri") var kayitYeriYolu = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Fotora").path
    @AppStorage("model") var model = "iyi"
    @AppStorage("uykuEngelle") var uykuEngelle = true
    @AppStorage("pildeDuraklat") var pildeDuraklat = true
    /// Tarama yarıda kaldıysa (Mac kapandı, uygulama kapandı) açılışta kendiliğinden sürer.
    @AppStorage("taramaSuruyordu") var taramaSuruyordu = false
    @AppStorage("ilkTaramaBitti") var ilkTaramaBitti = false
    /// Arayüz dili ("tr"/"en"); boşsa Mac'in dili (Dil.swift).
    @AppStorage("dil") var dil = Dil.kod
    /// Taranan katalog (kimliği) ve kullanıcının başka kataloglar için verdiği "taransın mı?" cevapları.
    @AppStorage("aktifKatalog") var aktifKatalog = ""
    @AppStorage("katalogKararlari") var katalogKararlari = ""  // "kimlik=1;kimlik=0"
    /// Görünüm: "sistem", "acik", "koyu".
    @AppStorage("gorunum") var gorunum = "sistem"
    @AppStorage("otomatikTara") var otomatikTara = true
    /// Aramada kullanılan model: model değiştirilince yeni dizin bitene kadar eskisi kullanılır.
    @AppStorage("aramaModeli") var aramaModeli = ""
    @Published var tasiniyor = false
    @Published var tasimaDurumu: String?
    @Published var guncelleme: String? // Ayarlar › Bakım › Güncellemeleri denetle sonucu

    var gorunumSemasi: ColorScheme? { gorunum == "acik" ? .light : (gorunum == "koyu" ? .dark : nil) }

    @Published var adim = 0
    @Published var kontroller: [Kontrol] = []
    @Published var eklentiHatasi: String?
    @Published var katalog: Lightroom.Katalog?
    @Published var eklentiAcik = false
    @Published var indirme: Double = 0
    @Published var modelHazir = false
    @Published var modelHatasi: String?

    enum TaramaDurumu { case hazirlaniyor, hazir, suruyor, duraklatildi(String), bitti }
    @Published var tarama: TaramaDurumu = .hazirlaniyor
    @Published var ilerleme: Tarayici.Ilerleme?
    @Published var tahminiSaniye: Double?
    @Published var taranacak = 0
    @Published var taranmisSayisi = 0
    @Published var bekleyenDiskler: [String: Int] = [:]
    @Published var sorunlular: [(uuid: String, yol: String, durum: String, neden: String)] = []
    @Published var taramaHatasi: String?
    @Published var sorunlarAcik = false

    var kayitYeri: URL { URL(fileURLWithPath: kayitYeriYolu) }
    /// Seçili model: "iyi" = SigLIP 2 So400m, "hizli" = SigLIP 2 Base. Her modelin ayrı klasörü ve dizini var.
    var modelKimligi: String { model == "hizli" ? "base" : "so400m" }
    var modelAdi: String { model == "hizli" ? L("Hızlı ve hafif", "Fast and light") : L("En iyi sonuç", "Best results") }
    /// Bu Mac'te ölçülen kare başına süre (sn, model kısmı; disk ayrıca): So400m 0,095, Base 0,013 (10 Ekim 2026).
    var kareBasinaSn: Double { model == "hizli" ? 0.02 : 0.1 }
    /// Kullanılacak alan (GB): model + 200 bin karelik dizin. So400m 2,3 + 0,9; Base 0,75 + 0,3.
    var gerekenAlanGB: Double { model == "hizli" ? 1.1 : 3.2 }
    var modelKlasoru: URL { kayitYeri.appendingPathComponent("modeller/\(modelKimligi)") }
    func dizinDosyasi(_ katalogKimligi: String, model: String? = nil) -> URL {
        let m = model ?? modelKimligi
        return kayitYeri.appendingPathComponent("kataloglar/\(katalogKimligi)/" + (m == "so400m" ? "dizin.sqlite" : "dizin-\(m).sqlite"))
    }
    var aramaModeliKimligi: String { aramaModeli.isEmpty ? modelKimligi : aramaModeli }
    var modelPaketi: URL { modelKlasoru.appendingPathComponent("goruntu.mlpackage") }

    private var tarayici: Tarayici?
    private var listeTarihi: Date?
    private var gModel: GoruntuModeli?
    private var dizin: Dizin?
    private var kareler: [Kare] = []
    private var uyku: NSObjectProtocol?

    init() {
        if kurulumBitti { adim = 6; modeliIndir() } // eski kurulumda eksik parça (ör. metin kolu) varsa tamamlanır
        sunucuyuBaslat()
        listeyiIzle()
        Dil.eklentiyeBildir()
        Lightroom.eklentiyiGuncelle()
        Lightroom.menuDiliniAyarla()
        metniOnYukle()
        diskleriIzle()
    }

    /// İlk aramanın beklememesi için metin modeli uygulama açılırken arka planda yüklenir (yaklaşık 20 sn).
    func metniOnYukle() {
        let klasor = kayitYeri.appendingPathComponent("modeller/\(aramaModeliKimligi)")
        guard metinModeli == nil, FileManager.default.fileExists(atPath: klasor.appendingPathComponent("metin.mlpackage").path) else { return }
        Task {
            if let m = try? await MetinModeli(klasor: klasor, onbellek: klasor.appendingPathComponent("derlenmis")), metinModeli == nil {
                metinModeli = m
            }
        }
    }

    /// Bağlı olmayan bir disk bağlanınca o diskteki kareler kendiliğinden taranır.
    private func diskleriIzle() {
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { [weak self] n in
            let ad = (n.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL)?.lastPathComponent
            Task { @MainActor in
                guard let self, self.kurulumBitti, let ad, self.bekleyenDiskler[ad] != nil else { return }
                if case .suruyor = self.tarama { return }
                self.taramayaHazirlan()
            }
        }
    }

    /// Eklenti listeyi yenileyince (LrC açılışı ya da menü) eklenen kareler taranır, silinenler dizinden çıkar.
    /// Tarama sürerken beklenir; dosyaya bakmak ucuz olduğu için dakikada bir.
    private func listeyiIzle() {
        Task {
            while true {
                try? await Task.sleep(for: .seconds(60))
                guard kurulumBitti, let k = Lightroom.sonListe(), let eski = listeTarihi else { continue }
                if let a = katalog, k.kimlik != a.kimlik, k.tarih > eski {
                    if case .suruyor = tarama { continue }
                    yeniKatalog(k)
                    continue
                }
                // Liste değiştiyse ya da eklenti okunamayan kareler için yeni önizleme bıraktıysa.
                let onizleme = (try? k.klasor.appendingPathComponent("onizleme").resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                guard k.tarih > eski || (onizleme ?? .distantPast) > eski else { continue }
                if case .suruyor = tarama { continue }
                if case .hazirlaniyor = tarama { continue }
                taramayaHazirlan()
            }
        }
    }

    // MARK: Kurulum adımları

    /// Dili değiştirir; eklenti de bir sonraki penceresinde aynı dili kullanır.
    func diliSec(_ kod: String) {
        dil = kod
        Dil.eklentiyeBildir()
        Lightroom.menuDiliniAyarla()
        if !kontroller.isEmpty { macKontrol() }
    }

    func dilDegistir() {
        diliSec(Dil.ingilizce ? "tr" : "en")
        let uyari = NSAlert()
        uyari.messageText = L("Dil değişti", "Language changed")
        uyari.informativeText = L("Lightroom'daki Fotora menülerinin adları, Lightroom kapatılıp yeniden açıldığında değişir. Pencereler ve mesajlar hemen yeni dilde gösterilir. Dil tercihiniz hatırlanır.",
                                  "The names of the Fotora menus in Lightroom change after Lightroom is quit and reopened. Windows and messages switch right away. Your language choice is remembered.")
        NSApp.activate()
        uyari.runModal()
        if !kontroller.isEmpty { macKontrol() }
    }

    func macKontrol() { kontroller = Sistem.kontroller(kayitYeri: kayitYeri) }
    var macUygun: Bool { !kontroller.isEmpty && kontroller.allSatisfy(\.uygun) }

    func lightroomHazirla() {
        do { try Lightroom.eklentiyiKur(); eklentiHatasi = nil } catch { eklentiHatasi = L("Eklenti kurulamadı: ", "Could not install the plug-in: ") + error.localizedDescription }
        listeyiYenile()
    }

    func listeyiYenile() { eklentiAcik = Lightroom.eklentiAcik; katalog = Lightroom.sonListe() }

    func kayitYeriSec() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.prompt = L("Bu klasörü kullan", "Use this folder")
        p.message = L("Fotora'nın modeli ve arama dizinini koyacağı klasörü seçin ya da yeni bir klasör oluşturun (ör. harici bir SSD'de).", "Choose a folder for Fotora's model and search index, or create a new one (for example on an external SSD).")
        // Kullanıcının seçtiği klasör olduğu gibi kullanılır; içine ayrıca "Fotora" klasörü açılmaz (Okan, 9 Ekim 2026).
        if p.runModal() == .OK, let u = p.url { kayitYeriYolu = u.path }
    }

    var kayitYeriAdi: String {
        let v = try? kayitYeri.deletingLastPathComponent().resourceValues(forKeys: [.volumeLocalizedNameKey, .volumeIsInternalKey])
        return v?.volumeIsInternal == false ? "\(v?.volumeLocalizedName ?? L("Harici disk", "External disk")) " + L("(harici)", "(external)") : L("Bu Mac", "This Mac")
    }

    /// Modellerin indirildiği adres (Cloudflare R2, getfotora.com; 12 Ekim 2026). Dosyalar paket/modelleri_hazirla.sh çıktısı.
    /// Deneme için başka adres: defaults write com.fotora.app modelAdresi <adres>
    var modelAdresi: String { UserDefaults.standard.string(forKey: "modelAdresi") ?? "https://indir.getfotora.com" }
    /// Sunucudaki dosyalar (paket/modelleri_hazirla.sh çıktısı): ad, bayt, SHA-256. Model değişirse sürüm ve değerler birlikte değişir.
    nonisolated static let modelDosyalari: [String: (ad: String, boyut: Int, sha256: String)] = [
        "so400m": ("fotora-so400m-1.zip", 2_115_739_608, "c0dad98ad7c054c849131eb27e71507e1e742530d9a98f135b2976f05e6ef8b0"),
        "base": ("fotora-base-1.zip", 706_888_471, "30d41e89fdf695465d807da86b3b0c95371c97151325ccab473c47e06cc80fc9"),
    ]
    /// Model klasörünün içeriği: iki kol ve metni parçalara bölen sözlük.
    nonisolated static let modelParcalari = ["goruntu.mlpackage", "metin.mlpackage", "tokenizer.json", "tokenizer_config.json", "special_tokens_map.json"]

    /// Model eksikse indirir (tek zip), denetler, açar; sonra modeli bu Mac'te bir kez derleyip dener.
    func modeliIndir(sonra: (@MainActor () -> Void)? = nil) {
        let klasor = modelKlasoru, paket = modelPaketi, dosya = Self.modelDosyalari[modelKimligi]!
        let adres = URL(string: modelAdresi)!.appendingPathComponent(dosya.ad)
        modelHatasi = nil
        modelHazir = false
        indirme = 0
        Task.detached {
            do {
                let fm = FileManager.default
                if Self.modelParcalari.contains(where: { !fm.fileExists(atPath: klasor.appendingPathComponent($0).path) }) {
                    try fm.createDirectory(at: klasor, withIntermediateDirectories: true)
                    let zip = klasor.appendingPathComponent("indiriliyor.zip")
                    try await Indirici.indir(adres, hedef: zip, boyut: dosya.boyut, sha256: dosya.sha256) { oran in
                        Task { @MainActor in self.indirme = oran * 0.85 }
                    }
                    await MainActor.run { self.indirme = 0.87 }
                    let acilan = klasor.appendingPathComponent("aciliyor")
                    try? fm.removeItem(at: acilan)
                    let p = Process()
                    p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                    p.arguments = ["-x", "-k", zip.path, acilan.path]
                    try p.run(); p.waitUntilExit()
                    guard p.terminationStatus == 0 else { throw NSError(domain: "Fotora", code: 4, userInfo: [NSLocalizedDescriptionKey: L("Model dosyası açılamadı.", "Could not unpack the model file.")]) }
                    for parca in Self.modelParcalari {
                        try? fm.removeItem(at: klasor.appendingPathComponent(parca))
                        try fm.moveItem(at: acilan.appendingPathComponent(parca), to: klasor.appendingPathComponent(parca))
                    }
                    try? fm.removeItem(at: klasor.appendingPathComponent("MODEL_LISANSI.txt"))
                    try? fm.moveItem(at: acilan.appendingPathComponent("MODEL_LISANSI.txt"), to: klasor.appendingPathComponent("MODEL_LISANSI.txt"))
                    try? fm.removeItem(at: acilan)
                    try? fm.removeItem(at: zip)
                }
                await MainActor.run { self.indirme = 0.9 }
                // Mac'te bir kez derlenir ve denenir.
                _ = try GoruntuModeli(paket: paket, onbellek: klasor.appendingPathComponent("derlenmis"))
                await MainActor.run { self.indirme = 1; self.modelHazir = true; self.metniOnYukle(); sonra?() }
            } catch {
                await MainActor.run { self.modelHatasi = L("Model indirilemedi: ", "Could not download the model: ") + error.localizedDescription }
            }
        }
    }

    // MARK: Arama (eklentiden gelen istekler)

    private var sunucu: Sunucu?
    private var metinModeli: MetinModeli?
    private var aramaDizinleri: [String: (dizin: AramaDizini, zaman: Date)] = [:]
    private var numaraListeleri: [String: (s: [Int: String], tarih: Date)] = [:]

    /// Eklentinin gönderdiği kare numaralarını (LrC localIdentifier) dizin kimliklerine çevirir; liste değişince yeniden okunur.
    private func kimlikler(_ katalog: String, _ numaralar: [Int]) throws -> [String] {
        let url = Lightroom.listeler.appendingPathComponent("\(katalog)/liste.jsonl")
        let tarih = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
        if numaraListeleri[katalog]?.tarih != tarih { numaraListeleri[katalog] = (try Liste.numaralar(url), tarih) }
        let s = numaraListeleri[katalog]!.s
        if s.isEmpty && !numaralar.isEmpty {
            throw NSError(domain: "Fotora", code: 2, userInfo: [NSLocalizedDescriptionKey: L("Fotoğraf listesi eski. Library › Plug-in Extras › Fotoğraf Listesini Eşitle'yi bir kez çalıştırın.", "The photo list is out of date. Run Library › Plug-in Extras › Sync Photo List once.")])
        }
        var gorulen = Set<String>()
        return numaralar.compactMap { s[$0] }.filter { gorulen.insert($0).inserted }
    }

    func sunucuyuBaslat() {
        let s = Sunucu { [weak self] yol, govde in
            guard let self else { return ["hata": L("Fotora kapanıyor", "Fotora is quitting")] }
            return await self.istek(yol, govde)
        }
        do { try s.baslat(); sunucu = s } catch { taramaHatasi = L("Arama sunucusu açılamadı: ", "Could not start the search service: ") + error.localizedDescription }
    }

    /// Tarama sürerken dizin büyür; 5 dakikadan eski kopya yeniden okunur.
    private func aramaDizini(_ katalog: String) throws -> AramaDizini {
        if let d = aramaDizinleri[katalog], Date().timeIntervalSince(d.zaman) < 300 { return d.dizin }
        let yol = dizinDosyasi(katalog, model: aramaModeliKimligi)
        guard FileManager.default.fileExists(atPath: yol.path) else { throw NSError(domain: "Fotora", code: 1, userInfo: [NSLocalizedDescriptionKey: L("Bu katalog henüz taranmadı. Fotora'yı açıp taramayı başlatın.", "This catalog has not been scanned yet. Open Fotora and start the scan.")]) }
        let d = try AramaDizini(yol)
        aramaDizinleri[katalog] = (d, Date())
        return d
    }

    private func istek(_ yol: String, _ g: [String: Any]) async -> [String: Any] {
        do {
            switch yol {
            case "/durum":
                return ["surum": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "geliştirme"]
            case "/ara", "/benzer", "/gruplar":
                guard let katalog = g["katalog"] as? String else { return ["hata": L("Katalog bilgisi eksik", "Catalog information missing")] }
                if katalogKarari(katalog) == false {
                    return ["hata": L("Fotora bu katalogda kapalı. Fotora › Ayarlar › Kataloglar'dan açabilirsiniz.", "Fotora is off for this catalog. Turn it on in Fotora › Settings › Catalogs.")]
                }
                let adet = g["adet"] as? Int ?? 100
                let dizin = try aramaDizini(katalog)
                // Yalnız seçili ya da görünen kareler (LrC kare numaralarıyla); yoksa bütün katalog.
                let kapsam = try (g["numaralar"] as? [Int]).map { try kimlikler(katalog, $0) }
                if yol == "/gruplar" {
                    // Eşikler Okan'ın arşivinden örnek çiftlere bakılarak (10 Ekim 2026): 0,985+ aynı kare/art arda çekim,
                    // 0,97-0,98 aynı sahnede küçük açı ya da an farkı, 0,92 civarı yalnız konu aynı.
                    let esik: Float = (g["esik"] as? String) == "ayni" ? 0.985 : 0.97
                    let s = await Task.detached { dizin.gruplar(kapsam, esik: esik) }.value
                    return ["gruplar": s.gruplar, "taranmamis": s.taranmamis]
                }
                var q: [Float]
                var haric: Set<String> = []
                if yol == "/ara" {
                    if metinModeli == nil {
                        let k = kayitYeri.appendingPathComponent("modeller/\(aramaModeliKimligi)")
                        metinModeli = try await MetinModeli(klasor: k, onbellek: k.appendingPathComponent("derlenmis"))
                    }
                    q = try metinModeli!.vektor(g["metin"] as? String ?? "")
                } else {
                    let uuid = g["uuid"] as? String ?? ""
                    guard let v = dizin.vektor(uuid) else { return ["hata": L("Seçili kare henüz taranmadı.", "The selected photo has not been scanned yet.")] }
                    q = v
                    haric = [uuid]
                }
                let sonuc = dizin.ara(q, adet: adet, haric: haric, kapsam: kapsam.map(Set.init))
                let toplam = (Lightroom.sonListe().map { $0.klasor.lastPathComponent == katalog ? $0.ozet.asil : 0 }) ?? 0
                return ["sonuc": sonuc.map { $0.uuid }, "benzerlik": sonuc.map { Double($0.benzerlik) },
                        "taranan": dizin.kimlikler.count, "toplam": toplam]
            default:
                return ["hata": L("Bilinmeyen istek: ", "Unknown request: ") + yol]
            }
        } catch {
            return ["hata": error.localizedDescription]
        }
    }

    // MARK: Tarama

    func dizinYolu(_ k: Lightroom.Katalog) -> URL { dizinDosyasi(k.kimlik) }

    /// Listeyi okur, bağlı olmayan diskleri ayırır, bu Mac'te gerçek hızı ölçüp süreyi tahmin eder.
    func taramayaHazirlan() {
        guard let k = katalog ?? Lightroom.liste(aktifKatalog) ?? Lightroom.sonListe() else { taramaHatasi = L("Fotoğraf listesi bulunamadı.", "Photo list not found."); return }
        katalog = k
        aktifKatalog = k.kimlik
        tarama = .hazirlaniyor
        let paket = modelPaketi, onbellek = modelKlasoru.appendingPathComponent("derlenmis"), dYolu = dizinYolu(k)
        Task.detached {
            do {
                // macOS'un açamadığı kareler için eklenti LrC'nin kendi önizlemesini bırakır (Okunamayanlar.lua);
                // varsa kare o önizlemeden taranır. Önizleme LrC'deki düzenlemeleri de içerir.
                let onizleme = k.klasor.appendingPathComponent("onizleme")
                let tum = try Liste.oku(k.liste).map { kare -> Kare in
                    let o = onizleme.appendingPathComponent(kare.uuid + ".jpg").path
                    return FileManager.default.fileExists(atPath: o) ? kare.yolla(o) : kare
                }
                let model = try GoruntuModeli(paket: paket, onbellek: onbellek)
                let dizin = try Dizin(dYolu, model: model.ad)
                let bitti = dizin.bitenler()
                var diskler: [String: Int] = [:]
                let erisilebilir = tum.filter { kare in
                    let p = kare.yol.split(separator: "/")
                    if kare.yol.hasPrefix("/Volumes/"), p.count > 1, !FileManager.default.fileExists(atPath: "/Volumes/\(p[1])") {
                        diskler[String(p[1]), default: 0] += 1
                        return false
                    }
                    return true
                }
                let kalan = erisilebilir.filter { !bitti.contains($0.uuid) }
                // Katalogdan silinenler dizinden çıkar. Güvenlik freni (Vektörel Arama'daki gibi): liste bir anda
                // dizinin yarısından fazlasını "silinmiş" gösteriyorsa okuma bozuk sayılır, hiçbir şey silinmez.
                let listede = Set(tum.map(\.uuid))
                let silinen = dizin.kimlikler().subtracting(listede)
                let dizindeki = dizin.kimlikler().count
                if !silinen.isEmpty && silinen.count * 2 <= dizindeki { try dizin.sil(Array(silinen)) }
                let t = Tarayici(model: model, dizin: dizin)
                let bekleyen = diskler
                // Isınma ayrı ölçülür: ilk erişimde macOS ağ/harici disk izni sorabilir, model ilk kez yüklenir;
                // bu bekleme süreye karışmasın. Örnek her seferinde rastgele seçilir: aynı kareler ikinci kez
                // ölçülünce macOS'un disk önbelleğinden gelip çok hızlı çıkıyordu (Mac Mini: 53 dk, sonra 3 dk; gerçek 18 dk).
                let ornek = kalan.shuffled()
                _ = t.olc(Array(ornek.prefix(4)))
                let hiz = ornek.count > 4 ? t.olc(Array(ornek.dropFirst(4).prefix(48))) : 0
                await MainActor.run {
                    self.kareler = erisilebilir
                    self.dizin = dizin
                    self.tarayici = t
                    self.gModel = model
                    self.bekleyenDiskler = bekleyen
                    self.taranacak = kalan.count
                    self.taranmisSayisi = bitti.count
                    self.tahminiSaniye = hiz > 0 ? Double(kalan.count) / hiz : nil
                    // Taranacak bir şey kalmadıysa ve ilk tarama bitmişse bitiş ekranı gösterilir.
                    self.tarama = (kalan.isEmpty && self.ilkTaramaBitti) ? .bitti : .hazir
                    if kalan.isEmpty { self.sorunlular = dizin.sorunlular(); self.okunamayanlariBildir() }
                    self.listeTarihi = Date()
                    // Yarıda kalmış tarama ya da kurulumdan sonra listeye eklenen yeni kareler kendiliğinden taranır.
                    if (self.taramaSuruyordu || (self.ilkTaramaBitti && self.otomatikTara)) && !kalan.isEmpty { self.taramayiBaslat() }
                }
            } catch {
                await MainActor.run { self.taramaHatasi = "\(error.localizedDescription)" }
            }
        }
    }

    func taramayiBaslat() {
        guard let d = dizin, let m = gModel else { return }
        let t = Tarayici(model: m, dizin: d)
        tarayici = t
        kurulumBitti = true
        taramaSuruyordu = true
        tarama = .suruyor
        if uykuEngelle {
            uyku = ProcessInfo.processInfo.beginActivity(options: [.idleSystemSleepDisabled, .userInitiated], reason: "Fotora tarıyor")
        }
        let liste = kareler, pilKontrol = pildeDuraklat
        Task.detached {
            do {
                try t.tara(liste) { i in
                    if pilKontrol && Self.pildeMi() { t.iptal() }
                    Task { @MainActor in self.ilerleme = i }
                }
                await MainActor.run { self.taramaBitti(iptal: t.durdur) }
            } catch {
                await MainActor.run { self.taramaHatasi = "\(error.localizedDescription)"; self.taramaBitti(iptal: true) }
            }
        }
    }

    func duraklat(_ neden: String = L("Duraklatıldı", "Paused")) {
        taramaSuruyordu = false
        tarayici?.iptal()
        tarama = .duraklatildi(neden)
    }

    private func taramaBitti(iptal: Bool) {
        if let u = uyku { ProcessInfo.processInfo.endActivity(u); uyku = nil }
        sorunlular = dizin?.sorunlular() ?? []
        okunamayanlariBildir()
        // Tarama sırasında bağlantısı kopan diskler de izlenir: geri bağlanınca kareleri taranır.
        for r in sorunlular where r.durum == "bekliyor" {
            let p = r.yol.split(separator: "/")
            if r.yol.hasPrefix("/Volumes/"), p.count > 1 { bekleyenDiskler[String(p[1]), default: 0] += 1 }
        }
        if case .duraklatildi = tarama { return }
        if iptal && pildeDuraklat && Self.pildeMi() {
            tarama = .duraklatildi(L("Pil gücünde; prize takınca sürer", "On battery; resumes when plugged in"))
            pilBekle()
        } else if !iptal {
            taramaSuruyordu = false
            ilkTaramaBitti = true
            // Yeni modelin dizini bitti: arama artık onu kullanır.
            if aramaModeliKimligi != modelKimligi {
                aramaModeli = modelKimligi
                metinModeli = nil
                aramaDizinleri = [:]
                metniOnYukle()
            }
            if let d = tarayici?.dizin { taranmisSayisi = d.bitenler().count }
            tarama = .bitti
        }
    }

    private func pilBekle() {
        Task {
            while case .duraklatildi = tarama, Self.pildeMi() { try? await Task.sleep(for: .seconds(30)) }
            if case .duraklatildi = tarama { taramayiBaslat() }
        }
    }

    // MARK: Ayarlar: model, kayıt yeri, kataloglar

    /// Modeli değiştirir: yeni model iner, katalog yeni modelle baştan taranır; o sırada arama eski dizinle sürer.
    func modeliDegistir() {
        let yeni = model == "hizli" ? "iyi" : "hizli"
        let uyari = NSAlert()
        uyari.messageText = yeni == "hizli" ? L("Hızlı modele geçilsin mi?", "Switch to the Fast model?") : L("En iyi sonuç modeline geçilsin mi?", "Switch to the Best results model?")
        uyari.informativeText = L("Bütün katalog yeni modelle baştan taranır. Tarama bitene kadar aramalar eski modelle sürer.",
                                  "The whole catalog is scanned again with the new model. Searches keep using the old model until the scan finishes.")
        uyari.addButton(withTitle: L("Geç", "Switch"))
        uyari.addButton(withTitle: L("Vazgeç", "Cancel"))
        NSApp.activate()
        guard uyari.runModal() == .alertFirstButtonReturn else { return }
        if aramaModeli.isEmpty { aramaModeli = modelKimligi }
        duraklat()
        model = yeni
        modelHazir = false
        tasimaDurumu = L("Yeni model hazırlanıyor…", "Preparing the new model…")
        tasiniyor = true
        modeliIndir { [weak self] in
            guard let self else { return }
            self.tasiniyor = false
            self.tasimaDurumu = L("Yeni model hazır; katalog taranıyor.", "New model ready; scanning the catalog.")
            self.taramaSuruyordu = true
            self.taramayaHazirlan()
        }
    }

    /// Model ve dizinleri kullanıcının seçtiği başka bir klasöre taşır (ör. harici SSD). Taşıma sırasında tarama durur.
    func kayitYeriniTasi() {
        let p = NSOpenPanel()
        p.canChooseDirectories = true
        p.canChooseFiles = false
        p.canCreateDirectories = true
        p.prompt = L("Buraya taşı", "Move here")
        guard p.runModal() == .OK, let hedef = p.url, hedef.path != kayitYeri.path else { return }
        let kaynak = kayitYeri
        duraklat()
        tasiniyor = true
        tasimaDurumu = L("Taşınıyor… Bu sırada arama yapılamaz.", "Moving… Search is unavailable meanwhile.")
        Task.detached {
            let fm = FileManager.default
            var hata: String?
            for ad in ["modeller", "kataloglar"] where fm.fileExists(atPath: kaynak.appendingPathComponent(ad).path) {
                do { try fm.moveItem(at: kaynak.appendingPathComponent(ad), to: hedef.appendingPathComponent(ad)) }
                catch { hata = error.localizedDescription; break }
            }
            let sonHata = hata
            await MainActor.run {
                self.tasiniyor = false
                if let hata = sonHata {
                    self.tasimaDurumu = L("Taşınamadı: ", "Could not move: ") + hata
                } else {
                    self.kayitYeriYolu = hedef.path
                    self.metinModeli = nil
                    self.aramaDizinleri = [:]
                    self.tasimaDurumu = L("Taşındı.", "Moved.")
                    self.metniOnYukle()
                    self.taramayaHazirlan()
                }
            }
        }
    }

    func katalogTaraniyor(_ kimlik: String) -> Bool { katalogKarari(kimlik) ?? (katalog?.kimlik == kimlik) }

    func katalogTaramasiniDegistir(_ k: Lightroom.Katalog) {
        let yeni = !katalogTaraniyor(k.kimlik)
        katalogKararlari = katalogKararlari.split(separator: ";").filter { !$0.hasPrefix(k.kimlik + "=") }
            .map(String.init).joined(separator: ";") + ";\(k.kimlik)=\(yeni ? 1 : 0);"
        if yeni {
            katalog = k
            taramayaHazirlan()
        } else if katalog?.kimlik == k.kimlik {
            duraklat()
        }
    }

    // MARK: Birden çok katalog

    func katalogKarari(_ kimlik: String) -> Bool? {
        katalogKararlari.split(separator: ";").first { $0.hasPrefix(kimlik + "=") }.map { $0.hasSuffix("=1") }
    }

    /// LrC'de başka bir katalog açılıp eşitlendi. Taşınmış aynı katalogsa dizini sessizce devralır;
    /// değilse kullanıcıya bir kez sorar ("Hayır" denirse o katalog taranmaz; Okan, 9 Ekim 2026).
    func yeniKatalog(_ k: Lightroom.Katalog) {
        if let eski = tasinmisKatalog(k) {
            let kok = kayitYeri.appendingPathComponent("kataloglar")
            try? FileManager.default.moveItem(at: kok.appendingPathComponent(eski), to: kok.appendingPathComponent(k.kimlik))
            katalog = k
            taramayaHazirlan()
            return
        }
        var karar = katalogKarari(k.kimlik)
        if karar == nil {
            let uyari = NSAlert()
            uyari.messageText = L("Yeni katalog: \(k.ad)", "New catalog: \(k.ad)")
            uyari.informativeText = L("Lightroom'da başka bir katalog açtınız (\(sayi(k.ozet.asil)) kare). Fotora bu kataloğu da tarasın mı? Taranan kataloglar ayrı ayrı aranır; bu tercihi sonra değiştirebilirsiniz.",
                                      "You opened another catalog in Lightroom (\(sayi(k.ozet.asil)) photos). Should Fotora scan this catalog too? Each scanned catalog is searched separately; you can change this later.")
            uyari.addButton(withTitle: L("Evet, tara", "Yes, scan"))
            uyari.addButton(withTitle: L("Hayır", "No"))
            NSApp.activate()
            let evet = uyari.runModal() == .alertFirstButtonReturn
            katalogKararlari += "\(k.kimlik)=\(evet ? 1 : 0);"
            karar = evet
        }
        if karar == true {
            katalog = k
            taramayaHazirlan()
        }
    }

    /// Yeni görünen katalog, taşınmış (yolu değişmiş) eski bir katalog mu? Listedeki ilk 500 karenin
    /// en az %90'ı eski bir dizinde varsa evet: o dizinin kimliği döner, yeniden tarama gerekmez.
    private func tasinmisKatalog(_ k: Lightroom.Katalog) -> String? {
        let kok = kayitYeri.appendingPathComponent("kataloglar")
        guard let ornek = try? Liste.oku(k.liste).prefix(500).map(\.uuid), !ornek.isEmpty,
              let dizinler = try? FileManager.default.contentsOfDirectory(atPath: kok.path) else { return nil }
        for d in dizinler where d != k.kimlik {
            let dosya = dizinDosyasi(d)
            guard FileManager.default.fileExists(atPath: dosya.path), let dz = try? Dizin(dosya, model: modelKimligi) else { continue }
            let var_ = dz.kimlikler()
            if ornek.filter({ var_.contains($0) }).count * 10 >= ornek.count * 9 { return d }
        }
        return nil
    }

    /// Okunamayan karelerin kimliklerini eklentiye bırakır: eklenti bir sonraki eşitlemede (LrC açılışı ya da menü)
    /// bunları "Fotora" kümesinde bir koleksiyonda toplar ve LrC'nin önizlemelerini Fotora'ya verir.
    func okunamayanlariBildir() {
        guard let k = katalog else { return }
        let kimlikler = sorunlular.filter { $0.durum == "hata" }.map(\.uuid)
        if let veri = try? JSONSerialization.data(withJSONObject: kimlikler) {
            try? veri.write(to: k.klasor.appendingPathComponent("okunamayanlar.json"), options: .atomic)
        }
    }

    nonisolated static func pildeMi() -> Bool {
        guard let bilgi = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let tur = IOPSGetProvidingPowerSourceType(bilgi)?.takeUnretainedValue() else { return false }
        return (tur as String) == kIOPSBatteryPowerValue
    }
}
