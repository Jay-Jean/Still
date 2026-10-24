import AppKit

// Render the same polygons used by the app at five independently chosen times.
@main struct SandProof {
    static func main() throws {
        let size = NSSize(width: 850, height: 300)
        let image = NSImage(size: size)
        image.lockFocus()
        NSColor(srgbRed: 0.10, green: 0.16, blue: 0.20, alpha: 1).setFill()
        NSRect(origin: .zero, size: size).fill()
        let accent = NSColor(srgbRed: 0.94, green: 0.77, blue: 0.53, alpha: 1)
        func label(_ text: String, x: Double, y: Double, color: NSColor = .white) {
            let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium), .foregroundColor: color]
            (text as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attributes)
        }
        for (i, fraction) in [0.0, 0.25, 0.5, 0.75, 1.0].enumerated() {
            let model = SandGeometry(progress: fraction)
            let center = 85 + Double(i) * 170
            func path(_ points: [SandPoint], lower: Bool) -> NSBezierPath {
                let result = NSBezierPath()
                for (j, point) in points.enumerated() {
                    let p = NSPoint(x: center + point.x * 120, y: 242 - (lower ? 85 : 0) - point.y * 85)
                    if j == 0 { result.move(to: p) } else { result.line(to: p) }
                }
                if !points.isEmpty { result.close() }
                return result
            }
            label("Elapsed \(Int(fraction * 100))%", x: center - 49, y: 267)
            label("Upper \(100 - Int(fraction * 100))%", x: center - 44, y: 45, color: accent)
            label("Lower \(Int(fraction * 100))%", x: center - 44, y: 24, color: accent)
            accent.setFill()
            path(model.upperSand, lower: false).fill()
            path(model.lowerSand, lower: true).fill()
            NSColor.white.withAlphaComponent(0.45).setStroke()
            for (points, lower) in [(model.upperChamber, false), (model.lowerChamber, true)] {
                let glass = path(points, lower: lower)
                glass.lineWidth = 1
                glass.stroke()
            }
        }
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
    }
}
