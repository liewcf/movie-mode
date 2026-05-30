import AppKit
import ApplicationServices
import FocusMonitorCore

@MainActor
final class CompositeFullscreenDetector: FullscreenPlaybackDetecting {
    var onEvent: ((FullscreenPlaybackEvent) -> Void)?

    private var scheduler: FullscreenScanScheduler?
    private var workspaceObserver: NSObjectProtocol?
    private var activeSession: (displayID: String, bundleIdentifier: String)?
    private var consecutiveNoPlaybackCount = 0
    private var sessionStartedAt: Date?
    private var lastExitedAt: Date?
    private var browserWatchLatched = false
    private var peakBrowserCoverage: CGFloat = 0
    /// Suppress false exits while Chrome finishes entering fullscreen and shields settle.
    private let activationGraceDuration: TimeInterval = 3
    /// Ignore new auto-enter briefly after exit (YouTube exit animation looks like fullscreen).
    private let enterCooldownAfterExit: TimeInterval = 4
    private let browserExitScansWhenBackgrounded = 3
    private let browserExitScansPlaybackEnded = 8
    private let nativeExitScansWhileFrontmost = 6
    private let nativeExitScansWhenBackgrounded = 2
    private let settingsStore: MovieModeSettingsStore

    init(settingsStore: MovieModeSettingsStore) {
        self.settingsStore = settingsStore
    }

