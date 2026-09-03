import Foundation

final class DomainPreferenceStore {
    static let key = "lastFocusDomain"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var lastDomain: FocusDomain? {
        get {
            guard let value = defaults.string(forKey: Self.key) else { return nil }
            return FocusDomain(rawValue: value)
        }
        set {
            if let newValue {
                defaults.set(newValue.rawValue, forKey: Self.key)
            } else {
                defaults.removeObject(forKey: Self.key)
            }
        }
    }
}
