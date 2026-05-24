import AppKit
import FocusMonitorCore
import SwiftUI

@main
struct FocusMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var controller = DisplayShieldController(
        displayProvider: AppKitDisplayProvider(),
        shieldManager: AppKitShieldManager()
    )

    var body: some Scene {
        MenuBarExtra {
            FocusMonitorMenu(controller: controller) {
                appDelegate.connect(controller: controller)
            }
        } label: {
            Image(systemName: controller.menuBarSymbolName)
        }
    }
}

private struct FocusMonitorMenu: View {
    @ObservedObject var controller: DisplayShieldController
    let onAppear: () -> Void

    var body: some View {
        Group {
            Button(controller.toggleTitle) {
                controller.toggleMovieMode()
            }

            Text(controller.statusText)
                .foregroundStyle(.secondary)

            Divider()

            Button("Quit Focus Monitor") {
                controller.deactivateMovieMode()
                NSApplication.shared.terminate(nil)
            }
        }
        .onAppear(perform: onAppear)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private weak var controller: DisplayShieldController?
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func connect(controller: DisplayShieldController) {
        guard screenObserver == nil else {
            return
        }

        self.controller = controller
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak controller] _ in
            Task { @MainActor in
                controller?.refreshDisplayConfiguration()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller?.deactivateMovieMode()

        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }
}
