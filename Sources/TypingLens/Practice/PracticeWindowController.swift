import AppKit
import SwiftUI

final class PracticeWindowController: NSWindowController {
    private let defaultWindowSize = NSSize(width: 900, height: 420)
    private let minimumWindowSize = NSSize(width: 700, height: 320)
    private var hostingController: NSHostingController<PracticeRootView>?
    var onRequestNewPrompt: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: defaultWindowSize.width, height: defaultWindowSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Typing Practice"
        window.isReleasedWhenClosed = false
        window.setContentSize(defaultWindowSize)
        window.minSize = minimumWindowSize
        window.center()

        super.init(window: window)

        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(prompt: PracticePrompt) {
        guard let window else { return }
        let currentFrame = window.frame

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

        window.setFrame(currentFrame, display: true)

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.orderOut(nil)
    }
}
