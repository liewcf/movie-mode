import AppKit
import ApplicationServices
import FocusMonitorCore

@MainActor
final class CGWindowFullscreenDetector: FullscreenPlaybackDetecting {
    var onEvent: ((FullscreenPlaybackEvent) -> Void)?

    private var timer: Timer?
    private var workspaceObserver: NSObjectProtocol?
    private var activeSession: (displayID: String, bundleIdentifier: String)?
    private let settingsStore: MovieModeSettingsStore

    init(settingsStore: MovieModeSettingsStore) {
        self.settingsStore = settingsStore
    }

    func start() {
        stop()
        scan()

        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scan()
            }
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scan()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil

        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
            self.workspaceObserver = nil
        }

        if activeSession != nil {
            emitExitedIfNeeded()
        }
    }

    private func scan() {
        if let match = findFullscreenMatch() {
            applyMatch(match)
        } else {
            emitExitedIfNeeded()
        }
    }

    private func findFullscreenMatch() -> (displayID: String, bundleIdentifier: String)? {
        let allowlist = MovieModeBundleAllowlist.resolvedIdentifiers(from: settingsStore.settings)
        let screens = NSScreen.screens

        guard
            let windowList = CGWindowListCopyWindowInfo(
                [.optionOnScreenOnly, .excludeDesktopElements],
                kCGNullWindowID
            ) as? [[String: Any]]
        else {
            return nil
        }

        for windowInfo in windowList {
            guard
                let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: CGFloat],
                let ownerPID = windowInfo[kCGWindowOwnerPID as String] as? Int,
                let app = NSRunningApplication(processIdentifier: pid_t(ownerPID)),
                let bundleID = app.bundleIdentifier,
                allowlist.contains(bundleID),
                layerIsEligible(windowInfo)
            else {
                continue
            }

            let windowBounds = CGRect(
                x: boundsDict["X"] ?? 0,
                y: boundsDict["Y"] ?? 0,
                width: boundsDict["Width"] ?? 0,
                height: boundsDict["Height"] ?? 0
            )

            for screen in screens where ScreenIdentity.isWindowApproximatelyFullscreen(
                windowBounds: windowBounds,
                on: screen
            ) {
                return (screen.movieModeScreenID, bundleID)
            }
        }

        return nil
    }

    private func layerIsEligible(_ windowInfo: [String: Any]) -> Bool {
        let layer = windowInfo[kCGWindowLayer as String] as? Int ?? 0
        return layer >= 0 && layer <= 25
    }

    private func applyMatch(_ match: (displayID: String, bundleIdentifier: String)) {
        if let activeSession, activeSession.displayID == match.displayID, activeSession.bundleIdentifier == match.bundleIdentifier {
            return
        }

        emitExitedIfNeeded()
        activeSession = match
        onEvent?(FullscreenPlaybackEvent(kind: .entered, displayID: match.displayID, bundleIdentifier: match.bundleIdentifier))
    }

    private func emitExitedIfNeeded() {
        guard let activeSession else {
            return
        }

        self.activeSession = nil
        onEvent?(
            FullscreenPlaybackEvent(
                kind: .exited,
                displayID: activeSession.displayID,
                bundleIdentifier: activeSession.bundleIdentifier
            )
        )
    }
}
