import AppKit
import XCTest
@testable import TypingLens

@MainActor
final class FingerCalibrationWindowControllerTests: XCTestCase {
    func testShowAndCloseConfiguresWindowAndVisibilityCallbacks() {
        let controller = FingerCalibrationWindowController(appState: makeAppState())
        var visibilityChanges: [Bool] = []
        controller.onWindowVisibilityChanged = { isVisible in
            visibilityChanges.append(isVisible)
        }

        XCTAssertEqual(controller.window?.title, "Finger Calibration")
        XCTAssertEqual(controller.window?.isReleasedWhenClosed, false)

        controller.show()

        XCTAssertEqual(visibilityChanges.first, true)
        XCTAssertEqual(controller.window?.isVisible, true)

        controller.closeWindow()
        XCTAssertEqual(visibilityChanges.last, false)
        XCTAssertEqual(controller.window?.isVisible, false)
    }

    private func makeAppState() -> AppState {
        AppState(
            transcriptPath: "/tmp/transcript.jsonl",
            permissionStatus: .unknown,
            loggingStatus: .disabled,
            launchAtLoginEnabled: false
        )
    }
}
