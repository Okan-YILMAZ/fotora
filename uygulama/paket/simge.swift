// Fotora simgesini PNG olarak çizer: swift simge.swift <cikti.png> <boyut> [logo]
// logo: zeminsiz, koyu çizgili logo (eklentideki pencereler için); yoksa koyu zeminli uygulama simgesi.
import AppKit
let a = CommandLine.arguments, n = CGFloat(Int(a[2])!), yalnizLogo = a.count > 3
let img = NSImage(size: NSSize(width: n, height: n))
img.lockFocus()
let k = n / 1024
let murekkep = NSColor(red: 0x1A/255, green: 0x1B/255, blue: 0x1F/255, alpha: 1)
if !yalnizLogo {
    murekkep.setFill()
    NSBezierPath(roundedRect: NSRect(x: 100*k, y: 100*k, width: 824*k, height: 824*k), xRadius: 185*k, yRadius: 185*k).fill()
}
// logo 32 birim; uygulama simgesinde 560 px ortada, yalnız logoda bütün alan. y ekseni AppKit'te yukarı
let s = (yalnizLogo ? 1024 : 560)*k/32, ox = yalnizLogo ? 0 : 232*k, oy = yalnizLogo ? 0 : 232*k
func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: ox + x*s, y: oy + (32 - y)*s) }
let halka = NSBezierPath(); halka.appendArc(withCenter: p(14,14), radius: 12.5*s, startAngle: 0, endAngle: -265, clockwise: true)
halka.lineWidth = 2*s; halka.lineCapStyle = .round
NSColor(red: 0xF0/255, green: 0xA2/255, blue: 0x3A/255, alpha: 1).setStroke(); halka.stroke()
(yalnizLogo ? murekkep : NSColor.white).setStroke()
let mercek = NSBezierPath(ovalIn: NSRect(x: p(6.5,21.5).x, y: p(6.5,21.5).y, width: 15*s, height: 15*s)); mercek.lineWidth = 2.5*s; mercek.stroke()
let sap = NSBezierPath(); sap.move(to: p(19.5,19.5)); sap.line(to: p(27,27)); sap.lineWidth = 2.5*s; sap.lineCapStyle = .round; sap.stroke()
img.unlockFocus()
let r = NSBitmapImageRep(data: img.tiffRepresentation!)!
try! r.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: a[1]))
