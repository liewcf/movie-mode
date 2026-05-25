# Auto Movie Mode Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add optional auto movie mode when eligible apps fullscreen, with display rules (playing / main / watch), pin-main safety, and heuristic + optional AX detection.

**Architecture:** `DisplayVisibilityPolicy` computes shield targets; `DisplayShieldController` shields explicit display IDs; `MovieModeCoordinator` merges manual/auto activation; AppKit detectors emit fullscreen events into the coordinator.

**Tech Stack:** Swift 5.9+, SwiftPM, AppKit, FocusMonitorCore, XCTest, UserDefaults, ApplicationServices (AX), CoreGraphics (window list).

**Spec:** `design/auto-movie-mode-design.md`

---

## File map

| File | Action |
|------|--------|
| `Sources/FocusMonitorCore/DisplayVisibilityPolicy.swift` | Create |
| `Sources/FocusMonitorCore/MovieModeActivationSource.swift` | Create |
| `Sources/FocusMonitorCore/MovieModeSettings.swift` | Create |
| `Sources/FocusMonitorCore/MovieModeCoordinator.swift` | Create |
| `Sources/FocusMonitorCore/FullscreenPlaybackDetecting.swift` | Create |
| `Sources/FocusMonitorCore/DisplayShieldController.swift` | Modify |
| `Tests/FocusMonitorCoreTests/DisplayVisibilityPolicyTests.swift` | Create |
| `Tests/FocusMonitorCoreTests/MovieModeCoordinatorTests.swift` | Create |
| `Tests/FocusMonitorCoreTests/DisplayShieldControllerTests.swift` | Modify |
| `Sources/MovieMode/CGWindowFullscreenDetector.swift` | Create (2a) |
| `Sources/MovieMode/AXFullscreenDetector.swift` | Create (2b) |
| `Sources/MovieMode/CompositeFullscreenDetector.swift` | Create (2b) |
| `Sources/MovieMode/UserDefaultsMovieModeSettingsStore.swift` | Create |
| `Sources/MovieMode/MovieModeSettingsView.swift` | Create (2b) |
| `Sources/MovieMode/MovieModeApp.swift` | Modify |
| `README.md` | Modify (FAQ for auto mode) |

---

## Phase 2a — Core policy, coordinator, heuristics, minimal UI

### Task 1: Display visibility policy

**Files:**
- Create: `Sources/FocusMonitorCore/DisplayVisibilityPolicy.swift`
- Create: `Tests/FocusMonitorCoreTests/DisplayVisibilityPolicyTests.swift`

- [ ] **Step 1: Write failing policy tests**

```swift
// DisplayVisibilityPolicyTests.swift — key cases
func testPlayingRuleShieldsNonPlayingDisplays() {
    let displays = [
        DisplaySnapshot(id: "main", frame: .zero, isMain: true),
        DisplaySnapshot(id: "side", frame: .zero, isMain: false),
    ]
    let policy = DisplayVisibilityPolicy(rule: .playing, pinMainDisplay: false, watchDisplayID: nil)
    let visible = policy.visibleDisplayIDs(displays: displays, playingDisplayID: "main")
    XCTAssertEqual(visible, Set(["main"]))
    XCTAssertEqual(policy.shieldDisplayIDs(displays: displays, playingDisplayID: "main"), Set(["side"]))
}

func testPlayingRuleWithPinMainKeepsMainWhenPlayingOnSide() {
    let displays = [
        DisplaySnapshot(id: "main", frame: .zero, isMain: true),
        DisplaySnapshot(id: "tv", frame: .zero, isMain: false),
    ]
    let policy = DisplayVisibilityPolicy(rule: .playing, pinMainDisplay: true, watchDisplayID: nil)
    let visible = policy.visibleDisplayIDs(displays: displays, playingDisplayID: "tv")
    XCTAssertEqual(visible, Set(["main", "tv"]))
    XCTAssertEqual(policy.shieldDisplayIDs(displays: displays, playingDisplayID: "tv"), Set<String>())
}

func testWatchRuleOnlyTriggersWhenPlayingOnWatch() {
    let policy = DisplayVisibilityPolicy(rule: .watch, pinMainDisplay: false, watchDisplayID: "tv")
    XCTAssertTrue(policy.shouldAutoActivate(playingDisplayID: "tv"))
    XCTAssertFalse(policy.shouldAutoActivate(playingDisplayID: "main"))
}
```

