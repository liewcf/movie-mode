import AppKit
import ApplicationServices
import CoreGraphics

enum FullscreenMatchSelector {
    struct Candidate: Equatable {
        let displayID: String
        let bundleIdentifier: String
        let score: Int
    }

    struct Match {
        let displayID: String
        let bundleIdentifier: String
        let score: Int

        var candidate: Candidate {
            Candidate(displayID: displayID, bundleIdentifier: bundleIdentifier, score: score)
        }
    }

    static let nativePlayerBundleIdentifiers: Set<String> = [
        "org.videolan.vlc",
        "com.colliderli.iina",
    ]

    static let browserBundleIdentifiers: Set<String> = [
        "com.apple.Safari",
        "com.google.Chrome",
        "com.brave.Browser",
        "company.thebrowser.Browser",
        "org.mozilla.firefox",
        "org.mozilla.nightly",
        "com.microsoft.edgemac",
        "com.operasoftware.Opera",
    ]

    static let browserMinCoverage: CGFloat = 0.98
    static let nativePlayerMinCoverage: CGFloat = 0.90

    static let browserPresentationMinCoverage: CGFloat = 0.85
    static let browserFullscreenTolerance: CGFloat = 24

    static func selectBest(
        cgWindowList: [[String: Any]]?,
        screens: [NSScreen],
        allowlist: Set<String>,
        frontmostBundleIdentifier: String?,
        includeAccessibility: Bool
    ) -> Match? {
        var candidates: [Candidate] = []

        if let cgWindowList {
            candidates.append(
                contentsOf: candidatesFromWindowList(
                    cgWindowList,
                    screens: screens,
                    allowlist: allowlist,
                    frontmostBundleIdentifier: frontmostBundleIdentifier
                )
            )
        }

        if includeAccessibility, AXIsProcessTrusted() {
            candidates.append(
                contentsOf: candidatesFromAccessibility(
                    screens: screens,
                    allowlist: allowlist,
                    frontmostBundleIdentifier: frontmostBundleIdentifier
                )
            )
        }

        guard let best = candidates.max(by: { $0.score < $1.score }) else {
            return nil
        }

        return Match(displayID: best.displayID, bundleIdentifier: best.bundleIdentifier, score: best.score)
    }

    static func hasFullscreenPlayback(
        forBundleIdentifier bundleID: String,
        cgWindowList: [[String: Any]]?,
        screens: [NSScreen],
        allowlist: Set<String>,
        includeAccessibility: Bool
    ) -> Bool {
        guard allowlist.contains(bundleID) else {
            return false
        }

        var candidates: [Candidate] = []

        if let cgWindowList {
            candidates.append(
                contentsOf: candidatesFromWindowList(
                    cgWindowList,
                    screens: screens,
                    allowlist: allowlist,
                    frontmostBundleIdentifier: nil
                )
            )
        }

        if includeAccessibility, AXIsProcessTrusted() {
            candidates.append(
                contentsOf: candidatesFromAccessibility(
                    screens: screens,
                    allowlist: allowlist,
                    frontmostBundleIdentifier: nil
                )
            )
        }

        return candidates.contains { $0.bundleIdentifier == bundleID }
    }

    /// Browser-only: true while YouTube f-key / HTML5 overlay or native window fullscreen is active.
    static func browserPlaybackIsActive(
        forBundleIdentifier bundleID: String,
        cgWindowList: [[String: Any]]?,
        screens: [NSScreen],
        allowlist: Set<String>,
        includeAccessibility: Bool
    ) -> Bool {
        guard browserBundleIdentifiers.contains(bundleID), allowlist.contains(bundleID) else {
            return false
        }

        if hasPresentationOverlay(
            forBundleIdentifier: bundleID,
            cgWindowList: cgWindowList,
            screens: screens
        ) {
            return true
        }

        return hasFullscreenPlayback(
            forBundleIdentifier: bundleID,
            cgWindowList: cgWindowList,
            screens: screens,
            allowlist: allowlist,
            includeAccessibility: includeAccessibility
        )
    }

