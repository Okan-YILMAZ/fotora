import CoreML
import Foundation

/// Görüntü kolu: kareyi 1152 sayılık, uzunluğu 1 olan vektöre çevirir.
public final class GoruntuModeli {
    let model: MLModel
    /// Modelin adı: paketin bulunduğu klasör ("so400m", "base"). Dizin bu adla etiketlenir.
    public let ad: String
    /// Modelin beklediği kare boyu (So400m 384, Base 256).
    public let boyut: Int

    /// mlpackage ilk kullanımda derlenir; derlenmiş kopya `onbellek` klasöründe tutulur.
    public init(paket: URL, onbellek: URL) throws {
        model = try Self.yukle(paket: paket, onbellek: onbellek)
        ad = paket.deletingLastPathComponent().lastPathComponent
        boyut = model.modelDescription.inputDescriptionsByName["pixel_values"]?.multiArrayConstraint?.shape.last?.intValue ?? 384
    }

    /// Dosyadaki kareyi okuyup vektöre çevirir.
    public func vektor(dosya: String) throws -> [Float] { try vektor(Goruntu.girdi(Goruntu.ac(dosya), boyut: boyut)) }

    static func yukle(paket: URL, onbellek: URL) throws -> MLModel {
        let derli = onbellek.appendingPathComponent(paket.deletingPathExtension().lastPathComponent + ".mlmodelc")
        if !FileManager.default.fileExists(atPath: derli.path) {
            let gecici = try MLModel.compileModel(at: paket)
            try FileManager.default.createDirectory(at: onbellek, withIntermediateDirectories: true)
            try FileManager.default.moveItem(at: gecici, to: derli)
        }
        let ayar = MLModelConfiguration()
        ayar.computeUnits = .all
        return try MLModel(contentsOf: derli, configuration: ayar)
    }

    static func birimVektor(_ v: MLMultiArray) -> [Float] {
        var d = (0..<v.count).map { Float(truncating: v[$0]) }
        let n = sqrt(d.reduce(0) { $0 + $1 * $1 })
        if n > 0 { d = d.map { $0 / n } }
        return d
    }

    public func vektor(_ girdi: MLMultiArray) throws -> [Float] {
        let cikti = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["pixel_values": girdi]))
        guard let v = cikti.featureValue(for: "vektor")?.multiArrayValue else { throw GoruntuHatasi.okunamadi }
        return Self.birimVektor(v)
    }
}
