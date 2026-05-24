# Focus Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a menu-bar-only macOS app that toggles black full-screen shields on every non-main display.

**Architecture:** Use SwiftPM with a testable `FocusMonitorCore` library and a thin `FocusMonitor` executable app. Core owns display snapshot models, toggle state, menu labels, and shield orchestration. The app target bridges to AppKit for `NSScreen` discovery, a one-click `NSStatusItem`, and borderless shield windows.

**Tech Stack:** Swift 5.9, SwiftPM, SwiftUI app lifecycle, AppKit `NSStatusItem`, AppKit `NSWindow`, XCTest.

---

## File Structure

- Create `Package.swift`: SwiftPM package with `FocusMonitorCore`, `FocusMonitor`, and `FocusMonitorCoreTests`.
- Create `Sources/FocusMonitorCore/DisplaySnapshot.swift`: simple display identity/frame model.
- Create `Sources/FocusMonitorCore/DisplayShieldController.swift`: testable movie-mode state machine.
- Create `Tests/FocusMonitorCoreTests/DisplayShieldControllerTests.swift`: fake-provider tests for toggle and rebuild behavior.
- Create `Sources/FocusMonitor/FocusMonitorApp.swift`: app entry point, status item click handling, accessory activation policy.
- Create `Sources/FocusMonitor/AppKitDisplayProvider.swift`: `NSScreen` to `DisplaySnapshot` adapter.
- Create `Sources/FocusMonitor/AppKitShieldManager.swift`: creates and closes black shield windows.
- Create `script/build_and_run.sh`: project-local build/run/verify loop for the SwiftPM GUI app.
- Create `.codex/environments/environment.toml`: Codex Run action wired to `./script/build_and_run.sh`.

## Task 1: Scaffold SwiftPM Package

**Files:**
- Create: `Package.swift`
- Create: `Sources/FocusMonitorCore/DisplaySnapshot.swift`
- Create: `Tests/FocusMonitorCoreTests/DisplayShieldControllerTests.swift`

- [ ] **Step 1: Write the failing package test**

```swift
import CoreGraphics
import XCTest
@testable import FocusMonitorCore

final class DisplayShieldControllerTests: XCTestCase {
    @MainActor
    func testActivatingMovieModeShieldsOnlyNonMainDisplays() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "side", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.toggleMovieMode()

        XCTAssertTrue(controller.isMovieModeActive)
        XCTAssertEqual(shieldManager.shownDisplayIDs, ["side"])
        XCTAssertEqual(controller.shieldedDisplayCount, 1)
        XCTAssertEqual(controller.statusText, "Shielding 1 display")
        XCTAssertEqual(controller.toggleTitle, "Stop Movie Mode")
        XCTAssertEqual(controller.menuBarSymbolName, "moon.fill")
    }
}

private final class FakeDisplayProvider: DisplayProviding {
    var displays: [DisplaySnapshot]

    init(displays: [DisplaySnapshot]) {
        self.displays = displays
    }

    func currentDisplays() -> [DisplaySnapshot] {
        displays
    }
}

private final class FakeShieldManager: ShieldManaging {
    private(set) var shownDisplayIDs: [String] = []
    private(set) var closedTokens: [DisplayShieldToken] = []

    func showShield(on display: DisplaySnapshot) -> DisplayShieldToken? {
        shownDisplayIDs.append(display.id)
        return DisplayShieldToken(displayID: display.id)
    }

    func closeShield(_ token: DisplayShieldToken) {
        closedTokens.append(token)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `swift test --filter DisplayShieldControllerTests/testActivatingMovieModeShieldsOnlyNonMainDisplays`

Expected: FAIL because `Package.swift` or `FocusMonitorCore` types do not exist yet.

- [ ] **Step 3: Add minimal package and display model**

```swift
// Package.swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "FocusMonitor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(name: "FocusMonitorCore", targets: ["FocusMonitorCore"]),
        .executable(name: "FocusMonitor", targets: ["FocusMonitor"])
    ],
    targets: [
        .target(name: "FocusMonitorCore"),
        .executableTarget(
            name: "FocusMonitor",
            dependencies: ["FocusMonitorCore"]
        ),
        .testTarget(
            name: "FocusMonitorCoreTests",
            dependencies: ["FocusMonitorCore"]
        )
    ]
)
```

```swift
// Sources/FocusMonitorCore/DisplaySnapshot.swift
import CoreGraphics

