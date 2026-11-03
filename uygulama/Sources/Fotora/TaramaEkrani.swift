import SwiftUI

/// Kurulumdan sonraki ana pencere: taramadan önce, sürerken, bitince (tasarım tuvali, ekran 7-10).
struct TaramaEkrani: View {
    @EnvironmentObject var u: Uygulama
    @Environment(\.dismissWindow) var pencereyiKapat

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let h = u.taramaHatasi {
                Baslik(metin: L("Bir sorun çıktı", "Something went wrong"))
                Not(metin: h, uyari: true)
                Button(L("Yeniden dene", "Try again")) { u.taramaHatasi = nil; u.taramayaHazirlan() }.buttonStyle(AnaDugme())
                Spacer()
            } else {
                switch u.tarama {
                case .hazirlaniyor: hazirlaniyor
                case .hazir: ozet
                case .suruyor, .duraklatildi: suruyor
                case .bitti: bitti
                }
            }
        }
        .padding(.horizontal, 40).padding(.vertical, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Renk.zemin)
        .sheet(isPresented: $u.sorunlarAcik) { Okunamayanlar().environmentObject(u) }
    }

    var hazirlaniyor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Baslik(metin: L("Tarama hazırlanıyor", "Preparing the scan"))
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text(L("Fotoğraf listesi okunuyor, bu Mac'in hızı ölçülüyor…", "Reading the photo list and measuring this Mac's speed…")).font(.system(size: 13)).foregroundStyle(Renk.ikincil)
            }
            Not(metin: L("macOS bir disk için izin isterse \"İzin Ver\"e (Allow) basın. Yanlışlıkla reddettiyseniz: System Settings › Privacy & Security › Files and Folders › Fotora'da ilgili diski açın, sonra Fotora'yı yeniden başlatın.",
                         "If macOS asks for permission for a disk, click \"Allow\". If you declined by mistake: in System Settings › Privacy & Security › Files and Folders › Fotora, turn the disk on, then restart Fotora."))
            Spacer()
        }
    }

    var ozet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Baslik(metin: u.taranacak == 0 ? L("Taranacak yeni fotoğraf yok", "No new photos to scan") : L("Taramaya hazır", "Ready to scan"))
            HStack(spacing: 10) {
                kutu(sayi(u.taranacak), L("kare şimdi taranacak", "photos to scan now"))
                kutu(u.tahminiSaniye.map(sureAraligi) ?? "—", L("bu Mac'te tahmini süre", "estimated time on this Mac"))
                kutu(sayi(u.katalog?.ozet.sanal ?? 0), L("sanal kopya, ayrıca taranmaz", "virtual copies, not scanned separately"))
            }
            ForEach(u.bekleyenDiskler.sorted(by: { $0.key < $1.key }), id: \.key) { d, n in
                Not(metin: L("\(d) diski bağlı değil. Bu diskteki \(sayi(n)) kare, disk bağlandığında taranır.", "Disk \(d) is not connected. Its \(sayi(n)) photos will be scanned when it is connected."), uyari: true)
            }
            Toggle(isOn: Binding(get: { u.uykuEngelle }, set: { u.uykuEngelle = $0 })) { secenek(L("Tarama sürerken Mac uyumasın", "Keep the Mac awake while scanning"), L("Yalnız tarama süresince. Mac'in enerji ayarları değişmez.", "Only during the scan. Your Mac's energy settings are not changed.")) }
            Toggle(isOn: Binding(get: { u.pildeDuraklat }, set: { u.pildeDuraklat = $0 })) { secenek(L("Pil gücündeyken duraklat", "Pause on battery power"), L("Prize takınca kendiliğinden sürer.", "Resumes automatically when plugged in.")) }
            secenek(L("Lightroom kapalıyken de devam eder", "Continues while Lightroom is closed"), L("Fotoğraf listesi alındı; tarama için Lightroom'un açık olması gerekmez.", "The photo list has been received; Lightroom does not need to be open for the scan."))
            Spacer()
            HStack {
                // Tarama başlamadan model ya da başka bir seçim değiştirilebilsin (Okan, 10 Ekim 2026).
                if !u.ilkTaramaBitti { Button(L("Geri", "Back")) { u.adim = 4 }.buttonStyle(IkincilDugme()) }
                Spacer()
                Button(L("Taramayı başlat", "Start scan")) { u.taramayiBaslat() }.buttonStyle(AnaDugme()).disabled(u.taranacak == 0)
            }
        }
        .toggleStyle(.checkbox)
    }

    var suruyor: some View {
        VStack(alignment: .leading, spacing: 18) {
            let duraklatildi: String? = { if case .duraklatildi(let n) = u.tarama { return n }; return nil }()
            HStack(spacing: 14) {
                Logo(boyut: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text(duraklatildi == nil ? L("Kareler taranıyor", "Scanning photos") : L("Tarama duraklatıldı", "Scan paused")).font(.system(size: 18, weight: .bold))
                    Text((u.katalog?.ad ?? "") + " · " + u.modelAdi).font(.system(size: 13)).foregroundStyle(Renk.ikincil)
                }
                Spacer()
                Button(duraklatildi == nil ? L("Duraklat", "Pause") : L("Sürdür", "Resume")) {
                    if duraklatildi == nil { u.duraklat() } else { u.taramayiBaslat() }
                }
                .buttonStyle(IkincilDugme())
            }
            let i = u.ilerleme
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(sayi(i?.biten ?? 0)) / \(sayi(i?.toplam ?? u.taranacak)) " + L("kare", "photos")).font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Text(duraklatildi ?? kalanMetni(i)).font(.system(size: 13)).foregroundStyle(Renk.ikincil)
                }
                ProgressView(value: Double(i?.biten ?? 0), total: Double(max(i?.toplam ?? 1, 1)))
                    .tint(duraklatildi == nil ? Renk.aura : .gray)
            }
            HStack(spacing: 10) {
                kutu(String(format: "%.1f", i?.hiz ?? 0), L("kare / saniye", "photos / second"))
                kutu(sayi(i?.hata ?? 0), L("okunamayan kare", "unreadable photos"))
                kutu(sayi(u.bekleyenDiskler.values.reduce(0, +) + (i?.bekleyen ?? 0)), L("kare diski bekliyor", "photos waiting for a disk"))
            }
            Not(metin: L("Bu pencereyi kapatabilirsiniz; tarama menü çubuğundaki Fotora simgesinden izlenir. Mac kapanırsa kaldığı yerden sürer.", "You can close this window; follow the scan from the Fotora icon in the menu bar. If the Mac shuts down, the scan resumes where it left off."))
            Spacer()
        }
    }

    var bitti: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: "checkmark.circle.fill").font(.system(size: 40)).foregroundStyle(Renk.yaprak)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L("Artık Fotora arşiviniz için kullanılabilir", "Fotora is now ready for your archive")).font(.system(size: 20, weight: .bold))
                    Text((u.katalog?.ad ?? "") + " · " + L("\(sayi(u.ilerleme?.biten ?? u.taranmisSayisi)) kare tarandı", "\(sayi(u.ilerleme?.biten ?? u.taranmisSayisi)) photos scanned")).font(.system(size: 13)).foregroundStyle(Renk.ikincil)
                }
            }
            VStack(alignment: .leading, spacing: 10) {
                Text(L("LIGHTROOM'DA ŞİMDİ DENEYİN", "TRY IT IN LIGHTROOM NOW")).font(.system(size: 12, weight: .bold)).foregroundStyle(Renk.yazi3)
                Text(L("1. Library › Plug-in Extras › Fotora › Gündelik Dille Ara… Örneğin \"yağmurda şemsiyeli kadın\" yazın.", "1. Library › Plug-in Extras › Fotora › Search in Everyday Language… For example, type \"woman with an umbrella in the rain\".")).font(.system(size: 13))
                Text(L("2. Bir kare seçin, Library › Plug-in Extras › Fotora › Benzerlerini Bul.", "2. Select a photo, then Library › Plug-in Extras › Fotora › Find Similar.")).font(.system(size: 13))
                Text(L("3. Sonuçlar \"Fotora\" koleksiyon kümesinde açılır.", "3. Results open in the \"Fotora\" collection set.")).font(.system(size: 13))
            }
            .padding(14).frame(maxWidth: .infinity, alignment: .leading)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi))
            let hata = u.sorunlular.filter { $0.durum == "hata" }.count
            if hata > 0 {
                HStack {
                    Text(L("\(sayi(hata)) kare okunamadı", "\(sayi(hata)) photos could not be read")).foregroundStyle(Renk.uyariYazi)
                    Spacer()
                    Button(L("Nedenlerini gör", "See why")) { u.sorunlarAcik = true }.buttonStyle(.link)
                }
                .font(.system(size: 13)).padding(10).background(Renk.uyariZemin, in: RoundedRectangle(cornerRadius: 8))
            }
            ForEach(u.bekleyenDiskler.sorted(by: { $0.key < $1.key }), id: \.key) { d, n in
                Not(metin: L("\(d) diskindeki \(sayi(n)) kare bekliyor; disk bağlanınca taranır.", "\(sayi(n)) photos on \(d) are waiting; they will be scanned when the disk is connected."))
            }
            Spacer()
            HStack(alignment: .center) {
                Text(L("Fotora menü çubuğunda bekler ve yeni fotoğrafları kendiliğinden tarar. Kapatsanız bile Lightroom'dan arama yaptığınızda kendiliğinden açılır.",
                       "Fotora waits in the menu bar and scans new photos automatically. Even if you quit it, it opens by itself when you search from Lightroom."))
                    .font(.system(size: 12)).foregroundStyle(Renk.ikincil).fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 24)
                Button(L("Tamam", "Done")) { pencereyiKapat(id: "ana") }.buttonStyle(AnaDugme()).keyboardShortcut(.defaultAction)
            }
        }
    }

    func kalanMetni(_ i: FotoraCoreIlerleme?) -> String {
        guard let s = i?.kalanSaniye else { return L("Süre hesaplanıyor…", "Calculating time…") }
        let bitis = Date().addingTimeInterval(s).formatted(date: .omitted, time: .shortened)
        return L("\(sure(s).capitalizedFirst) kaldı, \(bitis) civarı biter", "\(sure(s).capitalizedFirst) left, finishes around \(bitis)")
    }

    func kutu(_ ust: String, _ alt: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(ust).font(.system(size: 18, weight: .bold))
            Text(alt).font(.system(size: 12)).foregroundStyle(Renk.ikincil)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi))
    }

    func secenek(_ a: String, _ b: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(a).font(.system(size: 13, weight: .semibold))
            Text(b).font(.system(size: 12)).foregroundStyle(Renk.ikincil)
        }
    }
}

