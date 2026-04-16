import AppKit
import SwiftUI

final class AnalyticsWindowController: NSWindowController, NSWindowDelegate {
    private let defaultWindowSize = NSSize(width: 980, height: 620)
    private let minimumWindowSize = NSSize(width: 900, height: 560)
    private let targetWidthRatio: CGFloat = 0.62
    private let targetHeightRatio: CGFloat = 0.72
    private var hostingController: NSHostingController<AnyView>?
    private let viewModel: AnalyticsViewModel
    var onWindowVisibilityChanged: ((Bool) -> Void)?
    var onRefreshAnalytics: (() -> Void)? {
        didSet {
            viewModel.onRefresh = onRefreshAnalytics ?? {}
        }
    }

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
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Typing Analytics"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.minSize = minimumWindowSize

        viewModel = AnalyticsViewModel()

        super.init(window: window)
        window.delegate = self
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(result: AnalyticsResult) {
        guard let window else { return }

        viewModel.show(result: result)
        let rootView = AnalyticsRootView(
            viewModel: viewModel,
            onClose: { [weak self] in self?.closeWindow() }
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
