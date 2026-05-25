import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settingsStore: ObservableMovieModeSettingsStore

    private static let contentWidth: CGFloat = 520
    private static let contentHeight: CGFloat = 620

    init(settingsStore: ObservableMovieModeSettingsStore) {
        self.settingsStore = settingsStore
    }

    func show() {
        if let window {
            settingsStore.refreshDisplays()
            resizeWindowIfNeeded(window)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(
            rootView: MovieModeSettingsView(store: settingsStore)
        )
        if #available(macOS 13.0, *) {
            hostingController.sizingOptions = [.preferredContentSize]
        }

        let window = NSWindow(contentViewController: hostingController)
        window.title = "MovieMode Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.window = window

        settingsStore.refreshDisplays()
        resizeWindowIfNeeded(window)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func resizeWindowIfNeeded(_ window: NSWindow) {
        guard let hostingView = window.contentView else {
            window.setContentSize(NSSize(width: Self.contentWidth, height: Self.contentHeight))
            window.center()
            return
        }

        hostingView.layoutSubtreeIfNeeded()
        let fitting = hostingView.fittingSize
        let width = max(Self.contentWidth, fitting.width)
        let height = max(Self.contentHeight, fitting.height)
        window.setContentSize(NSSize(width: width, height: height))
        window.center()
    }
}
