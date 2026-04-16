import AppKit
import SwiftUI

@main
struct TypingLensApp: App {
    @StateObject private var appState: AppState
    private let loggingCoordinator: LoggingCoordinator
    private let menuBarController: MenuBarController
    private let practiceWindowController: PracticeWindowController
    private let analyticsWindowController: AnalyticsWindowController
    private let launchAtLoginManager: LaunchAtLoginManager
    private let didBecomeActiveObserver: NSObjectProtocol

    init() {
        ApplicationBootstrap.configureMenuBarActivationPolicy()
        TypingLensBranding.applyAppIcon()

        let fileLocations = FileLocations()
        let transcriptWriter = TranscriptWriter(fileLocations: fileLocations)
        let permissionManager = PermissionManager()
        let preferencesStore = PreferencesStore()
        let launchAtLoginManager = LaunchAtLoginManager(preferencesStore: preferencesStore)
        self.launchAtLoginManager = launchAtLoginManager
        let state = AppState(
            transcriptPath: fileLocations.transcriptURL.path,
            permissionStatus: permissionManager.currentStatus(),
            loggingStatus: .disabled,
            launchAtLoginEnabled: launchAtLoginManager.isEnabled()
        )
        let keyboardMonitor = KeyboardMonitor()
        let practiceWindowController = PracticeWindowController()
        self.practiceWindowController = practiceWindowController
        let analyticsWindowController = AnalyticsWindowController()
        self.analyticsWindowController = analyticsWindowController

        let loggingCoordinator: LoggingCoordinator
        do {
            loggingCoordinator = try LoggingCoordinator(
                appState: state,
                fileLocations: fileLocations,
                permissionManager: permissionManager,
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter,
                onOpenPractice: { prompt in
                    practiceWindowController.show(prompt: prompt)
                },
                onOpenAnalytics: { result in
                    analyticsWindowController.show(result: result)
                }
            )
        } catch {
            state.loggingStatus = .error(message: error.localizedDescription)
            loggingCoordinator = LoggingCoordinator(
                appState: state,
                fileLocations: fileLocations,
                permissionManager: permissionManager,
                keyboardMonitor: keyboardMonitor,
                transcriptWriter: transcriptWriter,
                onOpenPractice: { prompt in
                    practiceWindowController.show(prompt: prompt)
                },
                onOpenAnalytics: { result in
                    analyticsWindowController.show(result: result)
                },
                initialSequence: 1
            )
        }

        practiceWindowController.onRequestNewPrompt = {
            loggingCoordinator.practiceNowRequested()
        }
        analyticsWindowController.onRefreshAnalytics = {
            loggingCoordinator.showAnalyticsRequested()
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
            },
            onExportRankedWords: {
                loggingCoordinator.exportRankedWordsRequested()
            },
            onPracticeNow: {
                loggingCoordinator.practiceNowRequested()
            },
            onOpenAnalytics: {
                loggingCoordinator.showAnalyticsRequested()
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
                    },
                    onExportRankedWords: {
                        loggingCoordinator.exportRankedWordsRequested()
                    },
                    onPracticeNow: {
                        loggingCoordinator.practiceNowRequested()
                    },
                    onOpenAnalytics: {
                        loggingCoordinator.showAnalyticsRequested()
                    }
                )
            )
        }
    }
}
