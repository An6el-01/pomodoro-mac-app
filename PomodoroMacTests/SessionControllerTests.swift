import XCTest
import Combine
@testable import PomodoroMac

final class SessionControllerTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_700_000_000)

    func testFocusRequiresActivityAndDomain() throws {
        let logger = RecordingActivityLogger()
        let controller = PomodoroSessionController(logger: logger)

        XCTAssertThrowsError(try controller.startFocus(durationMinutes: 25, activity: "", domain: .career, context: "", at: origin))
        XCTAssertThrowsError(try controller.startFocus(durationMinutes: 25, activity: "Write", domain: nil, context: "", at: origin))
    }

    func testCompletedFocusLogsExactlyOnce() throws {
        let logger = RecordingActivityLogger()
        let controller = PomodoroSessionController(logger: logger)
        try controller.startFocus(durationMinutes: 1, activity: "Draft report", domain: .career, context: "Q4", at: origin)

        XCTAssertFalse(try controller.tick(at: origin.addingTimeInterval(59)))
        XCTAssertTrue(try controller.tick(at: origin.addingTimeInterval(60)))
        XCTAssertFalse(try controller.tick(at: origin.addingTimeInterval(61)))

        XCTAssertEqual(logger.entries.count, 1)
        XCTAssertEqual(logger.entries[0].durationMinutes, 1)
        XCTAssertEqual(logger.entries[0].domain, .career)
        XCTAssertEqual(logger.entries[0].activity, "Draft report")
        XCTAssertEqual(logger.entries[0].context, "Q4")
        XCTAssertEqual(logger.entries[0].start, origin)
        XCTAssertEqual(logger.entries[0].end, origin.addingTimeInterval(60))
    }

    func testPausedTimeIsExcludedFromLoggedFocusDuration() throws {
        let logger = RecordingActivityLogger()
        let controller = PomodoroSessionController(logger: logger)
        try controller.startFocus(durationMinutes: 1, activity: "Study", domain: .university, context: "", at: origin)
        try controller.pause(at: origin.addingTimeInterval(20))
        try controller.resume(at: origin.addingTimeInterval(80))

        XCTAssertTrue(try controller.tick(at: origin.addingTimeInterval(120)))
        XCTAssertEqual(logger.entries.single?.start, origin)
        XCTAssertEqual(logger.entries.single?.end, origin.addingTimeInterval(120))
        XCTAssertEqual(logger.entries.single?.durationMinutes, 1)
    }

    func testPauseAtOrAfterExpiryCompletesAndLogsInsteadOfPausing() throws {
        for offset in [60.0, 61.0] {
            let logger = RecordingActivityLogger()
            let controller = PomodoroSessionController(logger: logger)
            try controller.startFocus(durationMinutes: 1, activity: "Study", domain: .university,
                                      context: "", at: origin)

            XCTAssertTrue(try controller.pause(at: origin.addingTimeInterval(offset)))
            XCTAssertEqual(controller.timer?.state, .completed)
            XCTAssertEqual(logger.entries.count, 1)
            XCTAssertEqual(logger.entries.single?.end, origin.addingTimeInterval(offset))
        }
    }

    func testCancelledFocusDoesNotLog() throws {
        let logger = RecordingActivityLogger()
        let controller = PomodoroSessionController(logger: logger)
        try controller.startFocus(durationMinutes: 1, activity: "Study", domain: .university, context: "", at: origin)

        controller.cancel()
        XCTAssertFalse(try controller.tick(at: origin.addingTimeInterval(120)))
        XCTAssertTrue(logger.entries.isEmpty)
    }

    func testBreakNeedsNoMetadataAndNeverLogs() throws {
        let logger = RecordingActivityLogger()
        let controller = PomodoroSessionController(logger: logger)

        try controller.startBreak(durationMinutes: 1, at: origin)
        XCTAssertTrue(try controller.tick(at: origin.addingTimeInterval(60)))
        XCTAssertTrue(logger.entries.isEmpty)
    }

    func testLoggingFailureIsSurfacedAndNotRetriedByLaterTicks() throws {
        let logger = RecordingActivityLogger(error: TestError.writeFailed)
        let controller = PomodoroSessionController(logger: logger)
        try controller.startFocus(durationMinutes: 1, activity: "Study", domain: .university, context: "", at: origin)

        XCTAssertThrowsError(try controller.tick(at: origin.addingTimeInterval(60)))
        XCTAssertFalse(try controller.tick(at: origin.addingTimeInterval(61)))
        XCTAssertEqual(logger.attemptCount, 1)
    }
}

@MainActor
final class MainWindowLifecycleControllerTests: XCTestCase {
    func testCloseOrdersWindowOutWithoutDestroyingIt() {
        let window = RecordingMainWindow()
        let lifecycle = MainWindowLifecycleController(activateApplication: {})
        lifecycle.register(window: window)

        let shouldClose = lifecycle.shouldClose(window: window)

        XCTAssertFalse(shouldClose)
        XCTAssertEqual(window.orderOutCount, 1)
    }

