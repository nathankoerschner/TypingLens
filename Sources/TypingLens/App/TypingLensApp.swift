import AppKit
import SwiftUI

@main
struct TypingLensApp: App {
    @StateObject private var appState: AppState
    private let loggingCoordinator: LoggingCoordinator
    private let menuBarController: MenuBarController
    private let launchAtLoginManager: LaunchAtLoginManager
    private let didBecomeActiveObserver: NSObjectProtocol

    init() {
        ApplicationBootstrap.configureMenuBarActivationPolicy()

        let fileLocations = FileLocations()
        let transcriptWriter = TranscriptWriter(fileLocations: fileLocations)
        let permissionManager = PermissionManager()
        let launchAtLoginManager = LaunchAtLoginManager()
        self.launchAtLoginManager = launchAtLoginManager
        let state = AppState(
            transcriptPath: fileLocations.transcriptURL.path,
            permissionStatus: permissionManager.currentStatus(),
            loggingStatus: .disabled,
            launchAtLoginEnabled: launchAtLoginManager.isEnabled()
        )
        let keyboardMonitor = KeyboardMonitor()
        let loggingCoordinator: LoggingCoordinator
        do {
            loggingCoordinator = try LoggingCoordinator(
                appState: state,
                fileLocations: fileLocations,
                permissionManager: permissionManager,
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter
            )
        } catch {
            state.loggingStatus = .error(message: error.localizedDescription)
            loggingCoordinator = LoggingCoordinator(
                appState: state,
                fileLocations: fileLocations,
                permissionManager: permissionManager,
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter,
                initialSequence: 1
            )
        }
        var menuBarController: MenuBarController!
        let settingsWindowController = SettingsWindowController(
            appState: state,
            onRefreshPermissionStatus: {
                loggingCoordinator.refreshPermissionStatus()
                menuBarController.rebuildMenu()
            },
            onOpenSystemSettings: { loggingCoordinator.openSystemSettingsRequested() },
            onRevealTranscript: { menuBarController.revealTranscript() },
            onClearTranscript: { menuBarController.clearTranscript() },
            onToggleLaunchAtLogin: { isEnabled in
                do {
                    try launchAtLoginManager.setEnabled(isEnabled)
                    state.launchAtLoginEnabled = isEnabled
                } catch {
                    state.loggingStatus = .error(message: error.localizedDescription)
                }
            },
            onExtractWords: {
                loggingCoordinator.extractWordsRequested()
            }
        )

        _appState = StateObject(wrappedValue: state)
        menuBarController = MenuBarController(
            appState: state,
            transcriptWriter: transcriptWriter,
            settingsSceneOpening: SwiftUISettingsSceneOpener(settingsWindow: settingsWindowController),
            loggingCoordinator: loggingCoordinator
        )
        self.loggingCoordinator = loggingCoordinator
        self.menuBarController = menuBarController

        self.didBecomeActiveObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { _ in
            loggingCoordinator.handleAppDidBecomeActive()
            menuBarController.rebuildMenu()
        }
    }

    var body: some Scene {
        Settings {
            SettingsRootView(
                appState: appState,
                viewModel: .init(
                    onRefreshPermissionStatus: {
                        loggingCoordinator.refreshPermissionStatus()
                        menuBarController.rebuildMenu()
                    },
                    onOpenSystemSettings: { loggingCoordinator.openSystemSettingsRequested() },
                    onRevealTranscript: { menuBarController.revealTranscript() },
                    onClearTranscript: { menuBarController.clearTranscript() },
                    onToggleLaunchAtLogin: { isEnabled in
                        do {
                            try self.launchAtLoginManager.setEnabled(isEnabled)
                            appState.launchAtLoginEnabled = isEnabled
                        } catch {
                            appState.loggingStatus = .error(message: error.localizedDescription)
                        }
                    },
                    onExtractWords: {
                        loggingCoordinator.extractWordsRequested()
                    }
                )
            )
        }
    }
}
