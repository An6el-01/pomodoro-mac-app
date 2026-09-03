import XCTest
@testable import PomodoroMac

final class JSONLActivityLoggerTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: temporaryDirectory)
    }

    func testAppendCreatesDatedFileWithRequiredSchemaAndLocalOffsets() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 5_400))
        let logger = JSONLActivityLogger(baseDirectory: temporaryDirectory, calendar: calendar)
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let end = start.addingTimeInterval(1_500)
        let loggedAt = end.addingTimeInterval(2)

        try logger.append(ActivityLogEntry(
            start: start, end: end, durationMinutes: 25, domain: .hermes,
            activity: "Review agent", context: "MVP", loggedAt: loggedAt
        ))

        let files = try FileManager.default.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(files.count, 1)
        let line = try XCTUnwrap(String(contentsOf: files[0], encoding: .utf8).split(separator: "\n").single)
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(line.utf8)) as? [String: Any])
        XCTAssertEqual(Set(object.keys), Set(["start", "end", "duration_minutes", "domain", "activity", "context", "logged_at"]))
        XCTAssertEqual(object["duration_minutes"] as? Int, 25)
        XCTAssertEqual(object["domain"] as? String, "hermes")
        XCTAssertEqual(object["activity"] as? String, "Review agent")
        XCTAssertEqual(object["context"] as? String, "MVP")
        XCTAssertTrue(try XCTUnwrap(object["start"] as? String).hasSuffix("+01:30"))
        XCTAssertTrue(try XCTUnwrap(object["end"] as? String).hasSuffix("+01:30"))
        XCTAssertTrue(try XCTUnwrap(object["logged_at"] as? String).hasSuffix("+01:30"))
    }

    func testAppendPreservesExistingLines() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let logger = JSONLActivityLogger(baseDirectory: temporaryDirectory, calendar: calendar)
        let start = Date(timeIntervalSince1970: 1_700_000_000)

        try logger.append(makeEntry(activity: "First", start: start))
        try logger.append(makeEntry(activity: "Second", start: start.addingTimeInterval(60)))

        let files = try FileManager.default.contentsOfDirectory(at: temporaryDirectory, includingPropertiesForKeys: nil)
        let lines = try String(contentsOf: try XCTUnwrap(files.single), encoding: .utf8).split(separator: "\n")
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines[0].contains("First"))
        XCTAssertTrue(lines[1].contains("Second"))
    }

    func testAllSupportedDomainsMatchApprovedValuesExactly() {
        XCTAssertEqual(FocusDomain.allCases.map(\.rawValue), [
            "university", "career", "salinas", "hermes", "admin", "personal"
        ])
    }

    private func makeEntry(activity: String, start: Date) -> ActivityLogEntry {
        ActivityLogEntry(start: start, end: start.addingTimeInterval(60), durationMinutes: 1,
                         domain: .personal, activity: activity, context: "", loggedAt: start.addingTimeInterval(60))
    }
}

private extension Array {
    var single: Element? { count == 1 ? self[0] : nil }
}
