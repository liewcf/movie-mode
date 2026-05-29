import AppKit
import ApplicationServices
import FocusMonitorCore

@MainActor
final class CompositeFullscreenDetector: FullscreenPlaybackDetecting {
    var onEvent: ((FullscreenPlaybackEvent) -> Void)?

    private var scheduler: FullscreenScanScheduler?
    private var workspaceObserver: NSObjectProtocol?
    private var activeSession: (displayID: String, bundleIdentifier: String)?
    private var consecutiveMissCount = 0
    private var sessionStartedAt: Date?
    /// Suppress false exits while Chrome finishes entering fullscreen and shields settle.
    private let activationGraceDuration: TimeInterval = 5
    private let exitMissThresholdWhenNotFullscreen = 2
    private let exitMissThresholdWhileFrontmost = 5
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
        consecutiveMissCount = 0
        sessionStartedAt = nil
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
        let windowList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]]

        if let match = findFullscreenMatch(windowList: windowList) {
            consecutiveMissCount = 0
            applyMatch(match)
            return
        }

        guard let session = activeSession else {
            return
        }

        let stillFullscreen = FullscreenMatchSelector.hasFullscreenPlayback(
            forBundleIdentifier: session.bundleIdentifier,
            cgWindowList: windowList,
            screens: NSScreen.screens,
            allowlist: allowlist,
            includeAccessibility: settings.useAccessibilityDetection
        )

        if stillFullscreen {
            consecutiveMissCount = 0
            return
        }

        if isWithinActivationGracePeriod {
            return
        }

        consecutiveMissCount += 1
        let frontmost = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let threshold = frontmost == session.bundleIdentifier
            ? exitMissThresholdWhileFrontmost
            : exitMissThresholdWhenNotFullscreen
        guard consecutiveMissCount >= threshold else {
            return
        }

        consecutiveMissCount = 0
        sessionStartedAt = nil
        emitExitedIfNeeded()
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

    private func applyMatch(_ match: (displayID: String, bundleIdentifier: String)) {
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

    private func emitExitedIfNeeded() {
        guard let activeSession else {
            return
        }

        self.activeSession = nil
        sessionStartedAt = nil
        onEvent?(
            FullscreenPlaybackEvent(
                kind: .exited,
                displayID: activeSession.displayID,
                bundleIdentifier: activeSession.bundleIdentifier
            )
        )
    }
}
