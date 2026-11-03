import Foundation
import FotoraCore

// Geliştirme aracı: dizinde yazıyla arar ya da parçalamayı gösterir.
// fotora-ara <dizin.sqlite> <model klasörü> "<cümle>" [adet]
// fotora-ara --parcala <model klasörü> "<cümle>"
let a = CommandLine.arguments
if a.count >= 4, a[1] == "--parcala" {
    let m = try await MetinModeli(klasor: URL(fileURLWithPath: a[2]), onbellek: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("fotora-derlenmis"))
    print(m.parcalar(a[3]).prefix { $0 != 0 })
    exit(0)
}
if a.count >= 5, a[1] == "--sorgular" { // model klasörü, sorgular.json, çıktı (ham float32): ölçüm için
    let m = try await MetinModeli(klasor: URL(fileURLWithPath: a[2]), onbellek: URL(fileURLWithPath: a[2]).appendingPathComponent("derlenmis"))
    let s = try JSONSerialization.jsonObject(with: Data(contentsOf: URL(fileURLWithPath: a[3]))) as! [[String: Any]]
    var v: [Float] = []
    for q in s { v += try m.vektor(q["metin"] as! String) }
    try v.withUnsafeBytes { Data($0) }.write(to: URL(fileURLWithPath: a[4]))
    exit(0)
}
if a.count >= 3, a[1] == "--gruplar" { // dizin, [eşik]: bütün dizinde gruplama süresi ve grup boyları (ölçüm için)
    var t = Date()
    let d = try AramaDizini(URL(fileURLWithPath: a[2]))
    print(String(format: "yükleme %.1f sn, %d kare", Date().timeIntervalSince(t), d.kimlikler.count))
    t = Date()
    let g = d.gruplar(nil, esik: a.count > 3 ? Float(a[3]) ?? 0.97 : 0.97).gruplar
    print(String(format: "gruplama %.1f sn: %d grup, %d kare, en büyük %@", Date().timeIntervalSince(t), g.count,
                 g.reduce(0) { $0 + $1.count }, g.map(\.count).sorted(by: >).prefix(5).description))
    exit(0)
}
guard a.count >= 4 else { print("kullanım: fotora-ara <dizin.sqlite> <model klasörü> \"cümle\" [adet]"); exit(2) }
let klasor = URL(fileURLWithPath: a[2])
var t = Date()
let m = try await MetinModeli(klasor: klasor, onbellek: klasor.appendingPathComponent("derlenmis"))
let d = try AramaDizini(URL(fileURLWithPath: a[1]))
print(String(format: "yükleme %.1f sn, %d kare", Date().timeIntervalSince(t), d.kimlikler.count))
t = Date()
let q = try m.vektor(a[3])
let sonuc = d.ara(q, adet: a.count > 4 ? Int(a[4]) ?? 10 : 10)
print(String(format: "arama %.2f sn", Date().timeIntervalSince(t)))
for r in sonuc { print(String(format: "%.3f", r.benzerlik), r.uuid) }
