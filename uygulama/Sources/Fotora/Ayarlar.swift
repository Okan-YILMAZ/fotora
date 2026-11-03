import SwiftUI

/// Ayarlar penceresi (tasarım tuvali, "Ayarlar", 10 Ekim 2026): Genel, Model ve Disk, Kataloglar, Bakım.
/// Menü çubuğu panelinden ve ⌘, ile açılır.
struct AyarlarPenceresi: View {
    @EnvironmentObject var u: Uygulama

    var body: some View {
        TabView {
            Genel().tabItem { Label(L("Genel", "General"), systemImage: "gearshape") }
            ModelVeDisk().tabItem { Label(L("Model ve Disk", "Model & Disk"), systemImage: "externaldrive") }
            Kataloglar().tabItem { Label(L("Kataloglar", "Catalogs"), systemImage: "square.grid.2x2") }
            BakimSekmesi().tabItem { Label(L("Bakım", "Maintenance"), systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 620, height: 400)
        .environmentObject(u)
    }
}

private struct Satir<Icerik: View>: View {
    let baslik: String
    @ViewBuilder var icerik: Icerik
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(baslik).foregroundStyle(Renk.ikincil).frame(width: 140, alignment: .trailing)
            VStack(alignment: .leading, spacing: 8) { icerik }
            Spacer(minLength: 0)
        }
        .font(.system(size: 13))
    }
}

private struct Kutu<Icerik: View>: View {
    let baslik: String
    let alt: String
    @ViewBuilder var sag: Icerik
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(baslik).font(.system(size: 13, weight: .semibold))
                Text(alt).font(.system(size: 12)).foregroundStyle(Renk.ikincil).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            sag
        }
        .padding(12)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi))
    }
}

private struct Genel: View {
    @EnvironmentObject var u: Uygulama
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Satir(baslik: L("Dil", "Language")) {
                Picker("", selection: Binding(get: { Dil.kod }, set: { u.diliSec($0) })) {
                    Text("Türkçe").tag("tr")
                    Text("English").tag("en")
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 200)
                Text(L("Lightroom'daki Fotora menülerinin dili, Lightroom kapatılıp yeniden açıldığında değişir.",
                       "The language of the Fotora menus in Lightroom changes after Lightroom is quit and reopened."))
                    .font(.system(size: 12)).foregroundStyle(Renk.ikincil).fixedSize(horizontal: false, vertical: true)
            }
            Satir(baslik: L("Tarama", "Scanning")) {
                Toggle(L("Tarama sürerken Mac uyumasın", "Keep the Mac awake while scanning"), isOn: Binding(get: { u.uykuEngelle }, set: { u.uykuEngelle = $0 }))
                Toggle(L("Pil gücündeyken duraklat", "Pause on battery power"), isOn: Binding(get: { u.pildeDuraklat }, set: { u.pildeDuraklat = $0 }))
                Toggle(L("Yeni fotoğrafları kendiliğinden tara", "Scan new photos automatically"), isOn: Binding(get: { u.otomatikTara }, set: { u.otomatikTara = $0 }))
            }
            .toggleStyle(.checkbox)
            Satir(baslik: L("Görünüm", "Appearance")) {
                Picker("", selection: Binding(get: { u.gorunum }, set: { u.gorunum = $0 })) {
                    Text(L("Sistem gibi", "System")).tag("sistem")
                    Text(L("Açık", "Light")).tag("acik")
                    Text(L("Koyu", "Dark")).tag("koyu")
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 260)
            }
            Spacer()
        }
        .padding(24)
    }
}

private struct ModelVeDisk: View {
    @EnvironmentObject var u: Uygulama
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Kutu(baslik: L("Model: ", "Model: ") + u.modelAdi + (u.model == "hizli" ? " (SigLIP 2 Base)" : " (SigLIP 2 So400m)"),
                 alt: u.model == "hizli" ? L("Hızlı ve hafif · 1,1 GB", "Fast and light · 1.1 GB") : L("Yazıyla aramada en isabetli · 3,2 GB", "Most accurate in text search · 3.2 GB")) {
                Button(u.model == "hizli" ? L("En iyi sonuca geç…", "Switch to Best results…") : L("Hızlı modele geç…", "Switch to Fast…")) { u.modeliDegistir() }
                    .disabled(u.tasiniyor)
            }
            Kutu(baslik: L("Model ve arama dizini", "Model and search index"),
                 alt: u.kayitYeriYolu + String(format: L(" · %.0f GB boş", " · %.0f GB free"), Sistem.bosAlanGB(u.kayitYeri))) {
                Button(L("Başka diske taşı…", "Move to another disk…")) { u.kayitYeriniTasi() }.disabled(u.tasiniyor)
            }
            if let t = u.tasimaDurumu {
                HStack(spacing: 8) {
                    if u.tasiniyor { ProgressView().controlSize(.small) }
                    Text(t).font(.system(size: 12)).foregroundStyle(Renk.ikincil)
                }
            }
            Text(L("Model değişirse bütün katalog yeniden taranır; yeni tarama bitene kadar eski dizinle arama sürer. Taşıma sırasında arama kısa süre kapalı kalır.",
                   "If the model changes, the whole catalog is scanned again; searches keep using the old index until the new scan finishes. Search is briefly unavailable while moving."))
                .font(.system(size: 12)).foregroundStyle(Renk.ikincil).fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .padding(24)
    }
}

