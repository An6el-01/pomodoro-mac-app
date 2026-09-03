import XCTest
@testable import PomodoroMac

final class PomodoroTimerTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)

    func testStartTransitionsIdleTimerToRunning() throws {
        var timer = PomodoroTimer(durationSeconds: 1_500)

        try timer.start(at: origin)

        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.startedAt, origin)
        XCTAssertEqual(timer.remainingSeconds(at: origin), 1_500)
    }

    func testPauseAndResumeTransitions() throws {
        var timer = PomodoroTimer(durationSeconds: 1_500)
        try timer.start(at: origin)

        try timer.pause(at: origin.addingTimeInterval(30))
        XCTAssertEqual(timer.state, .paused)
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(90)), 1_470)

        try timer.resume(at: origin.addingTimeInterval(90))
        XCTAssertEqual(timer.state, .running)
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(100)), 1_460)
    }

    func testResumeRejectsTimestampBeforeActualPause() throws {
        var timer = PomodoroTimer(durationSeconds: 60)
        try timer.start(at: origin)
        try timer.pause(at: origin.addingTimeInterval(20))

        XCTAssertThrowsError(try timer.resume(at: origin.addingTimeInterval(19))) { error in
            XCTAssertEqual(error as? PomodoroTimerError, .timeMovedBackwards)
        }
        XCTAssertEqual(timer.state, .paused)
    }

    func testElapsedTimeExcludesPausedWallClockTime() throws {
        var timer = PomodoroTimer(durationSeconds: 120)
        try timer.start(at: origin)
        try timer.pause(at: origin.addingTimeInterval(20))
        try timer.resume(at: origin.addingTimeInterval(80))

        XCTAssertEqual(timer.elapsedActiveSeconds(at: origin.addingTimeInterval(100)), 40, accuracy: 0.001)
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(100)), 80)
    }

    func testTickCompletesOnlyAfterSelectedActiveDuration() throws {
        var timer = PomodoroTimer(durationSeconds: 60)
        try timer.start(at: origin)
        try timer.pause(at: origin.addingTimeInterval(20))
        try timer.resume(at: origin.addingTimeInterval(50))

        XCTAssertFalse(timer.tick(at: origin.addingTimeInterval(89)))
        XCTAssertEqual(timer.state, .running)
        XCTAssertTrue(timer.tick(at: origin.addingTimeInterval(90)))
        XCTAssertEqual(timer.state, .completed)
        XCTAssertEqual(timer.endedAt, origin.addingTimeInterval(90))
        XCTAssertEqual(timer.remainingSeconds(at: origin.addingTimeInterval(90)), 0)
    }

    func testCompletionSignalIsEmittedExactlyOnce() throws {
        var timer = PomodoroTimer(durationSeconds: 1)
        try timer.start(at: origin)

        XCTAssertTrue(timer.tick(at: origin.addingTimeInterval(1)))
        XCTAssertFalse(timer.tick(at: origin.addingTimeInterval(2)))
    }

    func testCancelResetsAnActiveTimerWithoutCompleting() throws {
        var timer = PomodoroTimer(durationSeconds: 60)
        try timer.start(at: origin)

        timer.cancel()

        XCTAssertEqual(timer.state, .idle)
        XCTAssertNil(timer.startedAt)
        XCTAssertNil(timer.endedAt)
        XCTAssertFalse(timer.tick(at: origin.addingTimeInterval(120)))
    }

    func testInvalidTransitionsThrow() throws {
        var timer = PomodoroTimer(durationSeconds: 60)

        XCTAssertThrowsError(try timer.pause(at: origin))
        XCTAssertThrowsError(try timer.resume(at: origin))
        try timer.start(at: origin)
        XCTAssertThrowsError(try timer.start(at: origin))
    }
}
