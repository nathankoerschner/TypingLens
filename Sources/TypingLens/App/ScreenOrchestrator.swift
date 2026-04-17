import Foundation

final class ScreenOrchestrator: ScreenOrchestrating {
    private let loggingCoordinator: LoggingCoordinator
    private let settingsSceneOpening: SettingsSceneOpening
    private let practiceWindowController: PracticeWindowController
    private let analyticsWindowController: AnalyticsWindowController
    private let fingerCalibrationWindowController: FingerCalibrationWindowController

    init(
        loggingCoordinator: LoggingCoordinator,
        settingsSceneOpening: SettingsSceneOpening,
        practiceWindowController: PracticeWindowController,
        analyticsWindowController: AnalyticsWindowController,
        fingerCalibrationWindowController: FingerCalibrationWindowController
    ) {
        self.loggingCoordinator = loggingCoordinator
        self.settingsSceneOpening = settingsSceneOpening
        self.practiceWindowController = practiceWindowController
        self.analyticsWindowController = analyticsWindowController
        self.fingerCalibrationWindowController = fingerCalibrationWindowController
    }

    func handle(_ intent: ScreenIntent) {
        switch intent {
        case .openSettings:
            settingsSceneOpening.openSettingsScene()
        case .openPractice, .requestNewPracticePrompt:
            if let prompt = loggingCoordinator.makePracticePrompt() {
                practiceWindowController.show(prompt: prompt)
            }
        case .openAnalytics, .refreshAnalytics:
            if let result = loggingCoordinator.makeAnalyticsResult() {
                analyticsWindowController.show(result: result)
            }
        case .openFingerCalibration:
            fingerCalibrationWindowController.show()
        case .closePractice:
            practiceWindowController.closeWindow()
        case .closeAnalytics:
            analyticsWindowController.closeWindow()
        case .closeFingerCalibration:
            fingerCalibrationWindowController.closeWindow()
        }
    }
}
