import Foundation

enum ScreenIntent: Equatable {
    case openSettings
    case openPractice
    case openAnalytics
    case openFingerCalibration
    case refreshAnalytics
    case requestNewPracticePrompt
    case closePractice
    case closeAnalytics
    case closeFingerCalibration
}

protocol ScreenOrchestrating {
    func handle(_ intent: ScreenIntent)
}
