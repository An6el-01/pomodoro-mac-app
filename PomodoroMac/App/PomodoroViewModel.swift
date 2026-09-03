import AppKit
import Combine
import Foundation
import UserNotifications

struct DurationInput {
    static func sanitized(_ text: String) -> String {
        String(text.filter { $0 >= "0" && $0 <= "9" })
    }

    static func committedMinutes(from text: String, fallback: Int) -> Int {
        guard !text.isEmpty else { return fallback }
        let significantDigits = text.drop(while: { $0 == "0" })
        guard !significantDigits.isEmpty else { return 1 }
        guard significantDigits.count <= 3, let value = Int(significantDigits) else { return 180 }
        return min(180, max(1, value))
    }
}

@MainActor
protocol CompletionAlertScheduling {
    func schedule(after delay: TimeInterval,
                  action: @escaping @MainActor () -> Void) -> Cancellable
}

@MainActor
final class TaskCompletionAlertScheduler: CompletionAlertScheduling {
    func schedule(after delay: TimeInterval,
                  action: @escaping @MainActor () -> Void) -> Cancellable {
        let task = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                guard !Task.isCancelled else { return }
                action()
            } catch {
                // Cancellation is expected when a newer alert replaces this one.
            }
        }
        return AnyCancellable { task.cancel() }
    }
}

@MainActor
final class CompletionAlertState: ObservableObject {
    @Published private(set) var message: String?

    private let scheduler: CompletionAlertScheduling
    private var dismissal: Cancellable?
    private var generation = 0

    init(scheduler: CompletionAlertScheduling? = nil) {
        self.scheduler = scheduler ?? TaskCompletionAlertScheduler()
    }

    func show(message: String) {
        generation += 1
        let generation = generation
        dismissal?.cancel()
        self.message = message
        dismissal = scheduler.schedule(after: 5) { [weak self] in
            guard self?.generation == generation else { return }
            self?.message = nil
        }
    }
}

@MainActor
final class PomodoroViewModel: ObservableObject {
    enum Mode: String, CaseIterable, Identifiable {
        case focus = "Focus"
        case breakTime = "Break"
        var id: String { rawValue }
    }

    @Published var mode: Mode = .focus
    @Published var focusMinutes = 25
    @Published var breakMinutes = 5
    @Published var activity = ""
    @Published var context = ""
    @Published var selectedDomain: FocusDomain?
    @Published private(set) var state: PomodoroTimerState = .idle
    @Published private(set) var remainingSeconds = 25 * 60
    @Published private(set) var errorMessage: String?
    @Published private(set) var durationInput = "25"

    let completionAlert: CompletionAlertState

    private let controller: PomodoroSessionController
    private let preferences: DomainPreferenceStore
    private var ticker: Timer?

    init(logger: ActivityLogging = JSONLActivityLogger(),
         preferences: DomainPreferenceStore = DomainPreferenceStore(),
         alertScheduler: CompletionAlertScheduling? = nil) {
        controller = PomodoroSessionController(logger: logger)
        self.preferences = preferences
        completionAlert = CompletionAlertState(scheduler: alertScheduler)
        selectedDomain = preferences.lastDomain
    }

    deinit { ticker?.invalidate() }

    var durationMinutes: Int { mode == .focus ? focusMinutes : breakMinutes }
    var canEdit: Bool { state == .idle || state == .completed }
    var clockText: String { String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60) }

    func selectFocusPreset(_ minutes: Int) {
        focusMinutes = minutes
        durationChanged()
    }

    func selectBreakPreset(_ minutes: Int) {
        breakMinutes = minutes
        durationChanged()
    }

    func updateDurationInput(_ text: String) {
        durationInput = DurationInput.sanitized(text)
    }

    func commitDurationInput() {
        let minutes = DurationInput.committedMinutes(from: durationInput, fallback: durationMinutes)
        if mode == .focus { focusMinutes = minutes }
        else { breakMinutes = minutes }
        durationChanged()
    }

    func start(now: Date = Date()) {
        commitDurationInput()
        do {
            errorMessage = nil
            if mode == .focus {
                try controller.startFocus(durationMinutes: focusMinutes, activity: activity,
                                          domain: selectedDomain, context: context, at: now)
                preferences.lastDomain = selectedDomain
            } else {
                try controller.startBreak(durationMinutes: breakMinutes, at: now)
            }
            state = .running
            remainingSeconds = durationMinutes * 60
            beginTicker()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func pause(now: Date = Date()) {
        do {
            if try controller.pause(at: now) {
                completeSession()
            } else {
                update(now: now)
            }
        } catch {
            if controller.timer?.state == .completed {
                completeSession(loggingError: error)
            } else {
                errorMessage = error.localizedDescription
            }
        }
    }

    func resume(now: Date = Date()) {
        do {
            try controller.resume(at: now)
            update(now: now)
        } catch { errorMessage = error.localizedDescription }
    }

    func cancel() {
        controller.cancel()
        ticker?.invalidate()
        ticker = nil
        state = .idle
        remainingSeconds = durationMinutes * 60
        errorMessage = nil
    }

    func durationChanged() {
        guard canEdit else { return }
        durationInput = String(durationMinutes)
        remainingSeconds = durationMinutes * 60
    }

    private func beginTicker() {
        ticker?.invalidate()
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.update(now: Date()) }
        }
        RunLoop.main.add(timer, forMode: .common)
        ticker = timer
    }

    private func update(now: Date) {
        guard let timer = controller.timer else { return }
        remainingSeconds = timer.remainingSeconds(at: now)
        state = timer.state
        do {
            if try controller.tick(at: now) {
                completeSession()
            } else if let updated = controller.timer {
                state = updated.state
                remainingSeconds = updated.remainingSeconds(at: now)
            }
        } catch {
            completeSession(loggingError: error)
        }
    }

    private func completeSession(loggingError: Error? = nil) {
        ticker?.invalidate()
        ticker = nil
        state = .completed
        remainingSeconds = 0
        if let loggingError {
            errorMessage = "Timer completed, but logging failed: \(loggingError.localizedDescription)"
        }
        CompletionPresenter.present(mode: mode)
        completionAlert.show(message: mode == .focus ? "Focus complete — nice work!" : "Break complete — ready to focus?")
    }
}
