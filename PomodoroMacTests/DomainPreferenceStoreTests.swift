import XCTest
@testable import PomodoroMac

final class DomainPreferenceStoreTests: XCTestCase {
    func testPersistsAndRestoresLastFocusDomain() throws {
        let suiteName = "DomainPreferenceStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = DomainPreferenceStore(defaults: defaults)

        XCTAssertNil(store.lastDomain)
        store.lastDomain = .salinas
        XCTAssertEqual(DomainPreferenceStore(defaults: defaults).lastDomain, .salinas)
    }

    func testUnknownStoredValueIsIgnored() throws {
        let suiteName = "DomainPreferenceStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set("unknown", forKey: DomainPreferenceStore.key)

        XCTAssertNil(DomainPreferenceStore(defaults: defaults).lastDomain)
    }
}