private struct Kataloglar: View {
    @EnvironmentObject var u: Uygulama
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L("Lightroom'da açtığınız kataloglar burada görünür. Fotora yalnız aktif kataloglarda çalışır: onları tarar, yeni fotoğraflarını izler ve onlarda arama yapar. Arama her zaman Lightroom'da o an açık olan katalogda yapılır.",
                   "Catalogs you open in Lightroom appear here. Fotora works only in active catalogs: it scans them, follows new photos and searches them. A search always runs in the catalog currently open in Lightroom."))
                .font(.system(size: 12)).foregroundStyle(Renk.ikincil)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Lightroom.tumListeler(), id: \.kimlik) { k in
                        let acik = u.katalogTaraniyor(k.kimlik)
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(k.ad).font(.system(size: 13, weight: .semibold))
                                Text(L("\(sayi(k.ozet.asil)) kare", "\(sayi(k.ozet.asil)) photos") + (u.katalog?.kimlik == k.kimlik ? L(" · son açılan katalog", " · last opened catalog") : ""))
                                    .font(.system(size: 12)).foregroundStyle(Renk.ikincil)
                            }
                            Spacer()
                            Text(acik ? L("Fotora aktif", "Fotora active") : L("Fotora kapalı", "Fotora off"))
                                .font(.system(size: 12)).foregroundStyle(acik ? Renk.murekkep : Renk.ikincil)
                            Toggle("", isOn: Binding(get: { acik }, set: { _ in u.katalogTaramasiniDegistir(k) }))
                                .toggleStyle(.switch).labelsHidden().tint(Renk.aura)
                        }
                        .padding(.vertical, 8).padding(.horizontal, 12)
                        Divider()
                    }
                }
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Renk.cizgi))
            }
        }
        .padding(24)
    }
}

private struct BakimSekmesi: View {
    @EnvironmentObject var u: Uygulama
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Kutu(baslik: L("Tanı raporu", "Diagnostic report"),
                 alt: L("Destek için: rapor Masaüstü'ne kaydedilir ve e-posta programınızda destek@getfotora.com'a hazır bir ileti açılır; siz Gönder'e basınca gider. Fotoğraf adı, yol ya da katalog adı içermez.", "For support: the report is saved to your Desktop and a ready email to destek@getfotora.com opens in your mail app; it is sent only when you press Send. Contains no photo names, paths or catalog names.")) {
                Button(L("Oluştur", "Create")) { Bakim.taniRaporu(u) }
            }
            Kutu(baslik: "Fotora " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? L("geliştirme", "development")),
                 alt: "Lightroom Classic " + (Sistem.lrcSurumu() ?? "—") + "\n" + (u.guncelleme ?? L("Yeni sürüm yalnız bu düğmeye basınca denetlenir.", "New versions are checked only when you press this button."))) {
                Button(L("Güncellemeleri denetle", "Check for updates")) {
                    u.guncelleme = L("Denetleniyor…", "Checking…")
                    Task { u.guncelleme = await Bakim.guncellemeDenetle(u.modelAdresi) }
                }
            }
            Kutu(baslik: L("Fotora'yı kaldır", "Remove Fotora"),
                 alt: L("Model, dizin, ayarlar ve eklenti Çöp Sepeti'ne taşınır. Fotoğraflarınıza ve kataloğunuza dokunulmaz.", "Model, index, settings and plug-in are moved to the Trash. Your photos and catalog are not touched.")) {
                Button(L("Kaldır…", "Remove…")) { Bakim.herSeyiKaldir(u) }.foregroundStyle(Renk.hata)
            }
            Spacer()
        }
        .padding(24)
    }
}
