import CoreGraphics
import XCTest
@testable import FocusMonitorCore

final class DisplayShieldControllerTests: XCTestCase {
    @MainActor
    func testActivatingMovieModeShieldsOnlyNonMainDisplays() {
        let provider = FakeDisplayProvider(displays: [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "side", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ])
        let shieldManager = FakeShieldManager()
        let controller = DisplayShieldController(displayProvider: provider, shieldManager: shieldManager)

        controller.toggleMovieMode()

        XCTAssertTrue(controller.isMovieModeActive)
        XCTAssertEqual(shieldManager.shownDisplayIDs, ["side"])
        XCTAssertEqual(controller.shieldedDisplayCount, 1)
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

        controller.toggleMovieMode()
        controller.toggleMovieMode()

        XCTAssertFalse(controller.isMovieModeActive)
        XCTAssertEqual(shieldManager.closedTokens, [
            DisplayShieldToken(displayID: "left"),
            DisplayShieldToken(displayID: "right")
        ])
        XCTAssertEqual(controller.shieldedDisplayCount, 0)
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

        controller.toggleMovieMode()

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

        controller.toggleMovieMode()
        provider.displays = [
            DisplaySnapshot(id: "main", frame: CGRect(x: 0, y: 0, width: 1920, height: 1080), isMain: true),
            DisplaySnapshot(id: "right", frame: CGRect(x: 1920, y: 0, width: 1920, height: 1080), isMain: false)
        ]
        controller.refreshDisplayConfiguration()

        XCTAssertEqual(shieldManager.closedTokens, [DisplayShieldToken(displayID: "left")])
        XCTAssertEqual(shieldManager.shownDisplayIDs, ["left", "right"])
        XCTAssertEqual(controller.shieldedDisplayCount, 1)
    }
}

private final class FakeDisplayProvider: DisplayProviding {
    var displays: [DisplaySnapshot]

    init(displays: [DisplaySnapshot]) {
        self.displays = displays
    }

    func currentDisplays() -> [DisplaySnapshot] {
        displays
    }
}

private final class FakeShieldManager: ShieldManaging {
    private(set) var shownDisplayIDs: [String] = []
    private(set) var closedTokens: [DisplayShieldToken] = []

    func showShield(on display: DisplaySnapshot) -> DisplayShieldToken? {
        shownDisplayIDs.append(display.id)
        return DisplayShieldToken(displayID: display.id)
    }

    func closeShield(_ token: DisplayShieldToken) {
        closedTokens.append(token)
    }
}
