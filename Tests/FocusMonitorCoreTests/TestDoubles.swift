import CoreGraphics
@testable import FocusMonitorCore

final class FakeDisplayProvider: DisplayProviding {
    var displays: [DisplaySnapshot]

    init(displays: [DisplaySnapshot]) {
        self.displays = displays
    }

    func currentDisplays() -> [DisplaySnapshot] {
        displays
    }
}

final class FakeShieldManager: ShieldManaging {
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
