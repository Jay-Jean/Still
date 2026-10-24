import AppKit

let destination = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
let bounds = NSRect(x: 64, y: 64, width: 896, height: 896)
let shape = NSBezierPath(roundedRect: bounds, xRadius: 208, yRadius: 208)
NSGraphicsContext.saveGraphicsState()
shape.addClip()
NSGradient(starting: NSColor(srgbRed: 0.12, green: 0.21, blue: 0.26, alpha: 1), ending: NSColor(srgbRed: 0.68, green: 0.45, blue: 0.35, alpha: 1))!.draw(in: bounds, angle: -90)
let back = NSBezierPath()
back.move(to: NSPoint(x: 30, y: 100)); back.line(to: NSPoint(x: 30, y: 310))
back.curve(to: NSPoint(x: 530, y: 320), controlPoint1: NSPoint(x: 240, y: 520), controlPoint2: NSPoint(x: 340, y: 210))
back.curve(to: NSPoint(x: 990, y: 400), controlPoint1: NSPoint(x: 730, y: 580), controlPoint2: NSPoint(x: 830, y: 400))
back.line(to: NSPoint(x: 990, y: 30)); back.close()
NSColor(srgbRed: 0.18, green: 0.27, blue: 0.28, alpha: 1).setFill(); back.fill()
let front = NSBezierPath()
front.move(to: NSPoint(x: 30, y: 30)); front.line(to: NSPoint(x: 30, y: 220))
front.curve(to: NSPoint(x: 990, y: 200), controlPoint1: NSPoint(x: 460, y: 480), controlPoint2: NSPoint(x: 560, y: 40))
front.line(to: NSPoint(x: 990, y: 30)); front.close()
NSColor(srgbRed: 0.09, green: 0.18, blue: 0.21, alpha: 1).setFill(); front.fill()
let ring = NSBezierPath()
ring.appendArc(withCenter: NSPoint(x: 512, y: 540), radius: 285, startAngle: 90, endAngle: -190, clockwise: true)
ring.lineWidth = 17; ring.lineCapStyle = .round
NSColor(srgbRed: 1, green: 0.81, blue: 0.58, alpha: 1).setStroke(); ring.stroke()
NSColor(srgbRed: 1, green: 0.81, blue: 0.58, alpha: 1).setFill()
NSBezierPath(ovalIn: NSRect(x: 617, y: 500, width: 102, height: 102)).fill()
let mark = NSBezierPath(); mark.move(to: NSPoint(x: 512, y: 700)); mark.line(to: NSPoint(x: 512, y: 540)); mark.line(to: NSPoint(x: 438, y: 466))
mark.lineWidth = 18; mark.lineCapStyle = .round; mark.lineJoinStyle = .round
NSColor.white.withAlphaComponent(0.9).setStroke(); mark.stroke()
NSGraphicsContext.restoreGraphicsState()
image.unlockFocus()
let rep = NSBitmapImageRep(data: image.tiffRepresentation!)!
try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