- [ ] **Step 2: Run tests**

Run: `swift test --filter DisplayVisibilityPolicyTests`  
Expected: FAIL (type not found)

- [ ] **Step 3: Implement policy**

```swift
public enum DisplayRule: String, Codable, CaseIterable {
    case playing
    case main
    case watch
}

public struct DisplayVisibilityPolicy: Equatable {
    public var rule: DisplayRule
    public var pinMainDisplay: Bool
    public var watchDisplayID: String?

    public func visibleDisplayIDs(displays: [DisplaySnapshot], playingDisplayID: String?) -> Set<String> {
        var visible = Set<String>()
        switch rule {
        case .playing:
            if let playingDisplayID { visible.insert(playingDisplayID) }
        case .main:
            if let main = displays.first(where: \.isMain)?.id { visible.insert(main) }
        case .watch:
            if let watchDisplayID { visible.insert(watchDisplayID) }
        }
        if pinMainDisplay, let main = displays.first(where: \.isMain)?.id {
            visible.insert(main)
        }
        return visible
    }

    public func shieldDisplayIDs(displays: [DisplaySnapshot], playingDisplayID: String?) -> Set<String> {
        let all = Set(displays.map(\.id))
        return all.subtracting(visibleDisplayIDs(displays: displays, playingDisplayID: playingDisplayID))
    }

    public func shouldAutoActivate(playingDisplayID: String?) -> Bool {
        guard let playingDisplayID else { return false }
        switch rule {
        case .playing: return true
        case .main: return displaysMainMatch(playingDisplayID)
        case .watch: return playingDisplayID == watchDisplayID
        }
    }
    // helper: compare playingDisplayID to main id from displays — pass displays into shouldAutoActivate in real impl
}
```

Adjust `shouldAutoActivate` to accept `displays:` parameter in implementation (fix test accordingly).

- [ ] **Step 4: Run tests — PASS**

Run: `swift test --filter DisplayVisibilityPolicyTests`

---

### Task 2: Activation source + settings model

**Files:**
- Create: `Sources/FocusMonitorCore/MovieModeActivationSource.swift`
- Create: `Sources/FocusMonitorCore/MovieModeSettings.swift`

- [ ] **Step 1: Add types with defaults matching spec**

```swift
public enum MovieModeActivationSource: Equatable {
    case manual
    case auto
}

public struct MovieModeSettings: Equatable, Codable {
    public var autoMovieModeEnabled: Bool = false
    public var displayRule: DisplayRule = .playing
    public var pinMainDisplay: Bool = true
    public var watchDisplayID: String? = nil
    public var useAccessibilityDetection: Bool = false

    public static let defaults = MovieModeSettings()
}

public protocol MovieModeSettingsStore: AnyObject {
    var settings: MovieModeSettings { get set }
}
```

- [ ] **Step 2: Build**

Run: `swift build`  
Expected: BUILD SUCCEEDED

---

### Task 3: Refactor DisplayShieldController for explicit shield IDs

**Files:**
- Modify: `Sources/FocusMonitorCore/DisplayShieldController.swift`
- Modify: `Tests/FocusMonitorCoreTests/DisplayShieldControllerTests.swift`

- [ ] **Step 1: Add failing test for explicit shields**

```swift
func testActivateWithExplicitShieldIDs() {
    let provider = FakeDisplayProvider(displays: [
        DisplaySnapshot(id: "main", frame: .zero, isMain: true),
        DisplaySnapshot(id: "side", frame: .zero, isMain: false),
        DisplaySnapshot(id: "tv", frame: .zero, isMain: false),
    ])
    let shieldManager = FakeShieldManager()
    let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

    controller.activateMovieMode(shieldDisplayIDs: ["side"])

    XCTAssertEqual(Set(shieldManager.shownDisplayIDs), Set(["side"]))
}
```

- [ ] **Step 2: Implement**

- Add `public private(set) var activationSource: MovieModeActivationSource?`
- Replace `createShieldsForCurrentDisplays()` filter `!isMain` with `activateMovieMode(shieldDisplayIDs: Set<String>)`
- Keep `toggleMovieMode()` using **legacy default** `shieldDisplayIDs: non-main` for backward compatibility OR delegate to policy from coordinator only (coordinator becomes sole caller — preferred).