public struct DisplaySnapshot: Equatable, Identifiable {
    public let id: String
    public let frame: CGRect
    public let isMain: Bool

    public init(id: String, frame: CGRect, isMain: Bool) {
        self.id = id
        self.frame = frame
        self.isMain = isMain
    }
}
```

```swift
// Sources/FocusMonitor/main.swift
print("Focus Monitor")
```

- [ ] **Step 4: Run test to verify remaining expected failure**

Run: `swift test --filter DisplayShieldControllerTests/testActivatingMovieModeShieldsOnlyNonMainDisplays`

Expected: FAIL because `DisplayShieldController`, `DisplayProviding`, `ShieldManaging`, and `DisplayShieldToken` do not exist yet.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources Tests
git commit -m "Add SwiftPM scaffold"
```

## Task 2: Implement Testable Movie-Mode Controller

**Files:**
- Modify: `Sources/FocusMonitorCore/DisplaySnapshot.swift`
- Create: `Sources/FocusMonitorCore/DisplayShieldController.swift`
- Modify: `Tests/FocusMonitorCoreTests/DisplayShieldControllerTests.swift`

- [ ] **Step 1: Extend failing tests**

Replace `Tests/FocusMonitorCoreTests/DisplayShieldControllerTests.swift` with:

```swift
import CoreGraphics
import XCTest
@testable import FocusMonitorCore

final class DisplayShieldControllerTests: XCTestCase {
    @MainActor
    func testActivatingMovieModeShieldsOnlyNonMainDisplays() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "side", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.toggleMovieMode()

        XCTAssertTrue(controller.isMovieModeActive)
        XCTAssertEqual(shieldManager.shownDisplayIDs, ["side"])
        XCTAssertEqual(controller.shieldedDisplayCount, 1)
        XCTAssertEqual(controller.statusText, "Shielding 1 display")
        XCTAssertEqual(controller.toggleTitle, "Stop Movie Mode")
        XCTAssertEqual(controller.menuBarSymbolName, "moon.fill")
    }

    @MainActor
    func testStoppingMovieModeClosesExistingShields() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), isMain: false),
            DisplaySnapshot(id: "right", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.toggleMovieMode()
        controller.toggleMovieMode()

        XCTAssertFalse(controller.isMovieModeActive)
        XCTAssertEqual(shieldManager.closedTokens, [
            DisplayShieldToken(displayID: "left"),
            DisplayShieldToken(displayID: "right")
        ])
        XCTAssertEqual(controller.shieldedDisplayCount, 0)
        XCTAssertEqual(controller.statusText, "Movie Mode Off")
        XCTAssertEqual(controller.toggleTitle, "Start Movie Mode")
        XCTAssertEqual(controller.menuBarSymbolName, "moon")
    }

    @MainActor
    func testActivatingWithOnlyMainDisplayReportsNoExtraDisplays() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.toggleMovieMode()

        XCTAssertTrue(controller.isMovieModeActive)
        XCTAssertEqual(shieldManager.shownDisplayIDs, [])
        XCTAssertEqual(controller.shieldedDisplayCount, 0)
        XCTAssertEqual(controller.statusText, "No extra displays")
    }

    @MainActor
    func testRefreshingDisplaysWhileActiveReplacesStaleShields() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.toggleMovieMode()
        provider.displays = [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "right", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ]
        controller.refreshDisplayConfiguration()

        XCTAssertEqual(shieldManager.closedTokens, [DisplayShieldToken(displayID: "left")])
        XCTAssertEqual(shieldManager.shownDisplayIDs, ["left", "right"])
        XCTAssertEqual(controller.shieldedDisplayCount, 1)
    }
}

private final class FakeDisplayProvider: DisplayProviding {
    var displays: [DisplaySnapshot]

    init(displays: [DisplaySnapshot]) {
        self.displays = displays
    }

    func currentDisplays() -> [DisplaySnapshot] {
        displays
    }
}

private final class FakeShieldManager: ShieldManaging {
    private(set) var shownDisplayIDs: [String] = []
    private(set) var closedTokens: [DisplayShieldToken] = []

    func showShield(on display: DisplaySnapshot) -> DisplayShieldToken? {
        shownDisplayIDs.append(display.id)
        return DisplayShieldToken(displayID: display.id)
    }

    func closeShield(_ token: DisplayShieldToken) {
        closedTokens.append(token)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DisplayShieldControllerTests`

