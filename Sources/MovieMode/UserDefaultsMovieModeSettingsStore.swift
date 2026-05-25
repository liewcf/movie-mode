import FocusMonitorCore
import Foundation

final class UserDefaultsMovieModeSettingsStore: MovieModeSettingsStore {
    private enum Keys {
        static let autoMovieModeEnabled = "autoMovieModeEnabled"
        static let displayRule = "displayRule"
        static let pinMainDisplay = "pinMainDisplay"
        static let watchDisplayID = "watchDisplayID"
        static let useAccessibilityDetection = "useAccessibilityDetection"
        static let enabledBundleIdentifiers = "enabledBundleIdentifiers"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var settings: MovieModeSettings {
        get {
            MovieModeSettings(
                autoMovieModeEnabled: defaults.bool(forKey: Keys.autoMovieModeEnabled),
                displayRule: DisplayRule(rawValue: defaults.string(forKey: Keys.displayRule) ?? "") ?? .playing,
                pinMainDisplay: defaults.object(forKey: Keys.pinMainDisplay) as? Bool ?? true,
                watchDisplayID: defaults.string(forKey: Keys.watchDisplayID),
                useAccessibilityDetection: defaults.bool(forKey: Keys.useAccessibilityDetection),
                enabledBundleIdentifiers: defaults.stringArray(forKey: Keys.enabledBundleIdentifiers)
            )
        }
        set {
            defaults.set(newValue.autoMovieModeEnabled, forKey: Keys.autoMovieModeEnabled)
            defaults.set(newValue.displayRule.rawValue, forKey: Keys.displayRule)
            defaults.set(newValue.pinMainDisplay, forKey: Keys.pinMainDisplay)
            defaults.set(newValue.watchDisplayID, forKey: Keys.watchDisplayID)
            defaults.set(newValue.useAccessibilityDetection, forKey: Keys.useAccessibilityDetection)
            defaults.set(newValue.enabledBundleIdentifiers, forKey: Keys.enabledBundleIdentifiers)
        }
    }
}
