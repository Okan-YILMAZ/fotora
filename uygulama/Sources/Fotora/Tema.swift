import SwiftUI

/// Onaylanan kimlik (tasarım tuvali, 9-10 Ekim 2026). Her renk açık ve koyu görünüm için iki değerli.
enum Renk {
    static func cift(_ acik: UInt32, _ koyu: UInt32) -> Color {
        func ns(_ h: UInt32) -> NSColor {
            NSColor(srgbRed: CGFloat((h >> 16) & 0xFF) / 255, green: CGFloat((h >> 8) & 0xFF) / 255, blue: CGFloat(h & 0xFF) / 255, alpha: 1)
        }
        return Color(nsColor: NSColor(name: nil) { g in
            g.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? ns(koyu) : ns(acik)
        })
    }
    static let aura = cift(0xF0A23A, 0xF0A23A)
    /// Ana yazı ve logo çizgisi.
    static let murekkep = cift(0x1A1B1F, 0xECEBE8)
    /// Amber düğmenin üstündeki yazı: iki görünümde de koyu.
    static let dugmeYazi = cift(0x1A1B1F, 0x1A1B1F)
    static let zemin = cift(0xFFFFFF, 0x1C1D21)
    static let kum = cift(0xF4F3F1, 0x24252A)
    static let cizgi = cift(0xE3E1DD, 0x34363C)
    static let ikincil = cift(0x5C5F66, 0xA3A6AD)
    static let yazi2 = cift(0x4E5158, 0xB5B7BD)
    static let yazi3 = cift(0x3A3C42, 0xC9C9CC)
    static let yaprak = cift(0x2E7D4F, 0x4CAF7A)
    static let kehribar = cift(0x8A5200, 0xE8B566)
    static let uyariZemin = cift(0xFBF4E8, 0x3A2F1E)
    static let uyariYazi = cift(0x5E3800, 0xF2CC8F)
    static let hata = cift(0xB3261E, 0xF08A80)
    static let seciliZemin = cift(0xFFFBF4, 0x2E271C)
    static let etiketZemin = cift(0xF8D9A8, 0x5A4320)
    static let seciliAdim = cift(0xFFFFFF, 0x34363C)
}

/// Logo: büyüteç ve tam kapanmayan aura halkası (32 birimlik çizim, istenen boyuta ölçeklenir).
struct Logo: View {
    var boyut: CGFloat = 26
    var cizgi: Color = Renk.murekkep

    var body: some View {
        Canvas { ctx, size in
            let k = size.width / 32
            var halka = Path()
            halka.addArc(center: CGPoint(x: 14 * k, y: 14 * k), radius: 12.5 * k, startAngle: .degrees(0), endAngle: .degrees(265), clockwise: false)
            ctx.stroke(halka, with: .color(Renk.aura), style: StrokeStyle(lineWidth: 2 * k, lineCap: .round))
            let mercek = Path(ellipseIn: CGRect(x: 6.5 * k, y: 6.5 * k, width: 15 * k, height: 15 * k))
            ctx.stroke(mercek, with: .color(cizgi), lineWidth: 2.5 * k)
            var sap = Path()
            sap.move(to: CGPoint(x: 19.5 * k, y: 19.5 * k))
            sap.addLine(to: CGPoint(x: 27 * k, y: 27 * k))
            ctx.stroke(sap, with: .color(cizgi), style: StrokeStyle(lineWidth: 2.5 * k, lineCap: .round))
        }
        .frame(width: boyut, height: boyut)
        .accessibilityHidden(true)
    }
}

struct AnaDugme: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Renk.dugmeYazi)
            .padding(.horizontal, 20)
            .frame(height: 36)
            .background(Renk.aura.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8))
    }
}

struct IkincilDugme: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Renk.murekkep)
            .padding(.horizontal, 16)
            .frame(height: 36)
            .background(Renk.zemin.opacity(configuration.isPressed ? 0.7 : 1), in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Renk.cizgi))
    }
}

func sayi(_ n: Int) -> String {
    let f = NumberFormatter()
    f.numberStyle = .decimal
    f.locale = Locale(identifier: Dil.ingilizce ? "en_US" : "tr_TR")
    return f.string(from: NSNumber(value: n)) ?? "\(n)"
}

/// Taramadan önceki tahmin kısa bir ölçüme dayanır (disk önbelleği, Lightroom'un o anki yükü); aralık olarak gösterilir.
/// Tarama başlayınca gerçek hızla hesaplanan kalan süre gösterilir.
func sureAraligi(_ saniye: Double) -> String {
    let a = saniye * 0.75 / 60, b = saniye * 1.5 / 60
    if b < 3 { return L("birkaç dakika", "a few minutes") }
    if b < 90 { return L("~\(max(1, Int(a.rounded())))–\(Int(b.rounded())) dk", "~\(max(1, Int(a.rounded())))–\(Int(b.rounded())) min") }
    return L("~\(max(1, Int((a / 60).rounded())))–\(Int((b / 60).rounded())) sa", "~\(max(1, Int((a / 60).rounded())))–\(Int((b / 60).rounded())) h")
}

func sure(_ saniye: Double) -> String {
    let dk = Int(saniye / 60)
    if dk < 1 { return L("1 dakikadan az", "less than a minute") }
    if dk < 60 { return L("yaklaşık \(dk) dakika", "about \(dk) minutes") }
    return L("yaklaşık \(dk / 60) sa \(dk % 60) dk", "about \(dk / 60) h \(dk % 60) min")
}
