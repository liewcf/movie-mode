public enum DisplayRule: String, Codable, CaseIterable, Sendable {
    case playing
    case main
    case watch
}

public struct DisplayVisibilityPolicy: Equatable, Sendable {
    public var rule: DisplayRule
    public var pinMainDisplay: Bool
    public var watchDisplayID: String?

    public init(rule: DisplayRule, pinMainDisplay: Bool, watchDisplayID: String?) {
        self.rule = rule
        self.pinMainDisplay = pinMainDisplay
        self.watchDisplayID = watchDisplayID
    }

    public func visibleDisplayIDs(displays: [DisplaySnapshot], playingDisplayID: String?) -> Set<String> {
        var visible = Set<String>()

        switch rule {
        case .playing:
            if let playingDisplayID {
                visible.insert(playingDisplayID)
            }
        case .main:
            if let mainID = displays.first(where: \.isMain)?.id {
                visible.insert(mainID)
            }
        case .watch:
            if let watchDisplayID {
                visible.insert(watchDisplayID)
            }
        }

        if pinMainDisplay, let mainID = displays.first(where: \.isMain)?.id {
            visible.insert(mainID)
        }

        return visible
    }

    public func shieldDisplayIDs(displays: [DisplaySnapshot], playingDisplayID: String?) -> Set<String> {
        let allIDs = Set(displays.map(\.id))
        return allIDs.subtracting(visibleDisplayIDs(displays: displays, playingDisplayID: playingDisplayID))
    }

    public func shouldAutoActivate(displays: [DisplaySnapshot], playingDisplayID: String?) -> Bool {
        guard let playingDisplayID else {
            return false
        }

        switch rule {
        case .playing:
            return true
        case .main:
            return displays.first(where: \.isMain)?.id == playingDisplayID
        case .watch:
            return watchDisplayID == playingDisplayID
        }
    }

    /// Manual toggle when no fullscreen playing display is known: shield all non-main displays (legacy v1 behavior).
    public func manualShieldDisplayIDs(displays: [DisplaySnapshot]) -> Set<String> {
        if rule == .playing, pinMainDisplay == false {
            return Set(displays.filter { !$0.isMain }.map(\.id))
        }

        return shieldDisplayIDs(displays: displays, playingDisplayID: nil)
    }
}
