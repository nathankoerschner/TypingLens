import AppKit
import SwiftUI

final class PracticeWindowController: NSWindowController {
    private let defaultWindowSize = NSSize(width: 900, height: 420)
    private let minimumWindowSize = NSSize(width: 700, height: 320)
    private let targetWidthRatio: CGFloat = 0.5
    private let targetHeightRatio: CGFloat = 0.6
    private var hostingController: NSHostingController<PracticeRootView>?
    var onRequestNewPrompt: (() -> Void)?

    init() {
        let initialFrame = Self.preferredFrame(
            for: NSScreen.main,
            minimumWindowSize: minimumWindowSize,
            fallbackSize: defaultWindowSize,
            widthRatio: targetWidthRatio,
            heightRatio: targetHeightRatio
        )
        let window = NSWindow(
            contentRect: initialFrame,
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Typing Practice"
        window.isReleasedWhenClosed = false
        window.minSize = minimumWindowSize

        super.init(window: window)

        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(prompt: PracticePrompt) {
        guard let window else { return }

        let viewModel = PracticeViewModel(
            prompt: prompt,
            onNewPrompt: { [weak self] in
                self?.onRequestNewPrompt?()
            }
        )

        let rootView = PracticeRootView(
            viewModel: viewModel,
            onClose: { [weak self] in
                self?.window?.orderOut(nil)
            }
        )

        if let hostingController {
            hostingController.rootView = rootView
        } else {
            let controller = NSHostingController(rootView: rootView)
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

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.orderOut(nil)
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
