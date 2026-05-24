import AppKit
import FocusMonitorCore

struct AppKitDisplayProvider: DisplayProviding {
    func currentDisplays() -> [DisplaySnapshot] {
        let screens = NSScreen.screens
        let mainScreenID = NSScreen.main?.focusMonitorScreenID ?? screens.first?.focusMonitorScreenID

        return screens.map { screen in
            DisplaySnapshot(
                id: screen.focusMonitorScreenID,
                frame: screen.frame,
                isMain: screen.focusMonitorScreenID == mainScreenID
            )
        }
    }
}

private extension NSScreen {
    var focusMonitorScreenID: String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        if let number = deviceDescription[key] as? NSNumber {
            return number.stringValue
        }

        return "\(frame.origin.x),\(frame.origin.y),\(frame.width),\(frame.height)"
    }
}
