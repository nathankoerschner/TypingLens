import AppKit
import SwiftUI

protocol MenuBarStatusItemPresenting: AnyObject {
    var button: NSStatusBarButton? { get }
    var menu: NSMenu? { get set }
}

extension NSStatusItem: MenuBarStatusItemPresenting {}

struct MenuBarState: Equatable {
    let statusTitle: String
    let enableLoggingEnabled: Bool
    let disableLoggingEnabled: Bool
    let showOpenSystemSettings: Bool
    let errorMessage: String?

    init(
        statusTitle: String,
        enableLoggingEnabled: Bool,
        disableLoggingEnabled: Bool,
        showOpenSystemSettings: Bool = false,
        errorMessage: String? = nil
    ) {
        self.statusTitle = statusTitle
        self.enableLoggingEnabled = enableLoggingEnabled
        self.disableLoggingEnabled = disableLoggingEnabled
        self.showOpenSystemSettings = showOpenSystemSettings
        self.errorMessage = errorMessage
    }

    init(appState: AppState) {
        switch appState.loggingStatus {
        case .disabled:
            statusTitle = "Status: Disabled"
        case .enabling:
            statusTitle = "Status: Enabling"
        case .enabled:
            statusTitle = "Status: Enabled"
        case let .blocked(reason):
            statusTitle = "Status: Blocked – \(reason)"
        case let .error(message):
            statusTitle = "Status: Error – \(message)"
        }

        enableLoggingEnabled = !appState.isLoggingEnabled
        disableLoggingEnabled = appState.isLoggingEnabled
        showOpenSystemSettings = appState.permissionStatus != .granted
        errorMessage = {
            if case let .error(message) = appState.loggingStatus {
                return message
            }
            return nil
        }()
    }
}

final class MenuBarController: NSObject {
    private let statusItem: MenuBarStatusItemPresenting
    private let appState: AppState
    private let transcriptWriter: TranscriptWriting
    private let screenOrchestrator: ScreenOrchestrating
    private let loggingCoordinator: LoggingCoordinator
    private let permissionGuidancePresenter: PermissionGuidancePresenting

    init(
        appState: AppState,
        transcriptWriter: TranscriptWriting,
        screenOrchestrator: ScreenOrchestrating,
        loggingCoordinator: LoggingCoordinator,
        permissionGuidancePresenter: PermissionGuidancePresenting = PermissionGuidanceAlertPresenter(),
        statusItem: MenuBarStatusItemPresenting = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    ) {
        self.statusItem = statusItem
        self.appState = appState
        self.transcriptWriter = transcriptWriter
        self.screenOrchestrator = screenOrchestrator
        self.loggingCoordinator = loggingCoordinator
        self.permissionGuidancePresenter = permissionGuidancePresenter
        super.init()
        rebuildMenu()
    }

    func rebuildMenu() {
        let state = MenuBarState(appState: appState)
        let menu = Self.makeMenu(target: self, state: state)

        statusItem.button?.image = statusImage
        statusItem.button?.imagePosition = .imageOnly
        statusItem.menu = menu
    }

    static func makeMenu(target: AnyObject, state: MenuBarState) -> NSMenu {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: state.statusTitle, action: nil, keyEquivalent: ""))
        if let errorMessage = state.errorMessage {
            menu.addItem(NSMenuItem(title: "Error: \(errorMessage)", action: nil, keyEquivalent: ""))
        }
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Enable Logging", action: #selector(enableLogging), keyEquivalent: "", target: target, isEnabled: state.enableLoggingEnabled))
        menu.addItem(actionItem(title: "Disable Logging", action: #selector(disableLogging), keyEquivalent: "", target: target, isEnabled: state.disableLoggingEnabled))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Open Settings…", action: #selector(openSettings), keyEquivalent: ",", target: target))
        menu.addItem(actionItem(title: "Open Analytics", action: #selector(openAnalytics), keyEquivalent: "", target: target))
        menu.addItem(actionItem(title: "Finger Calibration", action: #selector(openFingerCalibration), keyEquivalent: "", target: target))
        menu.addItem(actionItem(title: "Practice Now", action: #selector(practiceNow), keyEquivalent: "", target: target))
        if state.showOpenSystemSettings {
            menu.addItem(actionItem(title: "Open System Settings", action: #selector(openSystemSettings), keyEquivalent: "", target: target))
        }
        menu.addItem(actionItem(title: "Reveal Transcript in Finder", action: #selector(revealTranscript), keyEquivalent: "r", target: target))
        menu.addItem(actionItem(title: "Clear Transcript", action: #selector(clearTranscript), keyEquivalent: "", target: target))
        menu.addItem(.separator())
        menu.addItem(actionItem(title: "Quit", action: #selector(quit), keyEquivalent: "q", target: target))

        return menu
    }

    private static func actionItem(
        title: String,
        action: Selector,
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags = [.command],
        target: AnyObject,
        isEnabled: Bool = true
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = keyEquivalent.isEmpty ? [] : modifiers
        item.target = target
        item.isEnabled = isEnabled
        return item
    }

    private var statusImage: NSImage? {
        switch appState.loggingStatus {
        case .error:
            return NSImage(systemSymbolName: "exclamationmark.circle.fill", accessibilityDescription: "Logging error")
        case .enabled:
            return Self.accessibleImage(TypingLensBranding.menuBarIcon(), description: "TypingLens active")
        default:
            return Self.accessibleImage(TypingLensBranding.menuBarIcon(), description: "TypingLens")
        }
    }

    private static func accessibleImage(_ image: NSImage?, description: String) -> NSImage? {
        image?.accessibilityDescription = description
        return image
    }

    @objc private func enableLogging() {
        let didEnable = loggingCoordinator.enableLoggingRequested()
        if !didEnable, appState.permissionStatus != .granted {
            permissionGuidancePresenter.presentGuidance { [loggingCoordinator] in
                loggingCoordinator.openSystemSettingsRequested()
            }
        }
        rebuildMenu()
    }

    @objc private func disableLogging() {
        loggingCoordinator.disableLoggingRequested()
        rebuildMenu()
    }

    @objc func openSettings() {
        screenOrchestrator.handle(.openSettings)
    }

    @objc func openSystemSettings() {
        loggingCoordinator.openSystemSettingsRequested()
        rebuildMenu()
    }

    @objc func openAnalytics() {
        screenOrchestrator.handle(.openAnalytics)
    }

    @objc func openFingerCalibration() {
        screenOrchestrator.handle(.openFingerCalibration)
    }

    @objc func practiceNow() {
        screenOrchestrator.handle(.openPractice)
    }

    @objc func revealTranscript() {
        transcriptWriter.revealInFinder()
    }

    @objc func clearTranscript() {
        let alert = NSAlert()
        alert.messageText = "Clear transcript?"
        alert.informativeText = "This will empty transcript.jsonl but keep the file in place."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }

        loggingCoordinator.clearTranscriptRequested()
        rebuildMenu()
    }

    @objc private func quit() {
        QuitInterception.requestTermination()
        NSApp.terminate(nil)
    }
}
