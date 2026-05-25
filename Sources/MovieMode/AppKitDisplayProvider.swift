import AppKit
import FocusMonitorCore

struct AppKitDisplayProvider: DisplayProviding {
    func currentDisplays() -> [DisplaySnapshot] {
        let screens = NSScreen.screens
        let mainScreenID = NSScreen.main?.movieModeScreenID ?? screens.first?.movieModeScreenID

        return screens.map { screen in
            DisplaySnapshot(
                id: screen.movieModeScreenID,
                frame: screen.frame,
                isMain: screen.movieModeScreenID == mainScreenID
            )
        }
    }
}