    static func hasPresentationOverlay(
        forBundleIdentifier bundleID: String,
        cgWindowList: [[String: Any]]?,
        screens: [NSScreen]
    ) -> Bool {
        guard let cgWindowList else {
            return false
        }

        for windowInfo in cgWindowList {
            guard
                let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
                let app = NSRunningApplication(processIdentifier: pid_t(ownerPID)),
                app.bundleIdentifier == bundleID
            else {
                continue
            }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            guard layer >= 1 else {
                continue
            }

            let quartzBounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            for screen in screens {
                guard let displayBounds = ScreenIdentity.quartzDisplayBounds(for: screen) else {
                    continue
                }

                let coverage = coverageRatio(windowBounds: quartzBounds, screenFrame: displayBounds)
                if coverage >= browserPresentationMinCoverage {
                    return true
                }
            }
        }

        return false
    }

    /// Largest display coverage among all on-screen windows owned by the app (quartz space).
    static func largestWindowCoverage(
        forBundleIdentifier bundleID: String,
        cgWindowList: [[String: Any]]?,
        screens: [NSScreen]
    ) -> CGFloat {
        guard let cgWindowList else {
            return 0
        }

        var best: CGFloat = 0

        for windowInfo in cgWindowList {
            guard
                let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
                let app = NSRunningApplication(processIdentifier: pid_t(ownerPID)),
                app.bundleIdentifier == bundleID
            else {
                continue
            }

            let quartzBounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            for screen in screens {
                guard let displayBounds = ScreenIdentity.quartzDisplayBounds(for: screen) else {
                    continue
                }

                let coverage = coverageRatio(windowBounds: quartzBounds, screenFrame: displayBounds)
                best = max(best, coverage)
            }
        }

        return best
    }

    /// True when a browser session likely ended (exited YouTube f-key / double-click fullscreen).
    static func browserPlaybackLikelyEnded(
        currentCoverage: CGFloat,
        peakCoverage: CGFloat,
        overlayVisible: Bool,
        strictFullscreenVisible: Bool
    ) -> Bool {
        if overlayVisible || strictFullscreenVisible {
            return false
        }

        if peakCoverage >= 0.98 && currentCoverage < 0.955 {
            return true
        }

        if currentCoverage < 0.90 {
            return true
        }

        if peakCoverage >= 0.85 && currentCoverage < peakCoverage - 0.04 {
            return true
        }

        return false
    }

    private static func candidatesFromWindowList(
        _ windowList: [[String: Any]],
        screens: [NSScreen],
        allowlist: Set<String>,
        frontmostBundleIdentifier: String?
    ) -> [Candidate] {
        var candidates: [Candidate] = []

        for windowInfo in windowList {
            guard
                let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
                let app = NSRunningApplication(processIdentifier: pid_t(ownerPID)),
                let bundleID = app.bundleIdentifier,
                allowlist.contains(bundleID)
            else {
                continue
            }

            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
            let quartzBounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            guard let (screen, coverage, displayBounds) = matchingScreenInQuartz(
                for: quartzBounds,
                among: screens,
                bundleID: bundleID,
                layer: layer
            ) else {
                continue
            }

            guard layerIsEligible(
                layer,
                bundleID: bundleID,
                coverage: coverage,
                quartzWindowBounds: quartzBounds,
                displayBounds: displayBounds
            ) else {
                continue
            }

            let score = score(
                bundleID: bundleID,
                frontmostBundleIdentifier: frontmostBundleIdentifier,
                coverage: coverage,
                layer: layer,
                accessibilityConfirmed: false
            )

            candidates.append(
                Candidate(displayID: screen.movieModeScreenID, bundleIdentifier: bundleID, score: score)
            )
        }

        return candidates
    }