- [ ] **Step 3: Update existing tests** to call `activateMovieMode(shieldDisplayIDs: ["side"])` etc. where needed.

- [ ] **Step 4: Run all FocusMonitorCore tests**

Run: `swift test`

---

### Task 4: MovieModeCoordinator

**Files:**
- Create: `Sources/FocusMonitorCore/MovieModeCoordinator.swift`
- Create: `Sources/FocusMonitorCore/FullscreenPlaybackDetecting.swift`
- Create: `Tests/FocusMonitorCoreTests/MovieModeCoordinatorTests.swift`

- [ ] **Step 1: Define detector protocol**

```swift
public struct FullscreenPlaybackEvent: Equatable {
    public enum Kind: Equatable { case entered, exited }
    public var kind: Kind
    public var displayID: String
    public var bundleIdentifier: String
}

@MainActor
public protocol FullscreenPlaybackDetecting: AnyObject {
    var onEvent: ((FullscreenPlaybackEvent) -> Void)? { get set }
    func start()
    func stop()
}
```

- [ ] **Step 2: Failing coordinator tests**

```swift
func testAutoEnterAppliesShields() { /* fake detector .entered, settings auto on */ }
func testAutoExitDeactivatesOnlyWhenAutoSourced() { /* ... */ }
func testManualTogglePreventsAutoExit() { /* enter auto, user manual toggle, exit fullscreen, still active */ }
```

- [ ] **Step 3: Implement coordinator**