Expected: FAIL because controller and protocols are not implemented.

- [ ] **Step 3: Implement controller**

```swift
// Sources/FocusMonitorCore/DisplayShieldController.swift
import Foundation

public protocol DisplayProviding {
    func currentDisplays() -> [DisplaySnapshot]
}

public protocol ShieldManaging {
    func showShield(on display: DisplaySnapshot) -> DisplayShieldToken?
    func closeShield(_ token: DisplayShieldToken)
}

public struct DisplayShieldToken: Equatable {
    public let displayID: String

    public init(displayID: String) {
        self.displayID = displayID
    }
}

@MainActor
public final class DisplayShieldController: ObservableObject {
    @Published public private(set) var isMovieModeActive = false
    @Published public private(set) var shieldedDisplayCount = 0

    private let displayProvider: DisplayProviding
    private let shieldManager: ShieldManaging
    private var activeTokens: [DisplayShieldToken] = []

    public init(displayProvider: DisplayProviding, shieldManager: ShieldManaging) {
        self.displayProvider = displayProvider
        self.shieldManager = shieldManager
    }

    public var toggleTitle: String {
        isMovieModeActive ? "Stop Movie Mode" : "Start Movie Mode"
    }

    public var menuBarSymbolName: String {
        isMovieModeActive ? "moon.fill" : "moon"
    }

    public var statusText: String {
        if !isMovieModeActive {
            return "Movie Mode Off"
        }

        if shieldedDisplayCount == 0 {
            return "No extra displays"
        }

        if shieldedDisplayCount == 1 {
            return "Shielding 1 display"
        }

        return "Shielding \(shieldedDisplayCount) displays"
    }

    public func toggleMovieMode() {
        if isMovieModeActive {
            deactivateMovieMode()
        } else {
            activateMovieMode()
        }
    }

    public func refreshDisplayConfiguration() {
        guard isMovieModeActive else {
            return
        }

        closeActiveShields()
        createShieldsForCurrentDisplays()
    }

    public func deactivateMovieMode() {
        closeActiveShields()
        isMovieModeActive = false
    }

    private func activateMovieMode() {
        isMovieModeActive = true
        createShieldsForCurrentDisplays()
    }

    private func createShieldsForCurrentDisplays() {
        activeTokens = displayProvider.currentDisplays()
            .filter { !$0.isMain }
            .compactMap { shieldManager.showShield(on: $0) }
        shieldedDisplayCount = activeTokens.count
    }

    private func closeActiveShields() {
        activeTokens.forEach { shieldManager.closeShield($0) }
        activeTokens.removeAll()
        shieldedDisplayCount = 0
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DisplayShieldControllerTests`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/FocusMonitorCore Tests/FocusMonitorCoreTests
git commit -m "Add movie mode controller"
```

## Task 3: Add Menu Bar App and AppKit Display Bridge

**Files:**
- Delete: `Sources/FocusMonitor/main.swift`
- Create: `Sources/FocusMonitor/FocusMonitorApp.swift`
- Create: `Sources/FocusMonitor/AppKitDisplayProvider.swift`
- Create: `Sources/FocusMonitor/AppKitShieldManager.swift`

- [ ] **Step 1: Run package tests before app code**

Run: `swift test --filter DisplayShieldControllerTests`

Expected: PASS.

- [ ] **Step 2: Add the one-click status item app**

```swift
// Sources/FocusMonitor/FocusMonitorApp.swift
import AppKit
import FocusMonitorCore
import SwiftUI

