# Agent Instructions

## Project Memory Requirement

Keep these repo-level memory files accurate and concise when work changes project context:

- `docs/PROJECT_CONTEXT.md` for stable project facts, architecture, workflows, and constraints.
- `docs/DECISIONS.md` for dated technical or product decisions and rationale.
- `docs/TASKS.md` for current tasks, blockers, and next actions.
- `docs/CHANGELOG_WORK.md` for dated notes on changed files, behavior, docs, config, dependencies, tooling, tests, and verification.

Do not store secrets, credentials, API keys, private tokens, database dumps, or sensitive personal data in project memory.

## Project-Specific Notes

- MovieMode is a SwiftPM macOS menu-bar app. Keep the public app identity, executable target, bundle, and process name as `MovieMode`.
- `FocusMonitorCore` is the internal testable core module; do not rename it unless the app architecture is intentionally being cleaned up.
- Use `swift test` for tests, `swift build` for compilation, and `./script/build_and_run.sh --verify` to build and launch `dist/MovieMode.app`.
- The app uses an AppKit `NSStatusItem` for true one-click left-click toggling. Right-click opens status, toggle, and quit menu items.
- Version 1 visually blacks out non-main displays with borderless black shield windows. Do not add private display APIs or actual monitor sleep/power-off behavior unless explicitly requested.
- Optional auto movie mode detects eligible fullscreen playback (heuristics plus optional Accessibility) and shields displays per user display rules in Settings.
