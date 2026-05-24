# Focus Monitor Design

## Goal

Build a simple macOS menu bar app for watching movies on the main display while visually turning off all other active displays.

Success means the user can toggle one menu bar control on and off:

- Off: no display shields are shown.
- On: every active non-main display is covered by a black full-screen window.
- The main display remains usable.
- The menu bar icon clearly reflects the current state.

## Scope

Version 1 uses the reliable black-screen approach. It does not physically sleep, power off, disable, mirror, or rearrange monitors. It avoids private macOS display APIs.

The app is menu-bar-only. There is no Dock icon, main window, settings screen, persistence beyond the current app session, or per-display configuration in version 1.

## Architecture

The app will be a SwiftPM macOS app using a SwiftUI app lifecycle and an AppKit `NSStatusItem` for one-click menu bar control.

Main parts:

- `FocusMonitorApp`: app entry point.
- `AppDelegate`: owns the status item, click handling, display-change observer, and app cleanup.
- `DisplayShieldController`: owns toggle state and coordinates shield windows.
- `DisplayShieldWindow`: borderless AppKit window shown on one non-main display.
- `DisplayProvider`: reads the current `NSScreen` list and identifies the main screen.

AppKit handles the menu bar status item and shield windows because direct one-click menu bar actions and precise display-sized borderless windows are simpler and more reliable there.

## Behavior

When the user left-clicks the menu bar icon to turn Movie Mode on, the controller reads `NSScreen.screens`, skips `NSScreen.main`, and creates one black shield window for each remaining screen. Each shield window is borderless, black, screen-sized, above normal app windows, and non-activating where possible.

When the user toggles Movie Mode off, the controller closes and releases all shield windows.

If the display configuration changes while Movie Mode is on, the controller rebuilds the shields so newly connected or disconnected displays are reflected.

If only one screen is available, toggling on leaves the main display untouched and shows a clear disabled/no-secondary-displays menu state.

## Menu Bar UI

The status item uses a compact template system symbol that follows macOS light/dark menu bar rendering:

- Off: inactive display-style icon.
- On: active/filled display-style icon.

Left-click toggles Movie Mode immediately. Right-click opens a small context menu containing:

- A short status line such as `Shielding 2 displays` or `No extra displays`.
- A fallback toggle item: `Start Movie Mode` or `Stop Movie Mode`.
- `Quit Focus Monitor`.

Visible menu labels stay short and scannable.

## Error Handling

Shield creation should be best-effort per display. If a shield cannot be created for one screen, the app still shields the others and reports the partial state in the menu.

The app should clean up all shield windows when toggled off or when quitting.

## Testing

Unit tests cover controller behavior with fake display snapshots:

- Toggling on creates shields for non-main displays only.
- Toggling off closes shields.
- A one-display setup creates no shields and reports `No extra displays`.
- Rebuilding while active replaces stale shields with the current display list.

Manual verification covers:

- Swift build succeeds.
- App bundle launches.
- The process is running.
- Menu bar toggle state changes.

Full multi-monitor visual verification may require running on a Mac with at least two active displays.
