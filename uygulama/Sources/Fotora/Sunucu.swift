import Foundation
import FotoraCore
import Network

/// LrC eklentisinin aramaları için yalnız bu Mac'ten (127.0.0.1) erişilen küçük HTTP sunucusu.
/// Kapı numarası sistemden boş bir kapı istenerek alınır (8765/8766 gibi başka uygulamaların kapılarıyla çakışmaz)
/// ve eklentinin okuyacağı `baglanti.json` dosyasına yazılır.
final class Sunucu {
    static let baglantiDosyasi = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Application Support/Fotora/baglanti.json")

    let isleyici: (String, [String: Any]) async -> [String: Any]
    var dinleyici: NWListener?

    init(isleyici: @escaping (String, [String: Any]) async -> [String: Any]) { self.isleyici = isleyici }

    func baslat() throws {
        let p = NWParameters.tcp
        p.requiredLocalEndpoint = NWEndpoint.hostPort(host: "127.0.0.1", port: .any)
        let d = try NWListener(using: p)
        d.newConnectionHandler = { [weak self] b in self?.karsila(b) }
        d.stateUpdateHandler = { durum in
            if case .ready = durum, let kapi = d.port?.rawValue {
                try? FileManager.default.createDirectory(at: Self.baglantiDosyasi.deletingLastPathComponent(), withIntermediateDirectories: true)
                try? #"{"kapi":\#(kapi),"pid":\#(ProcessInfo.processInfo.processIdentifier)}"#.write(to: Self.baglantiDosyasi, atomically: true, encoding: .utf8)
            }
        }
        d.start(queue: .global())
        dinleyici = d
    }

    private func karsila(_ b: NWConnection) {
        b.start(queue: .global())
        var tampon = Data()
        func oku() {
            b.receive(minimumIncompleteLength: 1, maximumLength: 1 << 16) { veri, _, bitti, hata in
                if let veri { tampon.append(veri) }
                if let istek = Self.coz(tampon) {
                    Task {
                        let cevap = await self.isleyici(istek.yol, istek.govde)
                        let json = (try? JSONSerialization.data(withJSONObject: cevap)) ?? Data("{}".utf8)
                        var yanit = Data("HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: \(json.count)\r\nConnection: close\r\n\r\n".utf8)
                        yanit.append(json)
                        b.send(content: yanit, completion: .contentProcessed { _ in b.cancel() })
                    }
                } else if bitti || hata != nil {
                    b.cancel()
                } else {
                    oku()
                }
            }
        }
        oku()
    }

    /// Tam gelmiş bir isteği çözer: (yol, JSON gövde). Eksikse nil.
    static func coz(_ d: Data) -> (yol: String, govde: [String: Any])? {
        guard let ayrac = d.range(of: Data("\r\n\r\n".utf8)),
              let bas = String(data: d[..<ayrac.lowerBound], encoding: .utf8) else { return nil }
        let satirlar = bas.components(separatedBy: "\r\n")
        let parca = satirlar.first?.split(separator: " ") ?? []
        guard parca.count >= 2 else { return ("", [:]) }
        let uzunluk = satirlar.first { $0.lowercased().hasPrefix("content-length:") }
            .flatMap { Int($0.split(separator: ":")[1].trimmingCharacters(in: .whitespaces)) } ?? 0
        let govde = d[ayrac.upperBound...]
        guard govde.count >= uzunluk else { return nil }
        let json = (try? JSONSerialization.jsonObject(with: govde.prefix(uzunluk))) as? [String: Any] ?? [:]
        return (String(parca[1]), json)
    }
}
