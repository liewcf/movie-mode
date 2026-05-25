public struct MovieModeSettings: Equatable, Codable, Sendable {
    public var autoMovieModeEnabled: Bool
    public var displayRule: DisplayRule
    public var pinMainDisplay: Bool
    public var watchDisplayID: String?
    public var useAccessibilityDetection: Bool
    public var enabledBundleIdentifiers: [String]?

    public init(
        autoMovieModeEnabled: Bool = false,
        displayRule: DisplayRule = .playing,
        pinMainDisplay: Bool = true,
        watchDisplayID: String? = nil,
        useAccessibilityDetection: Bool = false,
        enabledBundleIdentifiers: [String]? = nil
    ) {
        self.autoMovieModeEnabled = autoMovieModeEnabled
        self.displayRule = displayRule
        self.pinMainDisplay = pinMainDisplay
        self.watchDisplayID = watchDisplayID
        self.useAccessibilityDetection = useAccessibilityDetection
        self.enabledBundleIdentifiers = enabledBundleIdentifiers
    }

    public static let defaults = MovieModeSettings()

    public var visibilityPolicy: DisplayVisibilityPolicy {
        DisplayVisibilityPolicy(
            rule: displayRule,
            pinMainDisplay: pinMainDisplay,
            watchDisplayID: watchDisplayID
        )
    }
}

public protocol MovieModeSettingsStore: AnyObject {
    var settings: MovieModeSettings { get set }
}