    func start() {
        stop()

        let scheduler = FullscreenScanScheduler { [weak self] in
            self?.scan()
        }
        scheduler.start()
        self.scheduler = scheduler

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.scan()
            }
        }

        scan()
    }

    func stop() {
        scheduler?.stop()
        scheduler = nil

        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }

        if activeSession != nil {
            emitExitedIfNeeded()
        }
    }

    func restartIfNeeded() {
        stop()
        start()
    }

    func resetTracking() {
        activeSession = nil
        consecutiveNoPlaybackCount = 0
        sessionStartedAt = nil
        browserWatchLatched = false
        peakBrowserCoverage = 0
    }

    func scanNow() {
        scan()
    }

    func resync() {
        resetTracking()
        scanNow()
    }

    private func scan() {
        let settings = settingsStore.settings
        let allowlist = MovieModeBundleAllowlist.resolvedIdentifiers(from: settings)
        let screens = NSScreen.screens
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]

        if let match = findFullscreenMatch(windowList: windowList) {
            if activeSession == nil, isWithinEnterCooldown {
                return
            }

            consecutiveNoPlaybackCount = 0
            applyMatch(match, windowList: windowList, screens: screens)
            return
        }

        guard let session = activeSession else {
            return
        }

        if evaluateBrowserSession(
            session: session,
            windowList: windowList,
            screens: screens,
            allowlist: allowlist,
            settings: settings
        ) {
            consecutiveNoPlaybackCount = 0
            return
        }

        if playbackStillActive(
            session: session,
            windowList: windowList,
            allowlist: allowlist,
            settings: settings
        ) {
            consecutiveNoPlaybackCount = 0
            return
        }

        if isWithinActivationGracePeriod {
            return
        }

        consecutiveNoPlaybackCount += 1

        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let exitThreshold: Int
        if FullscreenMatchSelector.browserBundleIdentifiers.contains(session.bundleIdentifier) {
            exitThreshold = frontmost == session.bundleIdentifier
                ? browserExitScansPlaybackEnded
                : browserExitScansWhenBackgrounded
        } else {
            exitThreshold = frontmost == session.bundleIdentifier
                ? nativeExitScansWhileFrontmost
                : nativeExitScansWhenBackgrounded
        }

        guard consecutiveNoPlaybackCount >= exitThreshold else {
            return
        }

        consecutiveNoPlaybackCount = 0
        clearBrowserLatchState()
        emitExitedIfNeeded()
    }

    /// Browser sessions latch while Chrome is frontmost; exit when coverage drops after true fullscreen.
    private func evaluateBrowserSession(
        session: (displayID: String, bundleIdentifier: String),
        windowList: [[String: Any]]?,
        screens: [NSScreen],
        allowlist: Set<String>,
        settings: MovieModeSettings
    ) -> Bool {
        guard FullscreenMatchSelector.browserBundleIdentifiers.contains(session.bundleIdentifier) else {
            return false
        }

        guard browserWatchLatched else {
            return false
        }

        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        guard frontmost == session.bundleIdentifier else {
            return false
        }

        let currentCoverage = FullscreenMatchSelector.largestWindowCoverage(
            forBundleIdentifier: session.bundleIdentifier,
            cgWindowList: windowList,
            screens: screens
        )
        peakBrowserCoverage = max(peakBrowserCoverage, currentCoverage)

        let overlayVisible = FullscreenMatchSelector.hasPresentationOverlay(
            forBundleIdentifier: session.bundleIdentifier,
            cgWindowList: windowList,
            screens: screens
        )
        let strictVisible = FullscreenMatchSelector.hasFullscreenPlayback(
            forBundleIdentifier: session.bundleIdentifier,
            cgWindowList: windowList,
            screens: screens,
            allowlist: allowlist,
            includeAccessibility: settings.useAccessibilityDetection
        )

        if overlayVisible || strictVisible || FullscreenMatchSelector.browserPlaybackIsActive(
            forBundleIdentifier: session.bundleIdentifier,
            cgWindowList: windowList,
            screens: screens,
            allowlist: allowlist,
            includeAccessibility: settings.useAccessibilityDetection
        ) {
            return true
        }

        return !FullscreenMatchSelector.browserPlaybackLikelyEnded(
            currentCoverage: currentCoverage,
            peakCoverage: peakBrowserCoverage,
            overlayVisible: overlayVisible,
            strictFullscreenVisible: strictVisible
        )
    }

    private var isWithinEnterCooldown: Bool {
        guard let lastExitedAt else {
            return false
        }

        return Date().timeIntervalSince(lastExitedAt) < enterCooldownAfterExit
    }

    private func playbackStillActive(
        session: (displayID: String, bundleIdentifier: String),
        windowList: [[String: Any]]?,
        allowlist: Set<String>,
        settings: MovieModeSettings
    ) -> Bool {
        let screens = NSScreen.screens
        let includeAccessibility = settings.useAccessibilityDetection

        if FullscreenMatchSelector.browserBundleIdentifiers.contains(session.bundleIdentifier) {
            return FullscreenMatchSelector.browserPlaybackIsActive(
                forBundleIdentifier: session.bundleIdentifier,
                cgWindowList: windowList,
                screens: screens,
                allowlist: allowlist,
                includeAccessibility: includeAccessibility
            )
        }

        return FullscreenMatchSelector.hasFullscreenPlayback(
            forBundleIdentifier: session.bundleIdentifier,
            cgWindowList: windowList,
            screens: screens,
            allowlist: allowlist,
            includeAccessibility: includeAccessibility
        )
    }

    private var isWithinActivationGracePeriod: Bool {
        guard let sessionStartedAt else {
            return false
        }

        return Date().timeIntervalSince(sessionStartedAt) < activationGraceDuration
    }

    private func findFullscreenMatch(windowList: [[String: Any]]?) -> (displayID: String, bundleIdentifier: String)? {
        let settings = settingsStore.settings
        let allowlist = MovieModeBundleAllowlist.resolvedIdentifiers(from: settings)

        let match = FullscreenMatchSelector.selectBest(
            cgWindowList: windowList,
            screens: NSScreen.screens,
            allowlist: allowlist,
            frontmostBundleIdentifier: NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
            includeAccessibility: settings.useAccessibilityDetection
        )

        guard let match else {
            return nil
        }

        return (match.displayID, match.bundleIdentifier)
    }

    private func applyMatch(
        _ match: (displayID: String, bundleIdentifier: String),
        windowList: [[String: Any]]?,
        screens: [NSScreen]
    ) {
        let isNewSession = activeSession == nil || activeSession?.bundleIdentifier != match.bundleIdentifier

        if let activeSession {
            if activeSession.displayID == match.displayID, activeSession.bundleIdentifier == match.bundleIdentifier {
                return
            }

            if activeSession.bundleIdentifier == match.bundleIdentifier {
                self.activeSession = match
                onEvent?(
                    FullscreenPlaybackEvent(
                        kind: .entered,
                        displayID: match.displayID,
                        bundleIdentifier: match.bundleIdentifier
                    )
                )
                return
            }

            emitExitedIfNeeded()
        }

        if isNewSession {
            sessionStartedAt = Date()
            if FullscreenMatchSelector.browserBundleIdentifiers.contains(match.bundleIdentifier) {
                browserWatchLatched = true
                peakBrowserCoverage = FullscreenMatchSelector.largestWindowCoverage(
                    forBundleIdentifier: match.bundleIdentifier,
                    cgWindowList: windowList,
                    screens: screens
                )
            } else {
                browserWatchLatched = false
                peakBrowserCoverage = 0
            }
        }

        activeSession = match
        onEvent?(
            FullscreenPlaybackEvent(
                kind: .entered,
                displayID: match.displayID,
                bundleIdentifier: match.bundleIdentifier
            )
        )
    }

    private func clearBrowserLatchState() {
        sessionStartedAt = nil
        browserWatchLatched = false
        peakBrowserCoverage = 0
    }

    private func emitExitedIfNeeded() {
        guard let activeSession else {
            return
        }

        self.activeSession = nil
        clearBrowserLatchState()
        lastExitedAt = Date()
        onEvent?(
            FullscreenPlaybackEvent(
                kind: .exited,
                displayID: activeSession.displayID,
                bundleIdentifier: activeSession.bundleIdentifier
            )
        )
    }
}