    private static func candidatesFromAccessibility(
        screens: [NSScreen],
        allowlist: Set<String>,
        frontmostBundleIdentifier: String?
    ) -> [Candidate] {
        var candidates: [Candidate] = []

        for app in NSWorkspace.shared.runningApplications where !app.isTerminated {
            guard let bundleID = app.bundleIdentifier, allowlist.contains(bundleID) else {
                continue
            }

            let appElement = AXUIElementCreateApplication(app.processIdentifier)
            var windowsValue: CFTypeRef?
            guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
                  let windows = windowsValue as? [AXUIElement]
            else {
                continue
            }

            for window in windows where windowIsFullscreen(window) {
                guard let axFrame = windowFrame(window) else {
                    continue
                }

                guard let (screen, coverage) = matchingScreenForAccessibility(
                    windowBounds: axFrame,
                    among: screens,
                    bundleID: bundleID
                ) else {
                    continue
                }

                let score = score(
                    bundleID: bundleID,
                    frontmostBundleIdentifier: frontmostBundleIdentifier,
                    coverage: coverage,
                    layer: 0,
                    accessibilityConfirmed: true
                )

                candidates.append(
                    Candidate(displayID: screen.movieModeScreenID, bundleIdentifier: bundleID, score: score)
                )
            }
        }

        return candidates
    }

    private static func windowIsFullscreen(_ window: AXUIElement) -> Bool {
        for attribute in ["AXFullScreen", "AXFullscreen"] {
            var value: CFTypeRef?
            guard AXUIElementCopyAttributeValue(window, attribute as CFString, &value) == .success,
                  let isFullscreen = value as? Bool
            else {
                continue
            }

            if isFullscreen {
                return true
            }
        }

        return false
    }

