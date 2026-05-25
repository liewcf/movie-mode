# Tasks

## Recommended Next Action

- Manually left-click the `MovieMode` menu bar icon on the active multi-monitor setup to confirm non-main displays black out, then click again to restore.

## Current

- [ ] Manual multi-monitor visual verification of shield-window behavior.

## Verification

- Repo evidence checked on 2026-05-25: `Package.swift`, `Sources/`, `Tests/`, `script/build_and_run.sh`, and recent git history.
- Latest rename verification before memory setup: `swift test` passed 4 tests, `swift build` passed, `./script/build_and_run.sh --verify` launched `dist/MovieMode.app`, and `pgrep -x MovieMode` found the running app.
- App icon packaging verified on 2026-05-25: `./script/build_and_run.sh --verify` rebuilt and launched `dist/MovieMode.app`; `Contents/Resources/MovieMode.icns` exists and `Info.plist` declares `CFBundleIconFile`.
- Actual visual shielding still needs a deliberate manual click because toggling Movie Mode blacks out other displays.

## Blockers

- None recorded. Manual visual verification remains the only open check.

## Done

- [x] Project memory initialized and populated from current repo evidence.
- [x] MovieMode app implementation, run script, and app rename are present on branch `feature/movie-mode-shields`.
- [x] Cinema Focus app icon selected and wired into the generated app bundle.
