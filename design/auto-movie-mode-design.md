# Auto Movie Mode — Design Spec

**Status:** Approved (2026-05-25)
**Author:** Brainstorming session (user + agent)

## Summary

Extend MovieMode with optional **auto activation** when eligible apps enter fullscreen. Shield targets are computed from a user-chosen **display rule** (playing / main / watch) and an optional **pin Main Display** safety checkbox. Detection uses **window heuristics** by default and **optional Accessibility** for better browser coverage.

Manual menu-bar toggle remains unchanged in spirit; auto and manual interactions are coordinated via an **activation source** so exiting fullscreen does not fight user intent.

## Goals

- VLC / IINA fullscreen on primary display → secondary displays visually blacked out automatically.
- YouTube (and similar) in browsers → same when truly fullscreen.
- Two Chrome windows on two displays → only the display with the fullscreen window stays unshielded (rule B); optional pin keeps Main visible too.
- Future TV-as-player → user sets **Watch display** rule without rewriting core logic.
- Per-user configuration without an overwhelming settings matrix.

## Non-goals (this spec)

- Monitor sleep, power off, DDC, or private display APIs.
- PiP / windowed playback as triggers (fullscreen only).
- Cloud sync of settings or analytics.
- Preset bundles (“Desk”, “Theater”) — optional later.

## Defaults (new installs)

| Setting | Default |
|---------|---------|
| Auto movie mode | **Off** |
| Display rule | **Playing display (B)** |
| Also keep Main Display visible | **On** |
| Accessibility detection | **Off** (heuristics only until user enables) |

## Display rules

Let `D` = all active displays, `playing` = display hosting eligible fullscreen, `main` = macOS main display, `watch` = user-selected display (rule C only).

**Visible set** `V`:

| Rule | Base visible set `V` |
|------|----------------------|
| **Playing (B)** | `{ playing }` |
| **Main (A)** | `{ main }` |
| **Watch (C)** | `{ watch }` |

**Pin Main checkbox:** `V ← V ∪ { main }` when enabled.

**Shield set:** `shield = D − V` (empty if single display or all visible).

### Auto trigger gating

| Rule | Auto activates when |
|------|---------------------|
| B | Eligible fullscreen on any display |
| A | Eligible fullscreen on **main** only (recommended for rule A to avoid shielding the display that is playing on a secondary monitor) |
| C | Eligible fullscreen on **watch** display only |

Manual activation: user chooses shields via current rule + pin at toggle time (no fullscreen required).

## Activation source

```swift
enum MovieModeActivationSource {
    case manual
    case auto
}
```

| Event | Behavior |
|-------|----------|
| Auto detect fullscreen | `activate(source: .auto)` + apply shields |
| Fullscreen ends | `deactivate()` **only if** `source == .auto` |
| User left-clicks toggle ON | `activate(source: .manual)` |
| User left-clicks toggle OFF | `deactivate()` regardless of source |
| User toggles ON while auto active | Upgrade to `.manual` (fullscreen end will not auto-off) |
| Display topology change | Recompute `shield` for active mode |

## Detection

### Layer 1 — Heuristics (always available)

- Inputs: `CGWindowListCopyWindowInfo`, display snapshots from `DisplayProviding`.
- Candidate windows: owner bundle ID in allowlist (VLC, IINA, browsers).
- Fullscreen heuristic: on-screen, bounds approximately equal to target screen frame (configurable tolerance), layer/subtree hints where useful.
- Map window bounds → display ID (largest intersection area with screen frame).

### Layer 2 — Accessibility (optional)

- Gated by user setting + `AXIsProcessTrusted()`.
- Query fullscreen attribute on windows for frontmost / allowlisted apps.
- Used when enabled; falls back to heuristics if denied or inconclusive.

### Allowlist (phase 2b)

Default bundle IDs (configurable):

- `org.videolan.vlc`
- `com.colliderli.iina`
- `com.apple.Safari`, `com.google.Chrome`, `com.brave.Browser`, `company.thebrowser.Browser` (Arc), Firefox family, etc.

Phase 2a: coarse **“browsers”** bucket + native players hardcoded.

## UI/UX

### Menu bar

- **Left-click:** manual toggle (unchanged).
- **Right-click:** status, manual toggle, **Auto Movie Mode** on/off, **Settings…**, Quit.

### Settings window

1. Auto movie mode (toggle)
2. Display rule: Playing / Main / Watch + display picker when Watch
3. Also keep Main Display visible (checkbox)
4. Use Accessibility for detection (toggle + explanation + open System Settings)
5. (2b) App allowlist editor

## Architecture

### FocusMonitorCore (testable)

| Unit | Responsibility |
|------|----------------|
| `DisplayVisibilityPolicy` | Rule + pinMain + watchDisplayID → compute `visibleIDs` / `shieldIDs` |
| `DisplayShieldController` | Apply shields for explicit `shieldIDs`; manual toggle API |
| `MovieModeCoordinator` | Wires policy + controller + activation source |
| `FullscreenPlaybackDetecting` | Protocol: stream or callback `FullscreenEvent` (entered/exited, displayID, bundleID) |
| `MovieModeSettings` | Value types + defaults (storage protocol for tests) |

### MovieMode (AppKit)

| Unit | Responsibility |
|------|----------------|
| `CGWindowFullscreenDetector` | Heuristic implementation |
| `AXFullscreenDetector` | AX implementation |
| `CompositeFullscreenDetector` | AX when enabled, else heuristics |
| `UserDefaultsMovieModeSettingsStore` | Persistence |
| `MovieModeSettingsView` | SwiftUI settings UI |
| `AppDelegate` | Start/stop detector, menu items, coordinator lifecycle |

## Edge cases

- **No secondary displays:** Auto may run; `shieldedDisplayCount == 0`, status “No extra displays”.
- **Heuristic false positive:** User disables auto or tightens allowlist (2b).
- **Heuristic false negative:** User enables Accessibility.
- **Main pinned + playing on main:** `V = { main }` — no redundant shields.
- **Rule C + fullscreen on non-watch:** No auto activation.

## Phased delivery

| Phase | Deliverables |
|-------|----------------|
| **2a** | Policy engine, coordinator, heuristic detector, auto toggle in menu, minimal settings (auto + rule B only + pin main), tests |
| **2b** | Full rules A/C, watch picker, Settings window, AX detector, menu “Settings…” |
| **2c** | App allowlist UI, trigger tuning, README/FAQ |

## Testing strategy

- **FocusMonitorCore:** Policy tests for all rule × pin × display topology combos; coordinator auto/manual lifecycle; fake detector.
- **MovieMode:** Integration smoke via `swift test`; manual matrix documented in plan.

## Privacy

- No network.
- Accessibility: optional, explained in Settings; only used for window fullscreen state when enabled.
- Window list: local CGWindow API.

## Open questions (resolved)

- Default rule: **B** with **pin Main on**.
- Auto default: **off**.
- All three rules ship in **2b**; **2a** may ship B-only UI with policy code ready for A/C.