    private static func windowFrame(_ window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionRef = positionValue,
              let sizeRef = sizeValue
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetValue(positionRef as! AXValue, .cgPoint, &position),
              AXValueGetValue(sizeRef as! AXValue, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }

    private static func layerIsEligible(
        _ layer: Int,
        bundleID: String,
        coverage: CGFloat,
        quartzWindowBounds: CGRect,
        displayBounds: CGRect
    ) -> Bool {
        guard layer >= 0 && layer <= 25 else {
            return false
        }

        if nativePlayerBundleIdentifiers.contains(bundleID) {
            return coverage >= nativePlayerMinCoverage
        }

        if browserBundleIdentifiers.contains(bundleID) {
            if ScreenIdentity.isQuartzWindowApproximatelyFullscreen(
                windowBounds: quartzWindowBounds,
                displayBounds: displayBounds,
                tolerance: browserFullscreenTolerance
            ) {
                return true
            }

            // HTML5 / YouTube f-key overlays sit above the page at elevated layers.
            if layer >= 1 && coverage >= browserPresentationMinCoverage {
                return true
            }

            // Chrome native fullscreen sometimes uses elevated layers with a slight inset.
            if layer > 0 && coverage >= 0.95 {
                return true
            }

            return false
        }

        return layer == 0 && coverage >= browserMinCoverage
    }

    private static func matchingScreenInQuartz(
        for windowBounds: CGRect,
        among screens: [NSScreen],
        bundleID: String,
        layer: Int
    ) -> (NSScreen, CGFloat, CGRect)? {
        var bestMatch: NSScreen?
        var bestCoverage: CGFloat = 0
        var bestDisplayBounds: CGRect = .zero

        for screen in screens {
            guard let displayBounds = ScreenIdentity.quartzDisplayBounds(for: screen) else {
                continue
            }

            let coverage = coverageRatio(windowBounds: windowBounds, screenFrame: displayBounds)
            guard qualifiesForScreen(
                bundleID: bundleID,
                layer: layer,
                coverage: coverage,
                windowBounds: windowBounds,
                displayBounds: displayBounds
            ) else {
                continue
            }

            if coverage > bestCoverage {
                bestCoverage = coverage
                bestMatch = screen
                bestDisplayBounds = displayBounds
            }
        }

        guard let bestMatch else {
            return nil
        }

        return (bestMatch, bestCoverage, bestDisplayBounds)
    }

    private static func qualifiesForScreen(
        bundleID: String,
        layer: Int,
        coverage: CGFloat,
        windowBounds: CGRect,
        displayBounds: CGRect
    ) -> Bool {
        if nativePlayerBundleIdentifiers.contains(bundleID) {
            return coverage >= nativePlayerMinCoverage
        }

        if browserBundleIdentifiers.contains(bundleID) {
            if ScreenIdentity.isQuartzWindowApproximatelyFullscreen(
                windowBounds: windowBounds,
                displayBounds: displayBounds,
                tolerance: browserFullscreenTolerance
            ) {
                return true
            }

            if layer >= 1 && coverage >= browserPresentationMinCoverage {
                return true
            }

            return layer > 0 && coverage >= 0.95
        }

        return coverage >= browserMinCoverage
    }

    private static func matchingScreen(
        for windowBounds: CGRect,
        among screens: [NSScreen],
        bundleID: String,
        frontmostBundleIdentifier: String?
    ) -> NSScreen? {
        let minCoverage: CGFloat
        if nativePlayerBundleIdentifiers.contains(bundleID) {
            minCoverage = nativePlayerMinCoverage
        } else if browserBundleIdentifiers.contains(bundleID) {
            minCoverage = browserMinCoverage
        } else {
            minCoverage = browserMinCoverage
        }

        var bestMatch: NSScreen?
        var bestCoverage: CGFloat = 0

        for screen in screens {
            let coverage = coverageRatio(windowBounds: windowBounds, screenFrame: screen.frame)
            guard coverage >= minCoverage else {
                continue
            }

            if coverage > bestCoverage {
                bestCoverage = coverage
                bestMatch = screen
            }
        }

        return bestMatch
    }

    private static func matchingScreenForAccessibility(
        windowBounds: CGRect,
        among screens: [NSScreen],
        bundleID: String
    ) -> (NSScreen, CGFloat)? {
        var bestMatch: NSScreen?
        var bestCoverage: CGFloat = 0

        for screen in screens {
            guard let displayBounds = ScreenIdentity.quartzDisplayBounds(for: screen) else {
                continue
            }

            let coverage = coverageRatio(windowBounds: windowBounds, screenFrame: displayBounds)
            let aligned = ScreenIdentity.isQuartzWindowApproximatelyFullscreen(
                windowBounds: windowBounds,
                displayBounds: displayBounds,
                tolerance: browserBundleIdentifiers.contains(bundleID) ? browserFullscreenTolerance : 8
            )

            guard aligned || coverage >= nativePlayerMinCoverage else {
                continue
            }

            if coverage > bestCoverage {
                bestCoverage = coverage
                bestMatch = screen
            }
        }

        guard let bestMatch else {
            return nil
        }

        return (bestMatch, bestCoverage)
    }

    private static func coverageRatio(windowBounds: CGRect, screenFrame: CGRect) -> CGFloat {
        let intersection = screenFrame.intersection(windowBounds)
        guard !intersection.isNull else {
            return 0
        }

        let screenArea = screenFrame.width * screenFrame.height
        guard screenArea > 0 else {
            return 0
        }

        return (intersection.width * intersection.height) / screenArea
    }

    private static func score(
        bundleID: String,
        frontmostBundleIdentifier: String?,
        coverage: CGFloat,
        layer: Int,
        accessibilityConfirmed: Bool
    ) -> Int {
        var total = Int(coverage * 100)

        if bundleID == frontmostBundleIdentifier {
            total += 1_000
        }

        if nativePlayerBundleIdentifiers.contains(bundleID) {
            total += 500
        } else if browserBundleIdentifiers.contains(bundleID) {
            total += 100
        }

        if accessibilityConfirmed {
            total += 2_000
        }

        if layer == 0 {
            total += 10
        }

        return total
    }
}
