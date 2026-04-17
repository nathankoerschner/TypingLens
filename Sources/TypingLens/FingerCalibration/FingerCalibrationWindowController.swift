import AppKit
import SwiftUI

final class FingerCalibrationWindowController: NSWindowController, NSWindowDelegate {
    private let defaultWindowSize = NSSize(width: 1_240, height: 760)
    private let minimumWindowSize = NSSize(width: 1_080, height: 640)
    private let targetWidthRatio: CGFloat = 0.84
    private let targetHeightRatio: CGFloat = 0.76
    private var hostingController: NSHostingController<AnyView>?
    private let viewModel: FingerCalibrationViewModel
    var onWindowVisibilityChanged: ((Bool) -> Void)?

    init(appState: AppState) {
        let initialFrame = Self.preferredFrame(
            for: NSScreen.main,
            minimumWindowSize: minimumWindowSize,
            fallbackSize: defaultWindowSize,
            widthRatio: targetWidthRatio,
            heightRatio: targetHeightRatio
        )
        let window = ChromeLessWindow(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Finger Calibration"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = minimumWindowSize

        viewModel = FingerCalibrationViewModel(appState: appState)

        super.init(window: window)
        window.delegate = self
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }

        let rootView = FingerCalibrationRootView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.closeWindow()
            }
        )

        let anyRootView = AnyView(rootView)

        if let hostingController {
            hostingController.rootView = anyRootView
        } else {
            let controller = NSHostingController(rootView: anyRootView)
            controller.sizingOptions = []
            window.contentViewController = controller
            self.hostingController = controller
        }

        let targetScreen = screenForPresentation(from: window)
        let targetFrame = Self.preferredFrame(
            for: targetScreen,
            minimumWindowSize: minimumWindowSize,
            fallbackSize: defaultWindowSize,
            widthRatio: targetWidthRatio,
            heightRatio: targetHeightRatio
        )
        window.setFrame(targetFrame, display: true)

        onWindowVisibilityChanged?(true)
        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        onWindowVisibilityChanged?(false)
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onWindowVisibilityChanged?(false)
    }

    private func screenForPresentation(from window: NSWindow) -> NSScreen? {
        let mouseLocation = NSEvent.mouseLocation
        if let mouseScreen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) }) {
            return mouseScreen
        }

        return window.screen ?? NSScreen.main ?? NSScreen.screens.first
    }

    private static func preferredFrame(
        for screen: NSScreen?,
        minimumWindowSize: NSSize,
        fallbackSize: NSSize,
        widthRatio: CGFloat,
        heightRatio: CGFloat
    ) -> NSRect {
        guard let screen else {
            return NSRect(origin: .zero, size: fallbackSize)
        }

        let visibleFrame = screen.visibleFrame
        let width = max(minimumWindowSize.width, floor(visibleFrame.width * widthRatio))
        let height = max(minimumWindowSize.height, floor(visibleFrame.height * heightRatio))
        let x = visibleFrame.origin.x + ((visibleFrame.width - width) / 2)
        let y = visibleFrame.origin.y + ((visibleFrame.height - height) / 2)

        return NSRect(x: x, y: y, width: width, height: height)
    }
}
