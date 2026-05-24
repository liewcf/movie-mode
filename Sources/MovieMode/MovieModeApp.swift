import AppKit
import FocusMonitorCore
import SwiftUI

@main
struct MovieModeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let controller = DisplayShieldController(
        displayProvider: AppKitDisplayProvider(),
        shieldManager: AppKitShieldManager()
    )
    private var statusItem: NSStatusItem?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureStatusItem()
        observeScreenChanges()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.deactivateMovieMode()

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item
        item.button?.target = self
        item.button?.action = #selector(handleStatusItemClick)
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusItem()
    }

    private func observeScreenChanges() {
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.controller.refreshDisplayConfiguration()
                self?.updateStatusItem()
            }
        }
    }

    @objc private func handleStatusItemClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
            return
        }

        controller.toggleMovieMode()
        updateStatusItem()
    }

    @objc private func quit() {
        controller.deactivateMovieMode()
        NSApplication.shared.terminate(nil)
    }

    private func updateStatusItem() {
        guard let button = statusItem?.button else {
            return
        }

        let image = NSImage(
            systemSymbolName: controller.menuBarSymbolName,
            accessibilityDescription: "MovieMode"
        )
        image?.isTemplate = true
        button.image = image
        button.toolTip = controller.statusText
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else {
            return
        }

        let menu = NSMenu()
        let statusItem = NSMenuItem(title: controller.statusText, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let toggleItem = NSMenuItem(title: controller.toggleTitle, action: #selector(handleStatusItemClick), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit MovieMode", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }
}