- Holds: `DisplayShieldController`, `DisplayVisibilityPolicy` (derived from settings), `MovieModeSettings`, weak detector callback.
- `handle(event:)` → if `!settings.autoMovieModeEnabled` return.
- On `.entered`: if `policy.shouldAutoActivate(...)` → compute shields → `activateMovieMode(shieldDisplayIDs:source:.auto)`.
- On `.exited`: if `controller.activationSource == .auto` → deactivate.
- `toggleManual()` → flips with `.manual` source and policy shields (playing display ID optional nil → use main-only visible for manual per spec: **manual uses rule at toggle time without requiring fullscreen** — use `playingDisplayID: nil` → for rule B with nil playing, visible = pinMain only? **Spec says manual uses rule at toggle.** For B without playing: visible = pinMain ? {main} : {} → shield all non-visible. Document: manual + playing rule + no playing → treat as **main** visible if pinMain else **all non-main** (legacy). Simplest v1 manual: keep **legacy shield all non-main** when `playingDisplayID == nil`.

- [ ] **Step 4: Run tests — PASS**

---

### Task 5: CGWindow heuristic detector (AppKit)

**Files:**
- Create: `Sources/MovieMode/CGWindowFullscreenDetector.swift`
- Modify: `Sources/MovieMode/MovieModeApp.swift`

- [ ] **Step 1: Implement detector**

- Timer interval ~0.5s while running; also refresh on `NSWorkspace.didActivateApplicationNotification`.
- Default bundle IDs: VLC, IINA, Chrome, Safari, Arc, Firefox.
- `screenForWindow(bounds:)` → `DisplaySnapshot.id` matching `AppKitDisplayProvider` IDs.
- Emit edge-triggered entered/exited (debounce same display+bundle).

- [ ] **Step 2: Wire in AppDelegate**

- `UserDefaultsMovieModeSettingsStore`, `MovieModeCoordinator`, start detector when `autoMovieModeEnabled`.
- Right-click menu: **Auto Movie Mode** checkmark toggles setting.

- [ ] **Step 3: Manual verification**

Run: `./script/build_and_run.sh --verify`  
Test: VLC fullscreen on main → side shielded; exit fullscreen → shields off (auto on).

- [ ] **Step 4: Run `swift test`**

---

### Task 6: UserDefaults settings store (2a minimal)

**Files:**
- Create: `Sources/MovieMode/UserDefaultsMovieModeSettingsStore.swift`

- [ ] **Step 1: Codable persistence** for `MovieModeSettings` keys under `com.moviemode.settings` (or bundle ID prefix).

- [ ] **Step 2: Coordinator reads store** on change; changing auto toggles detector start/stop.

---

## Phase 2b — Full settings UI, rules A/C, Accessibility

### Task 7: Settings SwiftUI view

**Files:**
- Create: `Sources/MovieMode/MovieModeSettingsView.swift`
- Modify: `Sources/MovieMode/MovieModeApp.swift`

- [ ] **Step 1: Build form**

- Toggles: Auto, Pin Main, Use Accessibility
- Picker: Display rule (Playing / Main / Watch)
- Watch: `Picker` populated from `AppKitDisplayProvider().currentDisplays()` with friendly names (`NSScreen.localizedName`).

- [ ] **Step 2: Replace `Settings { EmptyView() }` with `MovieModeSettingsView(store:)`**

- [ ] **Step 3: Menu** “Settings…” → `NSApp.sendAction(terminateAndShowSettings)` or `openSettingsWindow` (macOS 14+).

---

### Task 8: AX detector + composite

**Files:**
- Create: `Sources/MovieMode/AXFullscreenDetector.swift`
- Create: `Sources/MovieMode/CompositeFullscreenDetector.swift`

- [ ] **Step 1: AXFullscreenDetector**

- Check `AXIsProcessTrusted()`; prompt via `AXIsProcessTrustedWithOptions` when user enables setting.
- Observe frontmost app; query windows for fullscreen attribute.

- [ ] **Step 2: Composite** prefers AX when enabled and trusted; else CGWindow.

- [ ] **Step 3: Settings copy** explaining Accessibility for YouTube/browser accuracy.

---

### Task 9: Policy tests for rule A and C

**Files:**
- Modify: `Tests/FocusMonitorCoreTests/DisplayVisibilityPolicyTests.swift`

- [ ] **Step 1: Add cases** for main-only auto gate, watch display, main rule shields.

Run: `swift test`

---

## Phase 2c — Allowlist + docs

### Task 10: App allowlist (optional bundle IDs)

**Files:**
- Modify: `Sources/FocusMonitorCore/MovieModeSettings.swift`
- Modify: `Sources/MovieMode/MovieModeSettingsView.swift`
- Modify: `Sources/MovieMode/CGWindowFullscreenDetector.swift`

- [ ] **Step 1: `enabledBundleIdentifiers: Set<String>?`** — nil means built-in defaults.

- [ ] **Step 2: Settings list editor** (add/remove bundle IDs).

---

### Task 11: README / FAQ

**Files:**
- Modify: `README.md`

- [ ] **Document:** auto mode, display rules, Accessibility permission, pin main, limitations (PiP, false positives).

---

## Spec coverage checklist

| Spec requirement | Task |
|------------------|------|
| Rules B/A/C | 1, 9, 7 |
| Pin main | 1, 7 |
| Auto off default | 6 |
| Activation source | 2, 4 |
| Heuristic detection | 5 |
| AX optional | 8 |
| Menu auto toggle | 5 |
| Settings window | 7 |
| No private display APIs | — (by design) |
| Manual toggle preserved | 4, 5 |

## Manual test matrix (post 2b)

| # | Setup | Action | Expected |
|---|-------|--------|----------|
| 1 | Main + side, rule B, pin on, auto on | IINA fullscreen on main | Side shielded, main visible |
| 2 | Same | Exit fullscreen | Shields off |
| 3 | Auto on, manual on | Exit fullscreen | Shields stay |
| 4 | Chrome on each display | Fullscreen YouTube on side only | Main + side visible if pin on; or only side if pin off |
| 5 | Rule C watch=TV | Fullscreen on TV | Laptop shielded |
| 6 | Rule C | Fullscreen on main | No auto |
| 7 | AX off | Safari fullscreen | Heuristic works or enable AX |
| 8 | Auto off | VLC fullscreen | No shields |

---

## Execution handoff

Plan complete and saved to `design/plans/2026-05-25-auto-movie-mode.md`.

**Default:** `subagent-driven-development` — dispatch each plan task via Cursor `Task` (implementer, then spec reviewer, then code quality reviewer). Parent agent does not implement task code inline.

**Override:** Reply **inline** to use `executing-plans` instead (parent implements task-by-task in this session with checkpoints).

**Two execution options:**

1. **Subagent-Driven (default)** — fresh subagent per task via `Task`, review between tasks  
2. **Inline Execution** — only if user explicitly says **inline**
