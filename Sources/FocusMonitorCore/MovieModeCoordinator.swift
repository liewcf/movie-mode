import Combine

@MainActor
public final class MovieModeCoordinator: ObservableObject {
    public let shieldController: DisplayShieldController

    private let displayProvider: DisplayProviding
    private var settings: MovieModeSettings
    private var currentPlayingDisplayID: String?

    public init(
        displayProvider: DisplayProviding,
        shieldController: DisplayShieldController,
        settings: MovieModeSettings = .defaults
    ) {
        self.displayProvider = displayProvider
        self.shieldController = shieldController
        self.settings = settings
    }

    public func updateSettings(_ settings: MovieModeSettings) {
        self.settings = settings

        guard shieldController.isMovieModeActive else {
            return
        }

        refreshActiveShields()
    }

    public func handleFullscreenEvent(_ event: FullscreenPlaybackEvent) {
        switch event.kind {
        case .entered:
            currentPlayingDisplayID = event.displayID
            guard settings.autoMovieModeEnabled else {
                return
            }

            let displays = displayProvider.currentDisplays()
            let policy = settings.visibilityPolicy

            guard policy.shouldAutoActivate(displays: displays, playingDisplayID: event.displayID) else {
                return
            }

            let shieldIDs = policy.shieldDisplayIDs(displays: displays, playingDisplayID: event.displayID)

            if shieldController.isMovieModeActive, shieldController.activationSource == .auto {
                shieldController.refreshDisplayConfiguration(shieldDisplayIDs: shieldIDs)
            } else {
                shieldController.activateMovieMode(shieldDisplayIDs: shieldIDs, activationSource: .auto)
            }

        case .exited:
            currentPlayingDisplayID = nil

            guard shieldController.activationSource == .auto else {
                return
            }

            shieldController.deactivateMovieMode()
        }
    }

    public func toggleManualMovieMode() {
        if shieldController.isMovieModeActive {
            shieldController.deactivateMovieMode()
            return
        }

        let displays = displayProvider.currentDisplays()
        let policy = settings.visibilityPolicy
        let shieldIDs = policy.manualShieldDisplayIDs(displays: displays)
        shieldController.activateMovieMode(shieldDisplayIDs: shieldIDs, activationSource: .manual)
    }

    public func toggleManualMovieModePreservingAutoIfActive() {
        if shieldController.isMovieModeActive {
            if shieldController.activationSource == .auto {
                shieldController.promoteToManualActivation()
            } else {
                shieldController.deactivateMovieMode()
            }
            return
        }

        toggleManualMovieMode()
    }

    public func refreshActiveShields() {
        let displays = displayProvider.currentDisplays()
        let policy = settings.visibilityPolicy

        let shieldIDs: Set<String>
        if let playingDisplayID = currentPlayingDisplayID {
            shieldIDs = policy.shieldDisplayIDs(displays: displays, playingDisplayID: playingDisplayID)
        } else {
            shieldIDs = policy.manualShieldDisplayIDs(displays: displays)
        }

        shieldController.refreshDisplayConfiguration(shieldDisplayIDs: shieldIDs)
    }

    public func handleDisplayConfigurationChanged() {
        guard shieldController.isMovieModeActive else {
            return
        }

        refreshActiveShields()
    }
}
