import Foundation
import FotoraCore

// Geliştirme aracı: tarama motorunu uygulama olmadan çalıştırır.
// Kullanım: fotora-tara <liste.jsonl> <dizin.sqlite> <model.mlpackage> [--icerir <yol parçası>] [--ilk N]
let a = CommandLine.arguments
guard a.count >= 4 else {
    print("kullanım: fotora-tara <liste.jsonl> <dizin.sqlite> <model.mlpackage> [--icerir 2024/] [--ilk N]")
    exit(2)
}
func secenek(_ ad: String) -> String? { a.firstIndex(of: ad).flatMap { $0 + 1 < a.count ? a[$0 + 1] : nil } }

var kareler = try Liste.oku(URL(fileURLWithPath: a[1]))
if let p = secenek("--icerir") { kareler = kareler.filter { $0.yol.contains(p) } }
if let n = secenek("--ilk").flatMap(Int.init) { kareler = Array(kareler.prefix(n)) }

let paket = URL(fileURLWithPath: a[3])
let dizinYolu = URL(fileURLWithPath: a[2])
let model = try GoruntuModeli(paket: paket, onbellek: dizinYolu.deletingLastPathComponent().appendingPathComponent("derlenmis"))
let tarayici = Tarayici(model: model, dizin: try Dizin(dizinYolu, model: model.ad))
signal(SIGINT) { _ in exit(130) } // parti yazımı tek işlem; yarıda kesmek dizini bozmaz

print("\(kareler.count) kare")
try tarayici.tara(kareler) { i in
    let kalan = i.kalanSaniye.map { String(format: "%.0f dk", $0 / 60) } ?? "?"
    print(String(format: "%d/%d tamam, %d hata, %d bekliyor, %.1f kare/sn, kalan %@", i.biten, i.toplam, i.hata, i.bekleyen, i.hiz, kalan))
    fflush(stdout)
}
print("bitti")
