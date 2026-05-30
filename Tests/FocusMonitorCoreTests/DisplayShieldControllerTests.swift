import CoreGraphics
import XCTest
@testable import FocusMonitorCore

final class DisplayShieldControllerTests: XCTestCase {
    @MainActor
    func testActivatingMovieModeShieldsOnlySpecifiedDisplays() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "side", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.activateMovieMode(shieldDisplayIDs: ["side"], activationSource: .manual)

        XCTAssertTrue(controller.isMovieModeActive)
        XCTAssertEqual(shieldManager.shownDisplayIDs, ["side"])
        XCTAssertEqual(controller.shieldedDisplayCount, 1)
        XCTAssertEqual(controller.activationSource, .manual)
        XCTAssertEqual(controller.statusText, "Shielding 1 display")
        XCTAssertEqual(controller.toggleTitle, "Stop Movie Mode")
        XCTAssertEqual(controller.menuBarSymbolName, "moon.fill")
    }

    @MainActor
    func testStoppingMovieModeClosesExistingShields() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), isMain: false),
            DisplaySnapshot(id: "right", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.activateMovieMode(shieldDisplayIDs: ["left", "right"], activationSource: .manual)
        controller.deactivateMovieMode()

        XCTAssertFalse(controller.isMovieModeActive)
        XCTAssertEqual(
            shieldManager.closedTokens.map(\.displayID).sorted(),
            ["left", "right"]
        )
        XCTAssertEqual(controller.shieldedDisplayCount, 0)
        XCTAssertNil(controller.activationSource)
        XCTAssertEqual(controller.statusText, "Movie Mode Off")
        XCTAssertEqual(controller.toggleTitle, "Start Movie Mode")
        XCTAssertEqual(controller.menuBarSymbolName, "moon")
    }

    @MainActor
    func testActivatingWithOnlyMainDisplayReportsNoExtraDisplays() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.activateMovieMode(shieldDisplayIDs: [], activationSource: .manual)

        XCTAssertTrue(controller.isMovieModeActive)
        XCTAssertEqual(shieldManager.shownDisplayIDs, [])
        XCTAssertEqual(controller.shieldedDisplayCount, 0)
        XCTAssertEqual(controller.statusText, "No extra displays")
    }

    @MainActor
    func testRefreshingDisplaysWhileActiveReplacesStaleShields() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "left", frame: CGRect(x: -1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.activateMovieMode(shieldDisplayIDs: ["left"], activationSource: .manual)
        provider.displays = [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "right", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ]
        controller.refreshDisplayConfiguration(shieldDisplayIDs: ["right"])

        XCTAssertEqual(shieldManager.closedTokens, [DisplayShieldToken(displayID: "left")])
        XCTAssertEqual(shieldManager.shownDisplayIDs, ["left", "right"])
        XCTAssertEqual(controller.shieldedDisplayCount, 1)
    }

    @MainActor
    func testRefreshingSameDisplayIDsWithChangedGeometryRecreatesShields() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "side", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.activateMovieMode(shieldDisplayIDs: ["side"], activationSource: .manual)
        provider.displays = [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "side", frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440), isMain: false)
        ]
        controller.refreshDisplayConfiguration(shieldDisplayIDs: ["side"])

        XCTAssertEqual(shieldManager.closedTokens, [DisplayShieldToken(displayID: "side")])
        XCTAssertEqual(shieldManager.shownDisplayIDs, ["side", "side"])
        XCTAssertEqual(controller.shieldedDisplayCount, 1)
    }
}
