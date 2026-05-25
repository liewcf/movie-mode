import FocusMonitorCore

@MainActor
final class CompositeFullscreenDetector: FullscreenPlaybackDetecting {
    var onEvent: ((FullscreenPlaybackEvent) -> Void)? {
        didSet {
            cgDetector.onEvent = onEvent
            axDetector.onEvent = onEvent
        }
    }

    private let settingsStore: MovieModeSettingsStore
    private let cgDetector: CGWindowFullscreenDetector
    private let axDetector: AXFullscreenDetector

    init(settingsStore: MovieModeSettingsStore) {
        self.settingsStore = settingsStore
        self.cgDetector = CGWindowFullscreenDetector(settingsStore: settingsStore)
        self.axDetector = AXFullscreenDetector(settingsStore: settingsStore)
    }

    func start() {
        if settingsStore.settings.useAccessibilityDetection {
            cgDetector.stop()
            axDetector.start()
        } else {
            axDetector.stop()
            cgDetector.start()
        }
    }

    func stop() {
        cgDetector.stop()
        axDetector.stop()
    }

    func restartIfNeeded() {
        stop()
        start()
    }
}