@main
struct FocusMonitorApp: App {
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
            accessibilityDescription: "Focus Monitor"
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

        let quitItem = NSMenuItem(title: "Quit Focus Monitor", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
    }
}
```

- [ ] **Step 3: Add AppKit display provider**

```swift
// Sources/FocusMonitor/AppKitDisplayProvider.swift
import AppKit
import FocusMonitorCore

struct AppKitDisplayProvider: DisplayProviding {
    func currentDisplays() -> [DisplaySnapshot] {
        let mainScreenNumber = NSScreen.main?.focusMonitorScreenID

        return NSScreen.screens.map { screen in
            DisplaySnapshot(
                id: screen.focusMonitorScreenID,
                frame: screen.frame,
                isMain: screen.focusMonitorScreenID == mainScreenNumber
            )
        }
    }
}

private extension NSScreen {
    var focusMonitorScreenID: String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = deviceDescription[key] as? NSNumber {
            return number.stringValue
        }

        return "\(frame.origin.x),\(frame.origin.y),\(frame.width),\(frame.height)"
    }
}
```

- [ ] **Step 4: Add AppKit shield manager**

```swift
// Sources/FocusMonitor/AppKitShieldManager.swift
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
```

- [ ] **Step 5: Build to verify app target compiles**

Run: `swift build`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Sources/FocusMonitor
git commit -m "Add menu bar app shell"
```

## Task 4: Confirm Display Configuration Refresh

**Files:**
- Read: `Sources/FocusMonitor/FocusMonitorApp.swift`

- [ ] **Step 1: Build to confirm screen-change observer integration**

Run: `swift build`

Expected: PASS.

- [ ] **Step 2: Run controller tests**

Run: `swift test --filter DisplayShieldControllerTests`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add Sources/FocusMonitor/FocusMonitorApp.swift
git commit -m "Refresh shields on display changes"
```

## Task 5: Add Build/Run Script and Codex Run Action

**Files:**
- Create: `script/build_and_run.sh`
- Create: `.codex/environments/environment.toml`

- [ ] **Step 1: Add build/run script**

```bash
#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="FocusMonitor"
BUNDLE_ID="com.liewcf.FocusMonitor"
MIN_SYSTEM_VERSION="13.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
```

- [ ] **Step 2: Make script executable**

Run: `chmod +x script/build_and_run.sh`

Expected: no output.

- [ ] **Step 3: Add Codex Run action**

```toml
# THIS IS AUTOGENERATED. DO NOT EDIT MANUALLY
version = 1
name = "focus-monitor"

[setup]
script = ""

[[actions]]
name = "Run"
icon = "run"
command = "./script/build_and_run.sh"
```

- [ ] **Step 4: Verify build script**

Run: `./script/build_and_run.sh --verify`

Expected: PASS, app bundle exists at `dist/FocusMonitor.app`, and `pgrep -x FocusMonitor` finds the running process.

- [ ] **Step 5: Commit**

```bash
git add script/build_and_run.sh .codex/environments/environment.toml
git commit -m "Add app run script"
```

## Task 6: Final Verification

**Files:**
- Read: `docs/superpowers/specs/2026-05-25-focus-monitor-design.md`
- Read: `docs/superpowers/plans/2026-05-25-focus-monitor-implementation.md`

- [ ] **Step 1: Run tests**

Run: `swift test`

Expected: PASS.

- [ ] **Step 2: Run build**

Run: `swift build`

Expected: PASS.

- [ ] **Step 3: Run app verify**

Run: `./script/build_and_run.sh --verify`

Expected: PASS and `dist/FocusMonitor.app` exists.

- [ ] **Step 4: Confirm git state**

Run: `git status --short`

Expected: clean working tree.

- [ ] **Step 5: Record limitation**

In the final report, state whether multi-monitor visual behavior was verified. If the test Mac has only one active display or UI inspection is unavailable, say that the app build/process was verified but actual secondary-display shielding still needs a live multi-monitor check.
