import Combine
import CoreGraphics

@MainActor
public protocol DisplayProviding {
    func currentDisplays() -> [DisplaySnapshot]
}

@MainActor
public protocol ShieldManaging {
    func showShield(on display: DisplaySnapshot) -> DisplayShieldToken?
    func closeShield(_ token: DisplayShieldToken)
}

public struct DisplayShieldToken: Equatable {
    public let displayID: String

    public init(displayID: String) {
        self.displayID = displayID
    }
}

@MainActor
public final class DisplayShieldController: ObservableObject {
    @Published public private(set) var isMovieModeActive = false
    @Published public private(set) var shieldedDisplayCount = 0
    @Published public private(set) var activationSource: MovieModeActivationSource?

    private let displayProvider: DisplayProviding
    private let shieldManager: ShieldManaging
    private var activeTokens: [DisplayShieldToken] = []
    private var appliedDisplayFrames: [String: CGRect] = [:]

    public init(displayProvider: DisplayProviding, shieldManager: ShieldManaging) {
        self.displayProvider = displayProvider
        self.shieldManager = shieldManager
    }

    public var toggleTitle: String {
        isMovieModeActive ? "Stop Movie Mode" : "Start Movie Mode"
    }

    public var menuBarSymbolName: String {
        isMovieModeActive ? "moon.fill" : "moon"
    }

    public var statusText: String {
        if !isMovieModeActive {
            return "Movie Mode Off"
        }

        if shieldedDisplayCount == 0 {
            return "No extra displays"
        }

        if shieldedDisplayCount == 1 {
            return "Shielding 1 display"
        }

        return "Shielding \(shieldedDisplayCount) displays"
    }

    public func toggleMovieMode(shieldDisplayIDs: Set<String>, activationSource: MovieModeActivationSource) {
        if isMovieModeActive {
            deactivateMovieMode()
        } else {
            activateMovieMode(shieldDisplayIDs: shieldDisplayIDs, activationSource: activationSource)
        }
    }

    public func activateMovieMode(shieldDisplayIDs: Set<String>, activationSource: MovieModeActivationSource) {
        isMovieModeActive = true
        self.activationSource = activationSource
        applyShields(shieldDisplayIDs: shieldDisplayIDs)
    }

    public func deactivateMovieMode() {
        closeActiveShields()
        isMovieModeActive = false
        activationSource = nil
    }

    public func promoteToManualActivation() {
        guard isMovieModeActive else {
            return
        }

        activationSource = .manual
    }

    public func refreshDisplayConfiguration(shieldDisplayIDs: Set<String>) {
        guard isMovieModeActive else {
            return
        }

        applyShields(shieldDisplayIDs: shieldDisplayIDs)
    }

    private func applyShields(shieldDisplayIDs: Set<String>) {
        let displaysByID = Dictionary(
            uniqueKeysWithValues: displayProvider.currentDisplays().map { ($0.id, $0) }
        )
        let currentIDs = Set(activeTokens.map(\.displayID))

        if currentIDs == shieldDisplayIDs {
            let geometryMatches = shieldDisplayIDs.allSatisfy { displayID in
                guard let display = displaysByID[displayID], let applied = appliedDisplayFrames[displayID] else {
                    return false
                }

                return display.frame == applied
            }

            if geometryMatches {
                shieldedDisplayCount = activeTokens.count
                return
            }

            recreateShields(for: shieldDisplayIDs, displaysByID: displaysByID)
            shieldedDisplayCount = activeTokens.count
            return
        }

        let toRemove = currentIDs.subtracting(shieldDisplayIDs)
        for token in activeTokens where toRemove.contains(token.displayID) {
            shieldManager.closeShield(token)
            appliedDisplayFrames.removeValue(forKey: token.displayID)
        }
        activeTokens.removeAll { toRemove.contains($0.displayID) }

        let existingIDs = Set(activeTokens.map(\.displayID))
        for displayID in shieldDisplayIDs where !existingIDs.contains(displayID) {
            guard let display = displaysByID[displayID] else {
                continue
            }

            if let token = shieldManager.showShield(on: display) {
                activeTokens.append(token)
                appliedDisplayFrames[displayID] = display.frame
            }
        }

        shieldedDisplayCount = activeTokens.count
    }

    private func recreateShields(for shieldDisplayIDs: Set<String>, displaysByID: [String: DisplaySnapshot]) {
        for token in activeTokens {
            shieldManager.closeShield(token)
        }
        activeTokens.removeAll()
        appliedDisplayFrames.removeAll()

        for displayID in shieldDisplayIDs {
            guard let display = displaysByID[displayID] else {
                continue
            }

            if let token = shieldManager.showShield(on: display) {
                activeTokens.append(token)
                appliedDisplayFrames[displayID] = display.frame
            }
        }
    }

    private func closeActiveShields() {
        activeTokens.forEach { shieldManager.closeShield($0) }
        activeTokens.removeAll()
        appliedDisplayFrames.removeAll()
        shieldedDisplayCount = 0
    }
}
