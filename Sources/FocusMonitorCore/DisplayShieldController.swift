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

    public func toggleMovieMode() {
        if isMovieModeActive {
            deactivateMovieMode()
        } else {
            activateMovieMode()
        }
    }

    public func refreshDisplayConfiguration() {
        guard isMovieModeActive else {
            return
        }

        closeActiveShields()
        createShieldsForCurrentDisplays()
    }

    public func deactivateMovieMode() {
        closeActiveShields()
        isMovieModeActive = false
    }

    private func activateMovieMode() {
        isMovieModeActive = true
        createShieldsForCurrentDisplays()
    }

    private func createShieldsForCurrentDisplays() {
        activeTokens = displayProvider.currentDisplays()
            .filter { !$0.isMain }
            .compactMap { shieldManager.showShield(on: $0) }
        shieldedDisplayCount = activeTokens.count
    }

    private func closeActiveShields() {
        activeTokens.forEach { shieldManager.closeShield($0) }
        activeTokens.removeAll()
        shieldedDisplayCount = 0
    }
}
