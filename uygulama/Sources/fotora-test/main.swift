import CoreGraphics
import Foundation
import FotoraCore
import ImageIO
import UniformTypeIdentifiers

// Fotora'nın otomatik testleri. Her değişiklikten sonra: swift run -c release fotora-test <model klasörü>
// Model klasörü: goruntu.mlpackage, metin.mlpackage ve tokenizer dosyaları (geliştirmede kesif/coreml).
// Altın değerler testdata/altin.json'da; model ya da kütüphane değişince bozulmayı yakalar.
// İlk kez ya da bilerek model değiştirince: ... fotora-test <model klasörü> --altin-yaz

let a = CommandLine.arguments
guard a.count >= 2 else { print("kullanım: fotora-test <model klasörü> [--altin-yaz]"); exit(2) }
let modelKlasoru = URL(fileURLWithPath: a[1])
let altinYaz = a.contains("--altin-yaz")
let altinDosya = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../../testdata/altin.json").standardized
let gecici = FileManager.default.temporaryDirectory.appendingPathComponent("fotora-test-\(getpid())")
try FileManager.default.createDirectory(at: gecici, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: gecici) }

var basarisiz = 0
func dene(_ ad: String, _ kosul: Bool, _ ayrinti: @autoclosure () -> String = "") {
    print((kosul ? "✓ " : "✗ ") + ad + (kosul ? "" : "  " + ayrinti()))
    if !kosul { basarisiz += 1 }
}
func kosinus(_ x: [Float], _ y: [Float]) -> Float { zip(x, y).reduce(0) { $0 + $1.0 * $1.1 } }

