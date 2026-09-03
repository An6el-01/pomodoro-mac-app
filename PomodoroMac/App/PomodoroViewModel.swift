import AppKit
import Combine
import Foundation
import UserNotifications

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

    private let controller: PomodoroSessionController
    private let preferences: DomainPreferenceStore
    private var ticker: Timer?

    init(logger: ActivityLogging = JSONLActivityLogger(),
         preferences: DomainPreferenceStore = DomainPreferenceStore()) {
        controller = PomodoroSessionController(logger: logger)
        self.preferences = preferences
        selectedDomain = preferences.lastDomain
    }

    deinit { ticker?.invalidate() }

    var durationMinutes: Int { mode == .focus ? focusMinutes : breakMinutes }
    var canEdit: Bool { state == .idle || state == .completed }
    var clockText: String { String(format: "%02d:%02d", remainingSeconds / 60, remainingSeconds % 60) }

    func selectFocusPreset(_ minutes: Int) { focusMinutes = minutes }
    func selectBreakPreset(_ minutes: Int) { breakMinutes = minutes }

    func start(now: Date = Date()) {
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
    }
}
