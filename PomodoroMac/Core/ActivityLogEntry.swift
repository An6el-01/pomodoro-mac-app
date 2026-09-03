import Foundation

enum FocusDomain: String, CaseIterable, Codable, Identifiable {
    case university
    case career
    case salinas
    case hermes
    case admin
    case personal

    var id: String { rawValue }
}

struct ActivityLogEntry: Codable, Equatable {
    let start: Date
    let end: Date
    let durationMinutes: Int
    let domain: FocusDomain
    let activity: String
    let context: String
    let loggedAt: Date

    enum CodingKeys: String, CodingKey {
        case start
        case end
        case durationMinutes = "duration_minutes"
        case domain
        case activity
        case context
        case loggedAt = "logged_at"
    }
}

protocol ActivityLogging: AnyObject {
    func append(_ entry: ActivityLogEntry) throws
}
