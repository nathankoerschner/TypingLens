import AppKit

final class ChromeLessWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseUp,
           event.clickCount >= 2,
           shouldHandleTitlebarDoubleClick(at: event.locationInWindow) {
            performPreferredTitlebarDoubleClickAction()
            return
        }

        super.sendEvent(event)
    }

    private func shouldHandleTitlebarDoubleClick(at point: NSPoint) -> Bool {
        guard titlebarAppearsTransparent,
              styleMask.contains(.fullSizeContentView) else {
            return false
        }

        let titlebarHeight = max(0, frame.height - contentLayoutRect.height)
        let titlebarRect = NSRect(
            x: 0,
            y: frame.height - titlebarHeight,
            width: frame.width,
            height: titlebarHeight
        )

        guard titlebarRect.contains(point) else { return false }

        for buttonType in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            if let button = standardWindowButton(buttonType) {
                let buttonFrame = button.convert(button.bounds, to: nil)
                if buttonFrame.contains(point) {
                    return false
                }
            }
        }

        return true
    }

    private func performPreferredTitlebarDoubleClickAction() {
        let defaults = UserDefaults.standard

        if let action = defaults.string(forKey: "AppleActionOnDoubleClick") {
            switch action {
            case "Minimize":
                performMiniaturize(nil)
            case "Maximize":
                performZoom(nil)
            default:
                break
            }
            return
        }

        if defaults.bool(forKey: "AppleMiniaturizeOnDoubleClick") {
            performMiniaturize(nil)
        } else {
            performZoom(nil)
        }
    }
}
