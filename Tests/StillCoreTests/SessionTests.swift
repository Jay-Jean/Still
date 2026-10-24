import Foundation
import StillCore

func XCTAssertEqual<T: Equatable>(_ left: T, _ right: T) { precondition(left == right, "Expected \(right), got \(left)") }
func XCTAssertTrue(_ value: Bool) { precondition(value) }
func XCTAssertFalse(_ value: Bool) { precondition(!value) }

@main struct SessionTests {
    static func main() throws {
        let suite = SessionTests()
        suite.testPauseResumeUsesElapsedWallTime()
        suite.testFocusFlowsIntoBreakWithoutDrift()
        suite.testSleepDoesNotCountImaginaryWorkSessions()
        try suite.testPersistRunningSessionAndSkip()
        suite.testSandConservationAndMonotonicTransfer()
        suite.testSandEndpointsAndMound()
        print("Passed 6 checks: 4 timer checks + sand conservation/monotonic transfer + empty/full/mound geometry")
    }
    let now = Date(timeIntervalSince1970: 100_000)
    func testPauseResumeUsesElapsedWallTime() {
        var session = Session()
        session.start(at: now)
        session.pause(at: now.addingTimeInterval(123))
        XCTAssertEqual(session.remaining, 1377)
        session.start(at: now.addingTimeInterval(500))
        session.tick(at: now.addingTimeInterval(510))
        XCTAssertEqual(session.remaining, 1367)
    }
    func testFocusFlowsIntoBreakWithoutDrift() {
        var session = Session()
        session.start(at: now)
        XCTAssertTrue(session.tick(at: now.addingTimeInterval(1510)))
        XCTAssertEqual(session.phase, .rest)
        XCTAssertEqual(session.remaining, 290)
        XCTAssertEqual(session.completed, 1)
        XCTAssertTrue(session.running)
        session.tick(at: now.addingTimeInterval(1800))
        XCTAssertEqual(session.phase, .focus)
        XCTAssertFalse(session.running)
        XCTAssertEqual(session.remaining, 1500)
    }
    func testSleepDoesNotCountImaginaryWorkSessions() {
        var session = Session()
        session.start(at: now)
        session.tick(at: now.addingTimeInterval(24 * 3600))
        XCTAssertEqual(session.completed, 1)
        XCTAssertEqual(session.phase, .focus)
        XCTAssertFalse(session.running)
    }
    func testPersistRunningSessionAndSkip() throws {
        var session = Session()
        session.start(at: now)
        let restored = try JSONDecoder().decode(Session.self, from: JSONEncoder().encode(session))
        XCTAssertEqual(restored.deadline, session.deadline)
        session.skip()
        XCTAssertEqual(session.phase, .rest)
        XCTAssertEqual(session.remaining, 300)
        XCTAssertEqual(session.completed, 0)
    }
    func testSandConservationAndMonotonicTransfer() {
        var lastSurface = -Double.infinity
        var lastPeak = Double.infinity
        for i in 0...100 {
            let progress = Double(i) / 100
            let sand = SandGeometry(progress: progress)
            let capacity = SandGeometry.area(of: sand.upperChamber)
            let upper = SandGeometry.area(of: sand.upperSand) / capacity
            let lower = SandGeometry.area(of: sand.lowerSand) / capacity
            precondition(abs(upper - (1 - progress)) < 0.000001, "Upper sand must equal remaining time")
            precondition(abs(lower - progress) < 0.000001, "Lower sand must equal elapsed time")
            precondition(abs(upper + lower - 1) < 0.000001, "Visible sand must be conserved")
            precondition(sand.upperSurface > lastSurface, "Upper level must fall continuously")
            precondition(sand.lowerPeak < lastPeak, "Lower mound must grow continuously")
            lastSurface = sand.upperSurface
            lastPeak = sand.lowerPeak
        }
        let before = SandGeometry(progress: 0.25)
        let after = SandGeometry(progress: 0.25 + 1.0 / 1500)
        let expectedGrainArea = SandGeometry.area(of: before.upperChamber) / 1500
        let transferred = SandGeometry.area(of: after.lowerSand) - SandGeometry.area(of: before.lowerSand)
        let lost = SandGeometry.area(of: before.upperSand) - SandGeometry.area(of: after.upperSand)
        precondition(abs(transferred - expectedGrainArea) < 0.000001, "A second of work must add a second of sand below")
        precondition(abs(lost - transferred) < 0.000001, "Every added grain must come from the upper chamber")
    }
    func testSandEndpointsAndMound() {
        let start = SandGeometry(progress: 0)
        let end = SandGeometry(progress: 1)
        precondition(start.lowerSand.isEmpty && !start.upperSand.isEmpty)
        precondition(end.upperSand.isEmpty && !end.lowerSand.isEmpty)
        let midway = SandGeometry(progress: 0.5)
        let top = midway.lowerSand.min { $0.y < $1.y }!
        precondition(abs(top.x) < 0.00001, "Sand must pile up under the central stream")
        precondition(midway.lowerSand.contains { abs($0.x) > 0.1 && $0.y > top.y + 0.1 }, "Mound must slope down towards the sides")
    }
}
