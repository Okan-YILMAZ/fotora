import AppKit
import Foundation

/// Kurulumdan önceki Mac kontrolü. Her madde: ad, değer, uygun mu, uygun değilse ne yapılacağı.
struct Kontrol: Identifiable {
    let id = UUID()
    let ad: String
    let deger: String
    let uygun: Bool
}

enum Sistem {
    static let gerekenAlanGB = 3.2 // So400m: model 2,3 + 200 bin karelik dizin 0,9

    static func sysctl(_ ad: String) -> String {
        var n = 0
        sysctlbyname(ad, nil, &n, nil, 0)
        var b = [CChar](repeating: 0, count: max(n, 1))
        sysctlbyname(ad, &b, &n, nil, 0)
        return String(cString: b)
    }

    static func bosAlanGB(_ url: URL) -> Double {
        // Kayıt klasörü henüz yoksa (ilk kurulum) var olan en yakın üst klasörün diskine bakılır.
        var url = url
        while !FileManager.default.fileExists(atPath: url.path), url.path != "/" { url = url.deletingLastPathComponent() }
        let v = try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return Double(v?.volumeAvailableCapacityForImportantUsage ?? 0) / 1e9
    }

    /// Nereye kurulmuş olursa olsun (Launch Services'e sorulur); bulunamazsa Adobe'nin varsayılan yeri.
    static var lrcUygulamasi: URL {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.adobe.LightroomClassicCC7")
            ?? URL(fileURLWithPath: "/Applications/Adobe Lightroom Classic/Adobe Lightroom Classic.app")
    }

    static func lrcSurumu() -> String? {
        Bundle(url: lrcUygulamasi)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }

    static func kontroller(kayitYeri: URL) -> [Kontrol] {
        var k: [Kontrol] = []
        var arm = 0
        var n = MemoryLayout<Int>.size
        sysctlbyname("hw.optional.arm64", &arm, &n, nil, 0)
        let islemci = sysctl("machdep.cpu.brand_string")
        k.append(Kontrol(ad: L("İşlemci", "Processor"), deger: arm == 1 ? islemci : "\(islemci): " + L("Fotora yalnız Apple çipli Mac'lerde çalışır", "Fotora only runs on Macs with Apple silicon"), uygun: arm == 1))
        let s = ProcessInfo.processInfo.operatingSystemVersion
        k.append(Kontrol(ad: "macOS", deger: "macOS \(s.majorVersion).\(s.minorVersion)", uygun: s.majorVersion >= 14))
        let ram = Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824
        k.append(Kontrol(ad: "Bellek", deger: String(format: "%.0f GB", ram) + (ram >= 15 ? L(" (en iyi model için yeterli)", " (enough for the best model)") : L(" (hızlı model önerilir)", " (fast model recommended)")), uygun: true))
        let bos = bosAlanGB(kayitYeri)
        k.append(Kontrol(ad: L("Boş disk", "Free disk"), deger: String(format: L("%.0f GB (gereken yaklaşık %.1f GB; harici diske de kurulabilir)", "%.0f GB (about %.1f GB needed; can also go on an external disk)"), bos, gerekenAlanGB), uygun: bos >= gerekenAlanGB))
        let lrc = lrcSurumu()
        k.append(Kontrol(ad: "Lightroom Classic", deger: lrc.map { L("Kurulu, sürüm ", "Installed, version ") + $0 } ?? L("Bulunamadı: önce Lightroom Classic'i kurun", "Not found: please install Lightroom Classic first"), uygun: lrc != nil))
        return k
    }
}
