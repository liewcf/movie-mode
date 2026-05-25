import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let settingsStore: ObservableMovieModeSettingsStore

    private static let windowSize = NSSize(width: 560, height: 640)

    init(settingsStore: ObservableMovieModeSettingsStore) {
        self.settingsStore = settingsStore
    }

    func show() {
        settingsStore.refreshDisplays()

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hostingController = NSHostingController(
            rootView: MovieModeSettingsView(store: settingsStore)
        )

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "MovieMode Settings"
        window.contentViewController = hostingController
        window.contentMinSize = Self.windowSize
        window.setContentSize(Self.windowSize)
        window.center()
        window.isReleasedWhenClosed = false
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
