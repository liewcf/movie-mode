import AppKit
import FocusMonitorCore

final class AppKitShieldManager: ShieldManaging {
    private var windowsByDisplayID: [String: NSWindow] = [:]

    func showShield(on display: DisplaySnapshot) -> DisplayShieldToken? {
        let window = DisplayShieldWindow(frame: display.frame)
        windowsByDisplayID[display.id] = window
        window.orderFrontRegardless()
        return DisplayShieldToken(displayID: display.id)
    }

    func closeShield(_ token: DisplayShieldToken) {
        guard let window = windowsByDisplayID.removeValue(forKey: token.displayID) else {
            return
        }

        window.close()
    }
}

private final class DisplayShieldWindow: NSWindow {
    init(frame: CGRect) {
        super.init(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        backgroundColor = .black
        isOpaque = true
        level = .screenSaver
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hasShadow = false
        ignoresMouseEvents = false
        isReleasedWhenClosed = false

        let contentView = NSView(frame: CGRect(origin: .zero, size: frame.size))
        contentView.wantsLayer = true
        contentView.layer?.backgroundColor = NSColor.black.cgColor
        self.contentView = contentView
    }

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }
}
