import CryptoKit
import Foundation

/// Tek bir büyük dosyayı ilerlemesini bildirerek indirir, boyutunu ve SHA-256'sını denetler.
/// ponytail: yarıda kalan indirme baştan başlar; yavaş bağlantılarda kaldığı yerden sürdürme (resumeData) eklenebilir.
final class Indirici: NSObject, URLSessionDownloadDelegate {
    private let hedef: URL
    private let ilerleme: (Double) -> Void
    private var devam: CheckedContinuation<Void, Error>?
    private var tasimaHatasi: Error?

    private init(hedef: URL, ilerleme: @escaping (Double) -> Void) { self.hedef = hedef; self.ilerleme = ilerleme }

    static func indir(_ adres: URL, hedef: URL, boyut: Int, sha256: String, ilerleme: @escaping (Double) -> Void) async throws {
        let i = Indirici(hedef: hedef, ilerleme: ilerleme)
        let oturum = URLSession(configuration: .default, delegate: i, delegateQueue: nil)
        defer { oturum.finishTasksAndInvalidate() }
        try await withCheckedThrowingContinuation { c in
            i.devam = c
            oturum.downloadTask(with: adres).resume()
        }
        let gercek = (try? hedef.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard gercek == boyut, try ozet(hedef) == sha256 else {
            try? FileManager.default.removeItem(at: hedef)
            throw NSError(domain: "Fotora", code: 3, userInfo: [NSLocalizedDescriptionKey: L("İndirilen model dosyası bozuk geldi. Yeniden deneyin.", "The downloaded model file is damaged. Please try again.")])
        }
    }

    static func ozet(_ dosya: URL) throws -> String {
        let f = try FileHandle(forReadingFrom: dosya)
        defer { try? f.close() }
        var h = SHA256()
        while let parca = try f.read(upToCount: 8 << 20), !parca.isEmpty { h.update(data: parca) }
        return h.finalize().map { String(format: "%02x", $0) }.joined()
    }

    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didWriteData _: Int64, totalBytesWritten y: Int64, totalBytesExpectedToWrite t: Int64) {
        if t > 0 { ilerleme(Double(y) / Double(t)) }
    }

    func urlSession(_ s: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo konum: URL) {
        // Geçici dosya bu fonksiyon dönünce silinir; hemen taşınır.
        if let r = downloadTask.response as? HTTPURLResponse, r.statusCode != 200 {
            tasimaHatasi = NSError(domain: "Fotora", code: r.statusCode, userInfo: [NSLocalizedDescriptionKey: L("Model sunucusu cevap vermedi (\(r.statusCode)).", "The model server did not respond (\(r.statusCode)).")])
            return
        }
        do {
            try? FileManager.default.removeItem(at: hedef)
            try FileManager.default.moveItem(at: konum, to: hedef)
        } catch { tasimaHatasi = error }
    }

    func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError hata: Error?) {
        if let e = hata ?? tasimaHatasi { devam?.resume(throwing: e) } else { devam?.resume() }
        devam = nil
    }
}
