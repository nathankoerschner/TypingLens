import AppKit
import SwiftUI

enum QuitInterception {
    private static var allowsTermination = false

    static func requestTermination() {
        allowsTermination = true
    }

    static func dismissCurrentUI(application: NSApplication = .shared) {
        if let window = application.keyWindow
            ?? application.mainWindow
            ?? application.orderedWindows.first(where: { $0.isVisible })
        {
            window.performClose(nil)
            return
        }

        application.hide(nil)
    }

    static func terminateReply(for application: NSApplication = .shared) -> NSApplication.TerminateReply {
        guard !allowsTermination else {
            return .terminateNow
        }

        dismissCurrentUI(application: application)
        return .terminateCancel
    }
}

final class TypingLensAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        QuitInterception.terminateReply(for: sender)
    }
}

@main
struct TypingLensApp: App {
    @NSApplicationDelegateAdaptor(TypingLensAppDelegate.self) private var appDelegate
    @StateObject private var appState: AppState
    private let loggingCoordinator: LoggingCoordinator
    private let menuBarController: MenuBarController
    private let practiceWindowController: PracticeWindowController
    private let analyticsWindowController: AnalyticsWindowController
    private let mediaPipeWindowController: MediaPipeWindowController
    private let settingsSceneOpener: SettingsSceneOpening
    private let launchAtLoginManager: LaunchAtLoginManager
    private let didBecomeActiveObserver: NSObjectProtocol

    init() {
        ApplicationBootstrap.configureMenuBarActivationPolicy()
        TypingLensBranding.applyAppIcon()

        let windowActivationController = WindowActivationController(application: NSApplication.shared)
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
        practiceWindowController.onWindowVisibilityChanged = {
            windowActivationController.setWindowVisible($0, identifier: "practice")
        }
        self.practiceWindowController = practiceWindowController
        let analyticsWindowController = AnalyticsWindowController()
        analyticsWindowController.onWindowVisibilityChanged = {
            windowActivationController.setWindowVisible($0, identifier: "analytics")
        }
        self.analyticsWindowController = analyticsWindowController

        let mediaPipeWindowController = MediaPipeWindowController()
        mediaPipeWindowController.onWindowVisibilityChanged = {
            windowActivationController.setWindowVisible($0, identifier: "mediapipe")
        }
        self.mediaPipeWindowController = mediaPipeWindowController

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
            },
            onExportRankedWords: {
                loggingCoordinator.exportRankedWordsRequested()
            },
            onPracticeNow: {
                if let prompt = loggingCoordinator.makePracticePrompt() {
                    practiceWindowController.show(prompt: prompt)
                }
            },
            onOpenAnalytics: {
                if let result = loggingCoordinator.makeAnalyticsResult() {
                    analyticsWindowController.show(result: result)
                }
            },
            onOpenMediaPipe: {
                mediaPipeWindowController.show()
            }
        )
        settingsWindowController.onWindowVisibilityChanged = {
            windowActivationController.setWindowVisible($0, identifier: "settings")
        }

        let settingsSceneOpener = SwiftUISettingsSceneOpener(settingsWindow: settingsWindowController)
        self.settingsSceneOpener = settingsSceneOpener

        practiceWindowController.onRequestNewPrompt = {
            if let prompt = loggingCoordinator.makePracticePrompt() {
                practiceWindowController.show(prompt: prompt)
            }
        }
        analyticsWindowController.onRefreshAnalytics = {
            if let result = loggingCoordinator.makeAnalyticsResult() {
                analyticsWindowController.show(result: result)
            }
        }

        _appState = StateObject(wrappedValue: state)
        menuBarController = MenuBarController(
            appState: state,
            transcriptWriter: transcriptWriter,
            onOpenSettings: {
                settingsSceneOpener.openSettingsScene()
            },
            onOpenAnalytics: {
                if let result = loggingCoordinator.makeAnalyticsResult() {
                    analyticsWindowController.show(result: result)
                }
            },
            onPracticeNow: {
                if let prompt = loggingCoordinator.makePracticePrompt() {
                    practiceWindowController.show(prompt: prompt)
                }
            },
            onOpenMediaPipe: {
                mediaPipeWindowController.show()
            },
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
                        if let prompt = loggingCoordinator.makePracticePrompt() {
                            practiceWindowController.show(prompt: prompt)
                        }
                    },
                    onOpenAnalytics: {
                        if let result = loggingCoordinator.makeAnalyticsResult() {
                            analyticsWindowController.show(result: result)
                        }
                    },
                    onOpenMediaPipe: {
                        mediaPipeWindowController.show()
                    }
                )
            )
        }
    }
}
