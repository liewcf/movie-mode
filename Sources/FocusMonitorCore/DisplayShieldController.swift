import Combine

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
        closeActiveShields()

        let displaysByID = Dictionary(
            uniqueKeysWithValues: displayProvider.currentDisplays().map { ($0.id, $0) }
        )

        activeTokens = shieldDisplayIDs.compactMap { displayID in
            guard let display = displaysByID[displayID] else {
                return nil
            }

            return shieldManager.showShield(on: display)
        }
        shieldedDisplayCount = activeTokens.count
    }

    private func closeActiveShields() {
        activeTokens.forEach { shieldManager.closeShield($0) }
        activeTokens.removeAll()
        shieldedDisplayCount = 0
    }
}
