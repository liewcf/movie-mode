import FocusMonitorCore
import Foundation

enum MovieModeBundleAllowlist {
    static let defaultBundleIdentifiers: Set<String> = [
        "org.videolan.vlc",
        "com.colliderli.iina",
        "com.apple.Safari",
        "com.google.Chrome",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "org.mozilla.firefox",
        "org.mozilla.nightly",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
    ]

    static func resolvedIdentifiers(from settings: MovieModeSettings) -> Set<String> {
        if let custom = settings.enabledBundleIdentifiers, !custom.isEmpty {
            return Set(custom)
        }

        return defaultBundleIdentifiers
    }
}
