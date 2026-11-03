import Foundation

/// Arayüz dili: Türkçe ya da İngilizce. Varsayılan Mac'in dili; menü çubuğu panelinden değişir.
/// Eklenti aynı seçimi ~/Library/Application Support/Fotora/ayarlar.json dosyasından okur.
enum Dil {
    static var kod: String {
        UserDefaults.standard.string(forKey: "dil")
            ?? (Locale.preferredLanguages.first?.hasPrefix("tr") == true ? "tr" : "en")
    }
    static var ingilizce: Bool { kod == "en" }

    static let ayarDosyasi = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Fotora/ayarlar.json")

    static func eklentiyeBildir() {
        try? FileManager.default.createDirectory(at: ayarDosyasi.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? #"{"dil":"\#(kod)"}"#.write(to: ayarDosyasi, atomically: true, encoding: .utf8)
    }
}

/// Metnin seçili dildeki hâli: L("Türkçe", "English").
func L(_ tr: String, _ en: String) -> String { Dil.ingilizce ? en : tr }
