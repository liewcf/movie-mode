# Decisions

## 2026-05-25

- Initialized and populated project memory from current repo evidence.
- Use black full-screen shield windows for version 1 instead of private display APIs or physical monitor sleep. Rationale: reliable and avoids brittle system-level behavior.
- Use an AppKit `NSStatusItem` rather than SwiftUI `MenuBarExtra` for the app shell. Rationale: left-click must toggle Movie Mode directly with one click.
- Keep the internal core module named `FocusMonitorCore` after renaming the public app to `MovieMode`. Rationale: preserves a focused app-identity rename without unnecessary internal churn.
