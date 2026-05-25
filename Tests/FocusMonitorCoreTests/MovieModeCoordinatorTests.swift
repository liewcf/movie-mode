import CoreGraphics
import XCTest
@testable import FocusMonitorCore

final class MovieModeCoordinatorTests: XCTestCase {
    @MainActor
    func testAutoEnterAppliesShieldsOnSideDisplay() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "side", frame: .zero, isMain: false),
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)
        var settings = MovieModeSettings.defaults
        settings.autoMovieModeEnabled = true
        let coordinator = MovieModeCoordinator(
            displayProvider: provider,
            shieldController: controller,
            settings: settings
        )

        coordinator.handleFullscreenEvent(
            FullscreenPlaybackEvent(kind: .entered, displayID: "main", bundleIdentifier: "org.videolan.vlc")
        )

        XCTAssertTrue(controller.isMovieModeActive)
        XCTAssertEqual(controller.activationSource, MovieModeActivationSource.auto)
        XCTAssertEqual(Set(shieldManager.shownDisplayIDs), Set(["side"]))
    }

    @MainActor
    func testAutoExitDeactivatesWhenAutoSourced() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "side", frame: .zero, isMain: false),
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)
        var settings = MovieModeSettings.defaults
        settings.autoMovieModeEnabled = true
        let coordinator = MovieModeCoordinator(
            displayProvider: provider,
            shieldController: controller,
            settings: settings
        )

        coordinator.handleFullscreenEvent(
            FullscreenPlaybackEvent(kind: .entered, displayID: "main", bundleIdentifier: "org.videolan.vlc")
        )
        coordinator.handleFullscreenEvent(
            FullscreenPlaybackEvent(kind: .exited, displayID: "main", bundleIdentifier: "org.videolan.vlc")
        )

        XCTAssertFalse(controller.isMovieModeActive)
        XCTAssertNil(controller.activationSource)
    }

    @MainActor
    func testPromoteToManualPreventsAutoExit() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "side", frame: .zero, isMain: false),
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)
        var settings = MovieModeSettings.defaults
        settings.autoMovieModeEnabled = true
        let coordinator = MovieModeCoordinator(
            displayProvider: provider,
            shieldController: controller,
            settings: settings
        )

        coordinator.handleFullscreenEvent(
            FullscreenPlaybackEvent(kind: .entered, displayID: "main", bundleIdentifier: "org.videolan.vlc")
        )
        coordinator.toggleManualMovieModePreservingAutoIfActive()

        coordinator.handleFullscreenEvent(
            FullscreenPlaybackEvent(kind: .exited, displayID: "main", bundleIdentifier: "org.videolan.vlc")
        )

        XCTAssertTrue(controller.isMovieModeActive)
        XCTAssertEqual(controller.activationSource, MovieModeActivationSource.manual)
    }

    @MainActor
    func testAutoDisabledIgnoresFullscreenEvents() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "side", frame: .zero, isMain: false),
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)
        let coordinator = MovieModeCoordinator(
            displayProvider: provider,
            shieldController: controller,
            settings: .defaults
        )

        coordinator.handleFullscreenEvent(
            FullscreenPlaybackEvent(kind: .entered, displayID: "main", bundleIdentifier: "org.videolan.vlc")
        )

        XCTAssertFalse(controller.isMovieModeActive)
    }
}
