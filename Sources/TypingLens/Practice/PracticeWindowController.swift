import AppKit
import SwiftUI

final class PracticeWindowController: NSWindowController {
    private var hostingController: NSHostingController<PracticeRootView>?
    var onRequestNewPrompt: (() -> Void)?

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Typing Practice"
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 900, height: 520))
        window.minSize = NSSize(width: 900, height: 520)
        window.center()

        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(prompt: PracticePrompt) {
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
            window?.contentViewController = controller
            self.hostingController = controller
        }

        if let window {
            let targetSize = NSSize(width: 900, height: 520)
            window.setContentSize(targetSize)
            window.layoutIfNeeded()
        }

        NSApp.activate(ignoringOtherApps: true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        window?.orderOut(nil)
    }
}
