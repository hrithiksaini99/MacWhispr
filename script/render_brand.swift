import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let assets = root.appendingPathComponent("Assets")
let brand = root.appendingPathComponent("site/assets/brand")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: brand, withIntermediateDirectories: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
}
let mint = color(0.48, 0.96, 0.78)
func mark(in r: NSRect) -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x: r.minX + r.width * 0.05, y: r.minY + r.height * 0.73))
    p.line(to: NSPoint(x: r.minX + r.width * 0.27, y: r.minY + r.height * 0.2))
    p.line(to: NSPoint(x: r.minX + r.width * 0.5, y: r.minY + r.height * 0.8))
    p.line(to: NSPoint(x: r.minX + r.width * 0.73, y: r.minY + r.height * 0.2))
    p.line(to: NSPoint(x: r.minX + r.width * 0.95, y: r.minY + r.height * 0.73))
    p.lineCapStyle = .round
    p.lineJoinStyle = .round
    return p
}
func drawIcon(in r: NSRect) {
    let tile = r.insetBy(dx: r.width * 0.1, dy: r.height * 0.1)
    let shape = NSBezierPath(roundedRect: tile, xRadius: r.width * 0.18, yRadius: r.height * 0.18)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = r.width * 0.04
    shadow.shadowOffset = NSSize(width: 0, height: -r.width * 0.025)
    shadow.set()
    color(0.045, 0.075, 0.085).setFill()
    shape.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(starting: color(0.15, 0.22, 0.24), ending: color(0.025, 0.045, 0.055))!.draw(in: shape, angle: -70)
    color(0.75, 0.9, 0.88, 0.2).setStroke()
    shape.lineWidth = r.width * 0.002
    shape.stroke()
    let line = mark(in: NSRect(x: r.minX + r.width * 0.245, y: r.minY + r.height * 0.32, width: r.width * 0.51, height: r.height * 0.39))
    NSGraphicsContext.saveGraphicsState()
    let glyphShadow = NSShadow()
    glyphShadow.shadowColor = mint.withAlphaComponent(0.17)
    glyphShadow.shadowBlurRadius = r.width * 0.035
    glyphShadow.shadowOffset = .zero
    glyphShadow.set()
    mint.setStroke()
    line.lineWidth = r.width * 0.066
    line.stroke()
    NSGraphicsContext.restoreGraphicsState()
    color(0.85, 1, 0.94, 0.55).setStroke()
    line.lineWidth = r.width * 0.009
    line.stroke()
}
func writePNG(width: Int, height: Int, to url: URL, draw: () -> Void) throws {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    draw()
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using: .png, properties: [:])!.write(to: url)
}
try writePNG(width: 1024, height: 1024, to: assets.appendingPathComponent("AppIcon.png")) { drawIcon(in: NSRect(x: 0, y: 0, width: 1024, height: 1024)) }
try Data(contentsOf: assets.appendingPathComponent("AppIcon.png")).write(to: brand.appendingPathComponent("app-icon.png"))
try writePNG(width: 1200, height: 630, to: brand.appendingPathComponent("social-card.png")) {
    color(0.96, 0.96, 0.925).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: 1200, height: 630)).fill()
    drawIcon(in: NSRect(x: 790, y: 110, width: 400, height: 400))
    let ink = color(0.08, 0.11, 0.105)
    func text(_ value: String, _ rect: NSRect, _ size: CGFloat, _ weight: NSFont.Weight, _ tint: NSColor) {
        (value as NSString).draw(in: rect, withAttributes: [.font: NSFont.systemFont(ofSize: size, weight: weight), .foregroundColor: tint])
    }
    text("MacWhispr", NSRect(x: 80, y: 470, width: 600, height: 55), 28, .medium, ink)
    text("Your thoughts.", NSRect(x: 80, y: 318, width: 800, height: 100), 70, .semibold, ink)
    text("Already in words.", NSRect(x: 80, y: 233, width: 800, height: 100), 70, .semibold, ink)
    text("Local voice dictation for your Mac.", NSRect(x: 80, y: 126, width: 650, height: 55), 28, .regular, ink.withAlphaComponent(0.65))
}
print("Rendered MacWhispr icon and sharing card")
