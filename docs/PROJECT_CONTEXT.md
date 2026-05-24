# Project Context

## Overview

- Project purpose: macOS menu bar app for movie watching on the main display by visually blacking out all active non-main displays.
- Primary users: Local Mac users with multiple displays who want a quick movie-mode toggle.
- Current status: SwiftPM app implemented on branch `feature/movie-mode-shields`; current app identity is `MovieMode`.

## Architecture

- SwiftPM package named `MovieMode`, with macOS 13 minimum target.
- Executable target: `MovieMode`.
- Internal library target: `FocusMonitorCore`, containing `DisplaySnapshot`, `DisplayShieldController`, and testable display/shield protocols.
- App target uses the SwiftUI app lifecycle plus AppKit for menu-bar and window behavior.
- `MovieModeApp` installs an accessory app delegate that owns an `NSStatusItem`; left-click toggles Movie Mode, right-click opens a context menu.
- `AppKitDisplayProvider` adapts `NSScreen` to core display snapshots.
- `AppKitShieldManager` creates borderless black `NSWindow` shields at screen-saver level for each non-main display.

## Development Workflow

- Package manager: SwiftPM.
- Build command: `swift build`.
- Test command: `swift test`.
- Run command: `./script/build_and_run.sh`.
- Launch verification command: `./script/build_and_run.sh --verify`.
- Built app bundle: `dist/MovieMode.app`.
- Process name: `MovieMode`.

## Constraints

- Version 1 uses black shield windows only. It does not physically sleep, power off, disable, mirror, or rearrange displays.
- Avoid private macOS display APIs unless the user explicitly asks for an experimental hardware-sleep mode.
- Do not surprise-toggle Movie Mode during verification if it would black out the user's active monitors; report when manual multi-monitor visual verification is still needed.
- The run script intentionally kills both `MovieMode` and legacy `FocusMonitor` processes before relaunching.
