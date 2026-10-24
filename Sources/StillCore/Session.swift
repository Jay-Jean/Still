import Foundation

public struct Session: Codable, Sendable {
    public enum Phase: String, Codable, Sendable { case focus, rest }
    public var phase: Phase = .focus
    public var focusMinutes: Int = 25
    public var restMinutes: Int = 5
    public private(set) var remaining: TimeInterval = 25 * 60
    public private(set) var deadline: Date?
    public private(set) var completed: Int = 0
    public var sound: Bool = true
    public var theme: Int = 0
    public var intention: String = ""
    public var duration: TimeInterval { TimeInterval((phase == .focus ? focusMinutes : restMinutes) * 60) }
    public var running: Bool { deadline != nil }
    public var fraction: Double { min(1, max(0, remaining / duration)) }
    public init() {}

    public mutating func start(at now: Date) { deadline = now.addingTimeInterval(remaining) }
    public mutating func pause(at now: Date) {
        _ = tick(at: now)
        deadline = nil
    }
    public mutating func reset() { deadline = nil; remaining = duration }
    public mutating func skip() {
        phase = phase == .focus ? .rest : .focus
        reset()
    }
    public mutating func configure(focus: Int, rest: Int) {
        focusMinutes = min(90, max(1, focus))
        restMinutes = min(30, max(1, rest))
        reset()
    }
    /// Work flows into a break. A new work session always waits for the user.
    @discardableResult public mutating func tick(at now: Date) -> Bool {
        guard let end = deadline else { return false }
        remaining = max(0, end.timeIntervalSince(now))
        guard remaining <= 0 else { return false }
        if phase == .focus {
            completed += 1
            phase = .rest
            let breakEnd = end.addingTimeInterval(duration)
            if breakEnd > now {
                deadline = breakEnd
                remaining = breakEnd.timeIntervalSince(now)
            } else {
                phase = .focus
                reset()
            }
        } else {
            phase = .focus
            reset()
        }
        return true
    }
}
