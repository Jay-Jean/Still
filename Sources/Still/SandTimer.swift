import SwiftUI
import StillCore

/// Motion follows elapsed session time, so pausing freezes every moving element.
private func elapsed(_ session: Session, at date: Date) -> Double {
    let remaining = session.deadline.map { $0.timeIntervalSince(date) } ?? session.remaining
    return min(session.duration, max(0, session.duration - remaining))
}

struct SandDrift: View {
    let session: Session
    let accent: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !session.running)) { timeline in
            let time = elapsed(session, at: timeline.date)
            Canvas { context, size in
                for index in 0..<96 {
                    let seed = Double(index)
                    let x = (seed * 67.7 + time * 14).truncatingRemainder(dividingBy: size.width + 20) - 10
                    let y = (seed * 47.3 + time * (90 + seed.truncatingRemainder(dividingBy: 5) * 22)).truncatingRemainder(dividingBy: size.height + 30) - 15
                    // Keep the center legible; most motion lives around the edges.
                    let edge = abs(x - size.width / 2) / (size.width / 2)
                    let opacity = 0.08 + 0.30 * edge
                    var trail = Path()
                    trail.move(to: CGPoint(x: x, y: y))
                    trail.addLine(to: CGPoint(x: x + 1.6, y: y + 6 + seed.truncatingRemainder(dividingBy: 8)))
                    context.stroke(trail, with: .color(accent.opacity(opacity)), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                }
            }
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct SandTimerFace: View {
    let session: Session
    let time: String
    let accent: Color
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !session.running)) { timeline in
            let passed = elapsed(session, at: timeline.date)
            let minuteSeconds = passed.truncatingRemainder(dividingBy: 60)
            VStack(spacing: 3) {
                Text(session.phase == .rest ? "舒 展 · 呼 吸" : "每 一 秒 · 都 看 得 见")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(accent)
                Text(time).font(.system(size: 56, weight: .ultraLight, design: .rounded))
                    .monospacedDigit().foregroundStyle(.white).accessibilityLabel("剩余 \(time)")
                HStack(spacing: 22) {
                    Hourglass(passed: passed, duration: session.duration, accent: accent)
                        .frame(width: 94, height: 112)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("已经流逝").font(.system(size: 10)).foregroundStyle(.white.opacity(0.6))
                        Text(String(format: "%02d:%02d", Int(passed) / 60, Int(passed) % 60))
                            .font(.system(size: 22, weight: .light, design: .rounded)).monospacedDigit()
                            .foregroundStyle(accent)
                        Text("已落下 \(Int(passed / session.duration * 100))%")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
                        Text("剩余沙量 \(100 - Int(passed / session.duration * 100))%")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.55))
                    }
                }
                Canvas { context, size in
                    let step = size.width / 60
                    for i in 0..<60 {
                        let lit = Double(i) <= minuteSeconds
                        let rect = CGRect(x: Double(i) * step, y: i % 5 == 0 ? 0 : 3, width: 2, height: i % 5 == 0 ? 9 : 6)
                        context.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(lit ? accent.opacity(0.85) : .white.opacity(0.15)))
                    }
                    let x = minuteSeconds / 60 * (size.width - 4)
                    context.fill(Path(ellipseIn: CGRect(x: x, y: 11, width: 4, height: 4)), with: .color(accent))
                }.frame(height: 15).padding(.top, 3).accessibilityHidden(true)
            }
        }
    }
}

private struct Hourglass: View {
    let passed: Double
    let duration: Double
    let accent: Color
    var body: some View {
        let geometry = SandGeometry(progress: duration > 0 ? passed / duration : 0)
        Canvas { context, size in
            let w = size.width
            let h = size.height
            let top = 7.0
            let chamberHeight = (h - 14) / 2
            func path(_ points: [SandPoint], lower: Bool) -> Path {
                Path { result in
                    for (index, point) in points.enumerated() {
                        let p = CGPoint(x: w / 2 + point.x * w,
                                        y: top + (lower ? chamberHeight : 0) + point.y * chamberHeight)
                        if index == 0 { result.move(to: p) } else { result.addLine(to: p) }
                    }
                    if !points.isEmpty { result.closeSubpath() }
                }
            }
            let upperGlass = path(geometry.upperChamber, lower: false)
            let lowerGlass = path(geometry.lowerChamber, lower: true)
            let upperSand = path(geometry.upperSand, lower: false)
            let lowerSand = path(geometry.lowerSand, lower: true)
            for glass in [upperGlass, lowerGlass] {
                context.fill(glass, with: .color(.white.opacity(0.035)))
            }
            for sand in [upperSand, lowerSand] {
                context.fill(sand, with: .linearGradient(Gradient(colors: [accent.opacity(0.95), accent.opacity(0.65)]),
                    startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
                // Texture belongs to the actual sand polygons, rather than the vessel.
                var textured = context
                textured.clip(to: sand)
                for i in 0..<280 {
                    let seed = Double(i)
                    let x = (seed * 17.731).truncatingRemainder(dividingBy: w)
                    let y = (seed * 31.37).truncatingRemainder(dividingBy: h)
                    textured.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.9, height: 0.9)),
                                  with: .color(.white.opacity(i % 3 == 0 ? 0.5 : 0.18)))
                }
            }
            if passed > 0 && geometry.progress < 1 {
                // Stream ends on the growing mound, not at an unrelated fixed height.
                let neck = top + chamberHeight
                let peak = neck + max(0, geometry.lowerPeak) * chamberHeight
                var streamContext = context
                var vessel = upperGlass
                vessel.addPath(lowerGlass)
                streamContext.clip(to: vessel)
                for index in 0..<36 {
                    let seed = Double(index)
                    let travel = (passed * 1.9 + seed / 36).truncatingRemainder(dividingBy: 1)
                    let x = w / 2 + sin(seed * 13.7) * (0.7 + travel * 2)
                    let y = neck - 2 + travel * max(2, peak - neck + 2)
                    streamContext.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 1.1, height: 1.8)), with: .color(accent))
                }
            }
            // Leave the neck open; do not draw a horizontal seam through the flow.
            for (points, lower) in [(geometry.upperChamber, false), (geometry.lowerChamber, true)] {
                var outline = Path()
                for side in [Array(points.prefix(33)), Array(points.suffix(33))] {
                    for (i, point) in side.enumerated() {
                        let p = CGPoint(x: w / 2 + point.x * w,
                                        y: top + (lower ? chamberHeight : 0) + point.y * chamberHeight)
                        if i == 0 { outline.move(to: p) } else { outline.addLine(to: p) }
                    }
                }
                context.stroke(outline, with: .color(.white.opacity(0.45)), lineWidth: 1.2)
            }
            for y in [4.0, h - 4] {
                context.fill(Path(roundedRect: CGRect(x: 3, y: y - 1.5, width: w - 6, height: 3), cornerRadius: 1.5), with: .color(accent.opacity(0.85)))
            }
        }.accessibilityHidden(true)
    }
}
