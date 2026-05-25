# Work Changelog

## 2026-05-25

- Initialized project memory files.
- Populated project memory from verified local evidence: `Package.swift`, `Sources/`, `Tests/`, `script/build_and_run.sh`, and recent git history.
- Current app identity is `MovieMode`; the app bundle is staged at `dist/MovieMode.app` by `./script/build_and_run.sh`.
- Recorded the v1 product boundary: black shield windows on non-main displays, not physical monitor sleep or private display APIs.
- Added the selected Cinema Focus app icon source PNG at `Assets/MovieMode-AppIcon.png` and generated `Assets/MovieMode.icns`.
- Updated `script/build_and_run.sh` so rebuilt app bundles copy `MovieMode.icns` into `Contents/Resources` and declare `CFBundleIconFile`.
- Verified `swift test` passes 4 tests after cleaning stale SwiftPM build artifacts; verified `./script/build_and_run.sh --verify` rebuilds and launches `dist/MovieMode.app` with the icon resource present.
