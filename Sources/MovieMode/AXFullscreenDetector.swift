import AppKit
import ApplicationServices
import FocusMonitorCore

@MainActor
final class AXFullscreenDetector: FullscreenPlaybackDetecting {
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
            Task { @MainActor in
                self?.scan()
            }
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
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

        emitExitedIfNeeded()
    }

    private func scan() {
        guard AXIsProcessTrusted() else {
            emitExitedIfNeeded()
            return
        }

        if let match = findFullscreenMatch() {
            applyMatch(match)
        } else {
            emitExitedIfNeeded()
        }
    }

    private func findFullscreenMatch() -> (displayID: String, bundleIdentifier: String)? {
        let allowlist = MovieModeBundleAllowlist.resolvedIdentifiers(from: settingsStore.settings)

        guard
            let frontmost = NSWorkspace.shared.frontmostApplication,
            let bundleID = frontmost.bundleIdentifier,
            allowlist.contains(bundleID)
        else {
            return nil
        }

        let appElement = AXUIElementCreateApplication(frontmost.processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement]
        else {
            return nil
        }

        for window in windows {
            guard windowIsFullscreen(window),
                  let frame = windowFrame(window),
                  let screen = ScreenIdentity.screen(containing: frame, among: NSScreen.screens)
            else {
                continue
            }

            return (screen.movieModeScreenID, bundleID)
        }

        return nil
    }

    private func windowIsFullscreen(_ window: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &value) == .success,
              let isFullscreen = value as? Bool
        else {
            return false
        }

        return isFullscreen
    }

    private func windowFrame(_ window: AXUIElement) -> CGRect? {
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
