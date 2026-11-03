import FotoraCore
import SwiftUI

typealias TarayiciIlerleme = Tarayici.Ilerleme

/// Pencere kapatılıp Fotora Dock'tan ya da Applications'tan yeniden açılınca ana pencere gelsin
/// (SwiftUI tek pencereli sahneyi kendiliğinden geri açmıyor; Mac Mini denemesi, 10 Ekim 2026).
final class Temsilci: NSObject, NSApplicationDelegate {
    static var anaPencereyiAc: (() -> Void)?
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if !hasVisibleWindows { Self.anaPencereyiAc?() }
        return true
    }
}

/// Menü çubuğu simgesi: her zaman yerinde durduğu için pencere açma eylemi buradan alınır.
struct MenuSimgesi: View {
    @ObservedObject var u: Uygulama
    @Environment(\.openWindow) var pencere
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "magnifyingglass.circle")
            if case .suruyor = u.tarama, let i = u.ilerleme, i.toplam > 0 { Text("%\(i.biten * 100 / i.toplam)") }
        }
        .onAppear { Temsilci.anaPencereyiAc = { pencere(id: "ana"); NSApp.activate() } }
    }
}

@main
struct FotoraApp: App {
    @StateObject var u = Uygulama()
    @NSApplicationDelegateAdaptor(Temsilci.self) var temsilci

    var body: some Scene {
        Window("Fotora", id: "ana") {
            Group {
                if u.adim < 6 { Sihirbaz() } else { TaramaEkrani() }
            }
            .frame(width: 760, height: 520)
            .foregroundStyle(Renk.murekkep)
            .preferredColorScheme(u.gorunumSemasi)
            .environmentObject(u)
            .onAppear { if u.kurulumBitti { u.taramayaHazirlan() } }
        }
        .windowResizability(.contentSize)

        Settings {
            AyarlarPenceresi().environmentObject(u).foregroundStyle(Renk.murekkep).preferredColorScheme(u.gorunumSemasi)
        }

        MenuBarExtra {
            MenuPaneli().environmentObject(u)
        } label: {
            MenuSimgesi(u: u)
        }
        .menuBarExtraStyle(.window)
    }
}

struct MenuPaneli: View {
    @EnvironmentObject var u: Uygulama
    @Environment(\.openWindow) var pencere

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(baslik).font(.system(size: 13, weight: .bold))
                if case .bitti = u.tarama {
                    Text(L("\(sayi(u.taranmisSayisi)) kare aranabilir", "\(sayi(u.taranmisSayisi)) photos searchable"))
                        .font(.system(size: 12)).foregroundStyle(Renk.ikincil)
                } else if let i = u.ilerleme, i.toplam > 0 { // bitince son ilerleme ("1 dakikadan az kaldı") kalmasın
                    ProgressView(value: Double(i.biten), total: Double(i.toplam)).tint(Renk.aura)
                    Text("\(sayi(i.biten)) / \(sayi(i.toplam))" + (i.kalanSaniye.map { " · " + L("\(sure($0)) kaldı", "\(sure($0)) left") } ?? ""))
                        .font(.system(size: 12)).foregroundStyle(Renk.ikincil)
                }
            }
            Divider()
            VStack(alignment: .leading, spacing: 2) {
                if case .suruyor = u.tarama { satir(L("Duraklat", "Pause")) { u.duraklat() } }
                if case .duraklatildi = u.tarama { satir(L("Sürdür", "Resume")) { u.taramayiBaslat() } }
                satir(L("Dil: Türkçe → English", "Language: English → Türkçe")) { u.dilDegistir() }
                satir(L("Fotora penceresini aç", "Open Fotora window")) { pencere(id: "ana"); NSApp.activate() }
                SettingsLink { Text(L("Ayarlar…", "Settings…")).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5).padding(.horizontal, 6) }
                    .buttonStyle(.plain).font(.system(size: 13))
                satir(L("Fotora'dan çık", "Quit Fotora")) { NSApp.terminate(nil) }
            }
        }
        .padding(14)
        .frame(width: 300)
    }

    var baslik: String {
        switch u.tarama {
        case .suruyor: return L("Kareler taranıyor", "Scanning photos")
        case .duraklatildi(let n): return n
        case .bitti: return L("Tarama bitti", "Scan finished")
        default: return u.kurulumBitti ? "Fotora" : L("Kurulum sürüyor", "Setup in progress")
        }
    }

    func satir(_ ad: String, _ e: @escaping () -> Void) -> some View {
        Button(action: e) { Text(ad).frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 5).padding(.horizontal, 6) }
            .buttonStyle(.plain).font(.system(size: 13))
    }
}
