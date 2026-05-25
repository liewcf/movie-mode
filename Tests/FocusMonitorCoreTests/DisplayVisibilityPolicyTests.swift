import CoreGraphics
import XCTest
@testable import FocusMonitorCore

final class DisplayVisibilityPolicyTests: XCTestCase {
    func testPlayingRuleShieldsNonPlayingDisplays() {
        let displays = [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "side", frame: .zero, isMain: false),
        ]
        let policy = DisplayVisibilityPolicy(rule: .playing, pinMainDisplay: false, watchDisplayID: nil)

        XCTAssertEqual(policy.visibleDisplayIDs(displays: displays, playingDisplayID: "main"), Set(["main"]))
        XCTAssertEqual(policy.shieldDisplayIDs(displays: displays, playingDisplayID: "main"), Set(["side"]))
    }

    func testPlayingRuleWithPinMainKeepsMainWhenPlayingOnSide() {
        let displays = [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "tv", frame: .zero, isMain: false),
        ]
        let policy = DisplayVisibilityPolicy(rule: .playing, pinMainDisplay: true, watchDisplayID: nil)

        XCTAssertEqual(policy.visibleDisplayIDs(displays: displays, playingDisplayID: "tv"), Set(["main", "tv"]))
        XCTAssertEqual(policy.shieldDisplayIDs(displays: displays, playingDisplayID: "tv"), Set<String>())
    }

    func testMainRuleVisibleSetIsMainOnlyWithoutPin() {
        let displays = [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "side", frame: .zero, isMain: false),
        ]
        let policy = DisplayVisibilityPolicy(rule: .main, pinMainDisplay: false, watchDisplayID: nil)

        XCTAssertEqual(policy.visibleDisplayIDs(displays: displays, playingDisplayID: "side"), Set(["main"]))
        XCTAssertEqual(policy.shieldDisplayIDs(displays: displays, playingDisplayID: "side"), Set(["side"]))
    }

    func testWatchRuleOnlyTriggersWhenPlayingOnWatch() {
        let displays = [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "tv", frame: .zero, isMain: false),
        ]
        let policy = DisplayVisibilityPolicy(rule: .watch, pinMainDisplay: false, watchDisplayID: "tv")

        XCTAssertTrue(policy.shouldAutoActivate(displays: displays, playingDisplayID: "tv"))
        XCTAssertFalse(policy.shouldAutoActivate(displays: displays, playingDisplayID: "main"))
    }

    func testMainRuleAutoActivateOnlyOnMainDisplay() {
        let displays = [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "tv", frame: .zero, isMain: false),
        ]
        let policy = DisplayVisibilityPolicy(rule: .main, pinMainDisplay: false, watchDisplayID: nil)

        XCTAssertTrue(policy.shouldAutoActivate(displays: displays, playingDisplayID: "main"))
        XCTAssertFalse(policy.shouldAutoActivate(displays: displays, playingDisplayID: "tv"))
    }

    func testManualLegacyShieldsNonMainWhenPlayingRuleWithoutPinAndNoPlayingDisplay() {
        let displays = [
            DisplaySnapshot(id: "main", frame: .zero, isMain: true),
            DisplaySnapshot(id: "side", frame: .zero, isMain: false),
        ]
        let policy = DisplayVisibilityPolicy(rule: .playing, pinMainDisplay: false, watchDisplayID: nil)

        XCTAssertEqual(policy.manualShieldDisplayIDs(displays: displays), Set(["side"]))
    }
}