struct Okunamayanlar: View {
    @EnvironmentObject var u: Uygulama
    @Environment(\.dismiss) var kapat

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let hatalar = u.sorunlular.filter { $0.durum == "hata" }
            Baslik(metin: L("\(sayi(hatalar.count)) kare okunamadı", "\(sayi(hatalar.count)) photos could not be read"))
            Aciklama(metin: L("Bu kareler aramada çıkmaz. Kataloğunuz ve dosyalarınız değişmedi. \"Yeniden dene\" bir sonraki taramada bu kareleri tekrar dener.", "These photos will not appear in searches. Your catalog and files were not changed. \"Try again\" retries them in the next scan."))
            Table(hatalar.map { Satir(yol: $0.yol, neden: $0.neden) }) {
                TableColumn(L("Dosya", "File")) { Text($0.yol).lineLimit(1).truncationMode(.head) }
                TableColumn(L("Neden", "Reason")) { Text(Self.nedenMetni($0.neden)) }
                TableColumn(L("Ne yapabilirsiniz", "What you can do")) { Text(oneri($0.neden)).fixedSize(horizontal: false, vertical: true) }
            }
            Text(L("Lightroom'da görmek için Library › Plug-in Extras › Fotora › Fotoğraf Listesini Eşitle'yi seçin: bu kareler \"Fotora\" kümesinde \"Okunamayanlar\" koleksiyonunda toplanır. Lightroom açabildiği karelerin önizlemesini de Fotora'ya verir; \"Yeniden dene\" onları önizlemeden tarar.",
                   "To see them in Lightroom, choose Library › Plug-in Extras › Fotora › Sync Photo List: they are gathered in the \"Unreadable\" collection in the \"Fotora\" set. Lightroom also hands Fotora a preview of the photos it can open; \"Try again\" scans them from that preview."))
                .font(.system(size: 12)).foregroundStyle(Renk.ikincil).fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button(L("Yeniden dene", "Try again")) { kapat(); u.taramayaHazirlan() }.buttonStyle(IkincilDugme())
                Button(L("Kapat", "Close")) { kapat() }.buttonStyle(AnaDugme())
            }
        }
        .padding(28)
        .frame(width: 720, height: 500)
    }

    struct Satir: Identifiable { let id = UUID(); let yol: String; let neden: String }

    /// Tarama motoru nedeni Türkçe kaydeder (FotoraCore); ekranda seçili dile çevrilir.
    static func nedenMetni(_ n: String) -> String {
        if n.contains("bulunamadı") { return L(n, "File not found") }
        if n.hasPrefix("Disk bağlı değil") { return L(n, "Disk not connected: " + n.replacingOccurrences(of: "Disk bağlı değil: ", with: "")) }
        return L(n, "File could not be read or format not supported")
    }

    func oneri(_ n: String) -> String {
        if n.contains("bulunamadı") { return L("Dosya taşınmış olabilir. Lightroom'da \"Eksik fotoğrafı bul\" ile yerini gösterin.", "The file may have moved. Locate it in Lightroom with \"Find Missing Photo\".") }
        if n.contains("Disk") { return L("Diski bağlayın; Fotora kendiliğinden tarar.", "Connect the disk; Fotora scans it automatically.") }
        return L("Dosyayı Lightroom'da açmayı deneyin; açılmıyorsa yedekten geri alın.", "Try opening the file in Lightroom; if it does not open, restore it from a backup.")
    }
}

typealias FotoraCoreIlerleme = TarayiciIlerleme

extension String {
    var capitalizedFirst: String { prefix(1).uppercased() + dropFirst() }
}
