import Foundation

public struct SandPoint: Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// The renderer uses these exact polygons, so visible sand area is conserved.
/// Each chamber has local coordinates: x across the full glass width, y from 0 to 1.
public struct SandGeometry: Sendable {
    public let upperChamber: [SandPoint]
    public let lowerChamber: [SandPoint]
    public let upperSand: [SandPoint]
    public let lowerSand: [SandPoint]
    public let upperSurface: Double
    public let lowerPeak: Double
    public let progress: Double
    public static let reposeSlope = 1.0

    public init(progress: Double) {
        let fraction = progress.isFinite ? min(1, max(0, progress)) : 0
        self.progress = fraction
        let upper = Self.chamber(lower: false)
        let lower = Self.chamber(lower: true)
        upperChamber = upper
        lowerChamber = lower
        let capacity = Self.area(of: upper)
        func upperFill(_ level: Double) -> [SandPoint] {
            Self.clip(upper) { $0.y - level }
        }
        func lowerFill(_ level: Double) -> [SandPoint] {
            let left = Self.clip(lower) { $0.y - Self.reposeSlope * $0.x - level }
            return Self.clip(left) { $0.y + Self.reposeSlope * $0.x - level }
        }
        func level(for target: Double, min low: Double, max high: Double, fill: (Double) -> [SandPoint]) -> Double {
            var low = low
            var high = high
            for _ in 0..<32 {
                let mid = (low + high) / 2
                if Self.area(of: fill(mid)) > target { low = mid } else { high = mid }
            }
            return (low + high) / 2
        }
        upperSurface = level(for: capacity * (1 - fraction), min: 0, max: 1, fill: upperFill)
        lowerPeak = level(for: capacity * fraction, min: -0.44 * Self.reposeSlope, max: 1, fill: lowerFill)
        upperSand = fraction == 1 ? [] : (fraction == 0 ? upper : upperFill(upperSurface))
        lowerSand = fraction == 0 ? [] : (fraction == 1 ? lower : lowerFill(lowerPeak))
    }

    private static func chamber(lower: Bool) -> [SandPoint] {
        let side = (0...32).map { i -> SandPoint in
            let y = Double(i) / 32
            let taper = lower ? y : 1 - y
            let width = 0.035 + 0.405 * pow(taper, 1.4)
            return SandPoint(x: -width, y: y)
        }
        return side + side.reversed().map { SandPoint(x: -$0.x, y: $0.y) }
    }

    public static func area(of points: [SandPoint]) -> Double {
        guard points.count > 2 else { return 0 }
        return abs(points.indices.reduce(0.0) { total, i in
            let next = points[(i + 1) % points.count]
            return total + points[i].x * next.y - next.x * points[i].y
        }) / 2
    }

    private static func clip(_ points: [SandPoint], distance: (SandPoint) -> Double) -> [SandPoint] {
        guard var previous = points.last else { return [] }
        var result: [SandPoint] = []
        var previousDistance = distance(previous)
        for point in points {
            let nextDistance = distance(point)
            if (previousDistance >= 0) != (nextDistance >= 0) {
                let t = previousDistance / (previousDistance - nextDistance)
                result.append(SandPoint(x: previous.x + t * (point.x - previous.x),
                                        y: previous.y + t * (point.y - previous.y)))
            }
            if nextDistance >= 0 { result.append(point) }
            previous = point
            previousDistance = nextDistance
        }
        return result
    }
}
