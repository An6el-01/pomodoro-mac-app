import Foundation

enum PomodoroSessionError: LocalizedError {
    case missingActivity
    case missingDomain
    case invalidDuration

    var errorDescription: String? {
        switch self {
        case .missingActivity: return "Enter an activity before starting focus."
        case .missingDomain: return "Choose a domain before starting focus."
        case .invalidDuration: return "Duration must be at least one minute."
        }
    }
}

final class PomodoroSessionController {
    enum Kind: Equatable { case focus, breakTime }

    private let logger: ActivityLogging
    private(set) var timer: PomodoroTimer?
    private(set) var kind: Kind?
    private(set) var activity = ""
    private(set) var domain: FocusDomain?
    private(set) var context = ""
    private var completionHandled = false

    init(logger: ActivityLogging) {
        self.logger = logger
    }

    func startFocus(durationMinutes: Int, activity: String, domain: FocusDomain?, context: String, at date: Date) throws {
        let trimmedActivity = activity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedActivity.isEmpty else { throw PomodoroSessionError.missingActivity }
        guard let domain else { throw PomodoroSessionError.missingDomain }
        try start(kind: .focus, durationMinutes: durationMinutes, at: date)
        self.activity = trimmedActivity
        self.domain = domain
        self.context = context.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func startBreak(durationMinutes: Int, at date: Date) throws {
        try start(kind: .breakTime, durationMinutes: durationMinutes, at: date)
        activity = ""
        domain = nil
        context = ""
    }

    @discardableResult
    func pause(at date: Date) throws -> Bool {
        guard var timer else { throw PomodoroTimerError.invalidTransition }
        let completedNow = try timer.pause(at: date)
        self.timer = timer
        return try handleCompletion(completedNow, timer: timer, at: date, loggedAt: nil)
    }

    func resume(at date: Date) throws {
        guard var timer else { throw PomodoroTimerError.invalidTransition }
        try timer.resume(at: date)
        self.timer = timer
    }

    func cancel() {
        timer?.cancel()
        timer = nil
        kind = nil
        completionHandled = false
    }

    @discardableResult
    func tick(at date: Date, loggedAt: Date? = nil) throws -> Bool {
        guard var timer else { return false }
        let completedNow = timer.tick(at: date)
        self.timer = timer
        return try handleCompletion(completedNow, timer: timer, at: date, loggedAt: loggedAt)
    }

    private func handleCompletion(_ completedNow: Bool, timer: PomodoroTimer,
                                  at date: Date, loggedAt: Date?) throws -> Bool {
        guard completedNow, !completionHandled else { return false }
        completionHandled = true

        if kind == .focus, let start = timer.startedAt, let end = timer.endedAt, let domain {
            let durationMinutes = Int(timer.durationSeconds / 60)
            try logger.append(ActivityLogEntry(start: start, end: end, durationMinutes: durationMinutes,
                                               domain: domain, activity: activity, context: context,
                                               loggedAt: loggedAt ?? date))
        }
        return true
    }

    private func start(kind: Kind, durationMinutes: Int, at date: Date) throws {
        guard durationMinutes > 0 else { throw PomodoroSessionError.invalidDuration }
        guard timer == nil || timer?.state == .idle || timer?.state == .completed else {
            throw PomodoroTimerError.invalidTransition
        }
        var timer = PomodoroTimer(durationSeconds: TimeInterval(durationMinutes * 60))
        try timer.start(at: date)
        self.timer = timer
        self.kind = kind
        completionHandled = false
    }
}