    func testRestoreDeminiaturizesAndOrdersMainWindowFront() {
        let window = RecordingMainWindow()
        window.isMiniaturized = true
        var activationCount = 0
        let lifecycle = MainWindowLifecycleController { activationCount += 1 }
        lifecycle.register(window: window)

        lifecycle.restoreMainWindow()

        XCTAssertEqual(activationCount, 1)
        XCTAssertEqual(window.deminiaturizeCount, 1)
        XCTAssertEqual(window.makeKeyAndOrderFrontCount, 1)
    }
}

final class DurationInputTests: XCTestCase {
    func testEditingAcceptsDigitsAndAllowsTemporaryEmptyText() {
        XCTAssertEqual(DurationInput.sanitized("4a5"), "45")
        XCTAssertEqual(DurationInput.sanitized("4٢5"), "45")
        XCTAssertEqual(DurationInput.sanitized(""), "")
    }

    func testCommitClampsMinutesToSupportedRange() {
        XCTAssertEqual(DurationInput.committedMinutes(from: "0", fallback: 25), 1)
        XCTAssertEqual(DurationInput.committedMinutes(from: "181", fallback: 25), 180)
        XCTAssertEqual(DurationInput.committedMinutes(from: "", fallback: 25), 25)
        XCTAssertEqual(DurationInput.committedMinutes(from: "045", fallback: 25), 45)
        XCTAssertEqual(DurationInput.committedMinutes(from: "000001", fallback: 25), 1)
        XCTAssertEqual(DurationInput.committedMinutes(from: String(repeating: "9", count: 30), fallback: 25), 180)
    }
}

@MainActor
final class DurationEditingIntegrationTests: XCTestCase {
    func testCommittedTextUpdatesFocusAndBreakCountdownsIndependently() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        let model = PomodoroViewModel(preferences: DomainPreferenceStore(defaults: defaults))

        model.updateDurationInput("42")
        model.commitDurationInput()
        XCTAssertEqual(model.focusMinutes, 42)
        XCTAssertEqual(model.remainingSeconds, 42 * 60)

        model.mode = .breakTime
        model.durationChanged()
        XCTAssertEqual(model.durationInput, "5")
        model.updateDurationInput("9")
        model.commitDurationInput()
        XCTAssertEqual(model.breakMinutes, 9)
        XCTAssertEqual(model.remainingSeconds, 9 * 60)
        XCTAssertEqual(model.focusMinutes, 42)
    }
}

@MainActor
final class CompletionAlertStateTests: XCTestCase {
    func testAlertDismissesAfterExactlyFiveSeconds() {
        let scheduler = ManualCompletionAlertScheduler()
        let alert = CompletionAlertState(scheduler: scheduler)

        alert.show(message: "Focus complete")

        XCTAssertEqual(alert.message, "Focus complete")
        XCTAssertEqual(scheduler.delays, [5])
        scheduler.fire(at: 0)
        XCTAssertNil(alert.message)
    }

    func testOldDismissalCannotHideNewerAlert() {
        let scheduler = ManualCompletionAlertScheduler()
        let alert = CompletionAlertState(scheduler: scheduler)
        alert.show(message: "Focus complete")
        alert.show(message: "Break complete")

        scheduler.fire(at: 0, evenIfCancelled: true)
        XCTAssertEqual(alert.message, "Break complete")

        scheduler.fire(at: 1)
        XCTAssertNil(alert.message)
    }
}

private enum TestError: Error { case writeFailed }

private final class RecordingActivityLogger: ActivityLogging {
    var entries: [ActivityLogEntry] = []
    var attemptCount = 0
    let error: Error?

    init(error: Error? = nil) { self.error = error }

    func append(_ entry: ActivityLogEntry) throws {
        attemptCount += 1
        if let error { throw error }
        entries.append(entry)
    }
}

@MainActor
private final class ManualCompletionAlertScheduler: CompletionAlertScheduling {
    private final class Token: Cancellable {
        var isCancelled = false
        func cancel() { isCancelled = true }
    }

    private var jobs: [(token: Token, action: @MainActor () -> Void)] = []
    private(set) var delays: [TimeInterval] = []

    func schedule(after delay: TimeInterval, action: @escaping @MainActor () -> Void) -> Cancellable {
        let token = Token()
        delays.append(delay)
        jobs.append((token, action))
        return token
    }

    func fire(at index: Int, evenIfCancelled: Bool = false) {
        let job = jobs[index]
        if evenIfCancelled || !job.token.isCancelled { job.action() }
    }
}

@MainActor
private final class RecordingMainWindow: MainWindowLifecycleWindow {
    var isMiniaturized = false
    var orderOutCount = 0
    var deminiaturizeCount = 0
    var makeKeyAndOrderFrontCount = 0

    func orderOut() { orderOutCount += 1 }
    func deminiaturize() {
        deminiaturizeCount += 1
        isMiniaturized = false
    }
    func makeKeyAndOrderFront() { makeKeyAndOrderFrontCount += 1 }
}

private extension Array {
    var single: Element? { count == 1 ? self[0] : nil }
}
