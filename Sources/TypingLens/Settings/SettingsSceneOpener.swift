import AppKit

protocol ApplicationOpening {
    func activate(ignoringOtherApps flag: Bool)
    @discardableResult
    func sendAction(_ action: Selector, to target: Any?, from sender: Any?) -> Bool
}

extension NSApplication: ApplicationOpening {}

protocol SettingsSceneOpening {
    func openSettingsScene()
}

protocol SettingsWindowShowing {
    func showSettingsWindow()
}

final class SwiftUISettingsSceneOpener: SettingsSceneOpening {
    private let application: ApplicationOpening
    private let settingsWindow: SettingsWindowShowing

    init(
        application: ApplicationOpening = NSApplication.shared,
        settingsWindow: SettingsWindowShowing
    ) {
        self.application = application
        self.settingsWindow = settingsWindow
    }

    func openSettingsScene() {
        application.activate(ignoringOtherApps: true)
        settingsWindow.showSettingsWindow()
    }
}
