import CoreGraphics
import CoreML
import Foundation
import ImageIO

public enum GoruntuHatasi: Error, CustomStringConvertible {
    case diskYok(String)
    case dosyaYok
    case okunamadi

    public var description: String {
        switch self {
        case .diskYok(let d): return "Disk bağlı değil: \(d)"
        case .dosyaYok: return "Dosya bulunamadı"
        case .okunamadi: return "Dosya okunamadı ya da biçim desteklenmiyor"
        }
    }
}

public enum Goruntu {
    static let uzunKenar = 1024
    static let enKisaKabul = 500 // daha küçük gömülü önizleme kabul edilmez (Vektörel Arama'daki eşik)

    /// macOS'un okuyucusuyla (ImageIO) kareyi açar; dosyanın kendi yönü uygulanır.
    /// Önce gömülü önizleme denenir (RAW'da hızlı); küçükse görüntünün kendisinden üretilir.
    public static func ac(_ yol: String) throws -> CGImage {
        guard FileManager.default.fileExists(atPath: yol) else {
            let parca = yol.split(separator: "/")
            if yol.hasPrefix("/Volumes/"), parca.count > 1, !FileManager.default.fileExists(atPath: "/Volumes/\(parca[1])") {
                throw GoruntuHatasi.diskYok(String(parca[1]))
            }
            throw GoruntuHatasi.dosyaYok
        }
        guard let kaynak = CGImageSourceCreateWithURL(URL(fileURLWithPath: yol) as CFURL, nil) else {
            throw GoruntuHatasi.okunamadi
        }
        func uret(_ hep: Bool) -> CGImage? {
            let s: [CFString: Any] = [
                hep ? kCGImageSourceCreateThumbnailFromImageAlways : kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: uzunKenar,
            ]
            return CGImageSourceCreateThumbnailAtIndex(kaynak, 0, s as CFDictionary)
        }
        if let g = uret(false), min(g.width, g.height) >= enKisaKabul { return g }
        if let g = uret(true) { return g }
        throw GoruntuHatasi.okunamadi
    }

    /// SigLIP işlemcisiyle aynı hazırlık: kare 384x384'e sündürülür (kırpılmaz), piksel [-1, 1] aralığına.
    public static func girdi(_ g: CGImage, boyut: Int = 384) throws -> MLMultiArray {
        var rgba = [UInt8](repeating: 0, count: boyut * boyut * 4)
        guard let ctx = CGContext(data: &rgba, width: boyut, height: boyut, bitsPerComponent: 8, bytesPerRow: boyut * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { throw GoruntuHatasi.okunamadi }
        ctx.interpolationQuality = .high
        ctx.draw(g, in: CGRect(x: 0, y: 0, width: boyut, height: boyut))
        let dizi = try MLMultiArray(shape: [1, 3, NSNumber(value: boyut), NSNumber(value: boyut)], dataType: .float16)
        let p = dizi.dataPointer.assumingMemoryBound(to: Float16.self)
        let alan = boyut * boyut
        for i in 0..<alan {
            for c in 0..<3 {
                p[c * alan + i] = Float16(Float(rgba[i * 4 + c]) / 127.5 - 1)
            }
        }
        return dizi
    }
}
