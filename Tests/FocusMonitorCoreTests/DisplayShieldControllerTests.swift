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
