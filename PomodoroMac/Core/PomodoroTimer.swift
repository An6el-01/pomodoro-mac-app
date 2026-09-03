import Foundation

enum PomodoroTimerState: Equatable {
    case idle
    case running
    case paused
    case completed
}

enum PomodoroTimerError: Error, Equatable {
    case invalidDuration
    case invalidTransition
    case timeMovedBackwards
}

struct PomodoroTimer {
    let durationSeconds: TimeInterval
    private(set) var state: PomodoroTimerState = .idle
    private(set) var startedAt: Date?
    private(set) var endedAt: Date?

    private var runningSince: Date?
    private var pausedAt: Date?
    private var accumulatedActiveSeconds: TimeInterval = 0

    init(durationSeconds: TimeInterval) {
        self.durationSeconds = durationSeconds
    }

    mutating func start(at date: Date) throws {
        guard durationSeconds > 0 else { throw PomodoroTimerError.invalidDuration }
        guard state == .idle else { throw PomodoroTimerError.invalidTransition }
        state = .running
        startedAt = date
        runningSince = date
    }

    @discardableResult
    mutating func pause(at date: Date) throws -> Bool {
        guard state == .running, let runningSince else { throw PomodoroTimerError.invalidTransition }
        guard date >= runningSince else { throw PomodoroTimerError.timeMovedBackwards }
        if elapsedActiveSeconds(at: date) >= durationSeconds {
            return tick(at: date)
        }
        accumulatedActiveSeconds += date.timeIntervalSince(runningSince)
        self.runningSince = nil
        pausedAt = date
        state = .paused
        return false
    }

    mutating func resume(at date: Date) throws {
        guard state == .paused else { throw PomodoroTimerError.invalidTransition }
        guard let pausedAt, date >= pausedAt else { throw PomodoroTimerError.timeMovedBackwards }
        runningSince = date
        self.pausedAt = nil
        state = .running
    }

    mutating func cancel() {
        state = .idle
        startedAt = nil
        endedAt = nil
        runningSince = nil
        pausedAt = nil
        accumulatedActiveSeconds = 0
    }

    func elapsedActiveSeconds(at date: Date) -> TimeInterval {
        guard state != .idle else { return 0 }
        let currentSegment: TimeInterval
        if state == .running, let runningSince {
            currentSegment = max(0, date.timeIntervalSince(runningSince))
        } else {
            currentSegment = 0
        }
        return min(durationSeconds, accumulatedActiveSeconds + currentSegment)
    }

    func remainingSeconds(at date: Date) -> Int {
        max(0, Int(ceil(durationSeconds - elapsedActiveSeconds(at: date))))
    }

    @discardableResult
    mutating func tick(at date: Date) -> Bool {
        guard state == .running, elapsedActiveSeconds(at: date) >= durationSeconds else { return false }
        accumulatedActiveSeconds = durationSeconds
        runningSince = nil
        pausedAt = nil
        endedAt = date
        state = .completed
        return true
    }
}