/// Kişisel fotoğraf kullanmadan sabit test görüntüsü: renk geçişi ve şekiller (tohuma göre).
func ornekGoruntu(_ tohum: Int, gen: Int = 800, yuk: Int = 600) -> CGImage {
    let ctx = CGContext(data: nil, width: gen, height: yuk, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let r = CGFloat(tohum % 7) / 7, g = CGFloat(tohum % 5) / 5, b = CGFloat(tohum % 3) / 3
    ctx.setFillColor(CGColor(red: r, green: g, blue: b, alpha: 1)); ctx.fill(CGRect(x: 0, y: 0, width: gen, height: yuk))
    for i in 0..<6 {
        ctx.setFillColor(CGColor(red: 1 - r, green: CGFloat(i) / 6, blue: 1 - b, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 60 + i * 110, y: 80 + (i * tohum * 37) % 300, width: 90 + tohum * 7, height: 90))
    }
    return ctx.makeImage()!
}

func jpegYaz(_ g: CGImage, _ url: URL, yon: Int = 1) {
    let d = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(d, g, [kCGImagePropertyOrientation: yon] as CFDictionary)
    CGImageDestinationFinalize(d)
}

// 1. Görüntü okuma: hatalar ve yön
do {
    do { _ = try Goruntu.ac(gecici.appendingPathComponent("yok.jpg").path); dene("olmayan dosya hata verir", false) }
    catch GoruntuHatasi.dosyaYok { dene("olmayan dosya: 'Dosya bulunamadı'", true) }
    do { _ = try Goruntu.ac("/Volumes/FotoraTestDiskYok/a.jpg"); dene("bağlı olmayan disk hata verir", false) }
    catch GoruntuHatasi.diskYok(let d) { dene("bağlı olmayan disk: 'Disk bağlı değil'", d == "FotoraTestDiskYok", d) }
    let dik = gecici.appendingPathComponent("yon6.jpg")
    jpegYaz(ornekGoruntu(1), dik, yon: 6) // 800x600 kayıtlı, EXIF 6: dik görünmeli
    let g = try Goruntu.ac(dik.path)
    dene("EXIF yönü uygulanır (yatay kayıt → dik)", g.height > g.width, "\(g.width)x\(g.height)")
    dene("uzun kenar en çok 1024", max(g.width, g.height) <= 1024)
}

// 2. Dizin: yazma, kaldığı yerden devam, silme, model değişikliği
do {
    let yol = gecici.appendingPathComponent("d/dizin.sqlite")
    let k = (0..<4).map { Kare(uuid: "U\($0)", yol: "/x/\($0).jpg", bicim: "JPG", sanal: false, asil_uuid: nil) }
    var dz: Dizin? = try Dizin(yol, model: "m1")
    try dz!.yaz([(k[0], .tamam([Float](repeating: 0.5, count: 4))), (k[1], .hata("Dosya okunamadı")), (k[2], .bekliyor("Disk bağlı değil: X"))])
    dz = nil
    let dz2 = try Dizin(yol, model: "m1")
    dene("yeniden açınca bitenler korunur", dz2.bitenler() == ["U0"], "\(dz2.bitenler())")
    dene("sorunlular: hata + bekliyor", dz2.sorunlular().count == 2)
    try dz2.sil(["U0"])
    dene("silinen dizinden çıkar", !dz2.kimlikler().contains("U0"))
    do { _ = try Dizin(yol, model: "m2"); dene("başka modelle açılmaz", false) } catch { dene("başka modelle açılmaz", true) }
}

// 3. Model: altın değerlerle karşılaştırma
struct Altin: Codable { var parcalar: [String: [Int]]; var metin: [String: [Float]]; var goruntu: [String: [Float]] }
let gm = try GoruntuModeli(paket: modelKlasoru.appendingPathComponent("goruntu.mlpackage"), onbellek: gecici.appendingPathComponent("derli"))
let mm = try await MetinModeli(klasor: modelKlasoru, onbellek: gecici.appendingPathComponent("derli"))
let cumleler = ["bir köpek fotoğrafı", "a photo of a dog", "sisli ormanda yürüyen biri", "ŞEMSİYELİ Kadın, İstanbul'da"]
var simdi = Altin(parcalar: [:], metin: [:], goruntu: [:])
for c in cumleler {
    simdi.parcalar[c] = mm.parcalar(c).filter { $0 != 0 }
    simdi.metin[c] = try mm.vektor(c)
}
for t in 1...3 {
    let u = gecici.appendingPathComponent("o\(t).jpg")
    jpegYaz(ornekGoruntu(t), u)
    simdi.goruntu["ornek\(t)"] = try gm.vektor(dosya: u.path)
}
if altinYaz {
    try JSONEncoder().encode(simdi).write(to: altinDosya)
    print("altın değerler yazıldı: \(altinDosya.path)")
} else if let veri = try? Data(contentsOf: altinDosya), let altin = try? JSONDecoder().decode(Altin.self, from: veri) {
    for c in cumleler {
        dene("parçalama aynı: \(c)", altin.parcalar[c] == simdi.parcalar[c], "\(simdi.parcalar[c] ?? [])")
        let k = kosinus(altin.metin[c] ?? [], simdi.metin[c] ?? [])
        dene("metin vektörü aynı: \(c)", k > 0.999, "kosinüs \(k)")
    }
    for (ad, v) in altin.goruntu {
        let k = kosinus(v, simdi.goruntu[ad] ?? [])
        dene("görüntü vektörü aynı: \(ad)", k > 0.995, "kosinüs \(k)")
    }
} else {
    dene("altın değer dosyası var (\(altinDosya.path))", false, "önce --altin-yaz ile oluşturun")
}

// 4. Tarama: kaldığı yerden devam
do {
    let kareler = (1...3).map { Kare(uuid: "T\($0)", yol: gecici.appendingPathComponent("o\($0).jpg").path, bicim: "JPG", sanal: false, asil_uuid: nil) }
    let dz = try Dizin(gecici.appendingPathComponent("t/dizin.sqlite"), model: gm.ad)
    var ilk = 0, ikinci = 0
    try Tarayici(model: gm, dizin: dz).tara(kareler) { ilk = $0.biten }
    try Tarayici(model: gm, dizin: dz).tara(kareler) { ikinci = $0.biten }
    dene("tarama 3 kareyi bitirir", ilk == 3, "\(ilk)")
    dene("ikinci taramada yeniden iş yapılmaz", ikinci == 0 && dz.bitenler().count == 3)
    let ad = try AramaDizini(gecici.appendingPathComponent("t/dizin.sqlite"))
    let ilkSonuc = ad.ara(ad.vektor("T2")!, adet: 1)
    dene("bir kare kendine en benzer", ilkSonuc.first?.uuid == "T2")
    dene("kapsamla arama yalnız kapsamdakileri döndürür", ad.ara(ad.vektor("T2")!, adet: 3, kapsam: ["T1", "T3"]).allSatisfy { $0.uuid != "T2" })
    // T4, T1'in birebir kopyası: neredeyse aynı eşiğinde birlikte gruplanır, kapsam dışındaysa gruplanmaz.
    try Tarayici(model: gm, dizin: dz).tara([Kare(uuid: "T4", yol: kareler[0].yol, bicim: "JPG", sanal: false, asil_uuid: nil)]) { _ in }
    let ad2 = try AramaDizini(gecici.appendingPathComponent("t/dizin.sqlite"))
    let g = ad2.gruplar(nil, esik: 0.985)
    dene("kopya kare grubu bulunur", g.gruplar.contains { Set($0) == ["T1", "T4"] }, "\(g.gruplar)")
    let g2 = ad2.gruplar(["T2", "T4", "YOK"], esik: 0.985)
    dene("kapsam dışı kare gruba girmez, taranmamış sayılır", g2.gruplar.isEmpty && g2.taranmamis == 1, "\(g2)")
}

print(basarisiz == 0 ? "\nBütün testler geçti." : "\n\(basarisiz) test başarısız.")
exit(basarisiz == 0 ? 0 : 1)
