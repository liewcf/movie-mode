# MovieMode

<p align="center">
  <img src="Assets/MovieMode-AppIcon.png" alt="MovieMode app icon" width="128" height="128">
</p>

<p align="center">
  A one-click movie mode for multi-display Macs.
</p>

MovieMode is a small macOS menu bar app that helps you watch on your main display while visually blacking out your other active displays.

> MovieMode creates black shield windows on non-main displays. It does not sleep, power off, disable, mirror, or rearrange monitors.

## What It Does

- Toggles movie mode from the macOS menu bar.
- Keeps the main display visible.
- Covers every active non-main display with a borderless black window.
- Restores the extra displays when movie mode is turned off.

## Install

### Download From Releases

For normal use, download the latest `MovieMode.app` from [GitHub Releases](https://github.com/liewcf/movie-mode/releases).

Early builds may be unsigned. If macOS blocks the app the first time you open it, right-click `MovieMode.app`, choose **Open**, then confirm that you want to open it.

### Build From Source

Requirements:

- macOS 13 or later
- Swift 5.9 or later

```sh
git clone https://github.com/liewcf/movie-mode.git
cd movie-mode
./script/build_and_run.sh
```

The script builds `dist/MovieMode.app`, installs the app icon, launches MovieMode as a menu bar accessory, and replaces any existing `MovieMode` or legacy `FocusMonitor` process.

## Use MovieMode

- Left-click the menu bar icon to turn movie mode on or off.
- Right-click the menu bar icon to see the current status, toggle movie mode, or quit the app.

When movie mode is on, the menu bar icon changes and all active non-main displays are covered by black shield windows.

## Privacy And Safety

MovieMode runs locally on your Mac. It has no accounts, no analytics, and no network service.

Version 1 only creates visual shield windows. It does not use private display APIs or change monitor power state.

## Build And Test

```sh
swift build
swift test
```

For a quick launch check:

```sh
./script/build_and_run.sh --verify
```

## FAQ

### Does MovieMode turn off my monitors?

No. MovieMode visually blacks out extra displays with black windows. Your monitors remain on.

### Which display stays visible?

The main macOS display stays visible. MovieMode covers the other active displays.

### Why does macOS warn me when opening the app?

Early public builds may be unsigned. If you trust the build, right-click the app, choose **Open**, and confirm the prompt.

### How do I quit MovieMode?

Right-click the menu bar icon and choose **Quit MovieMode**.

## Development

MovieMode is a SwiftPM macOS app.

- Public app identity, executable target, bundle, and process name: `MovieMode`
- Internal testable core module: `FocusMonitorCore`
- Built app bundle: `dist/MovieMode.app`
