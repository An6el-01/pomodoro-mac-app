import Foundation

enum ActivityLogError: LocalizedError {
    case cannotEncode
    case cannotOpenFile

    var errorDescription: String? {
        switch self {
        case .cannotEncode: return "The completed focus session could not be encoded."
        case .cannotOpenFile: return "The activity log file could not be opened for appending."
        }
    }
}

final class JSONLActivityLogger: ActivityLogging {
    static var defaultBaseDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("hermes-vault/00-Life/Activity", isDirectory: true)
    }

    private let baseDirectory: URL
    private let calendar: Calendar
    private let fileManager: FileManager

    init(baseDirectory: URL = JSONLActivityLogger.defaultBaseDirectory,
         calendar: Calendar = .current,
         fileManager: FileManager = .default) {
        self.baseDirectory = baseDirectory
        self.calendar = calendar
        self.fileManager = fileManager
    }

    func append(_ entry: ActivityLogEntry) throws {
        try fileManager.createDirectory(at: baseDirectory, withIntermediateDirectories: true)
        let destination = baseDirectory.appendingPathComponent(fileName(for: entry.end))
        var payload = try encoded(entry)
        payload.append(0x0A)

        if !fileManager.fileExists(atPath: destination.path) {
            guard fileManager.createFile(atPath: destination.path, contents: nil) else {
                throw ActivityLogError.cannotOpenFile
            }
        }

        let handle = try FileHandle(forWritingTo: destination)
        defer { try? handle.close() }
        try handle.seekToEnd()
        try handle.write(contentsOf: payload)
    }

    private func fileName(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date) + ".jsonl"
    }

    private func encoded(_ entry: ActivityLogEntry) throws -> Data {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withInternetDateTime, .withColonSeparatorInTimeZone]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        do {
            return try encoder.encode(entry)
        } catch {
            throw ActivityLogError.cannotEncode
        }
    }
}
