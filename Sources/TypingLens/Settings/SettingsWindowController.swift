import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, SettingsWindowShowing, NSWindowDelegate {
    var onWindowVisibilityChanged: ((Bool) -> Void)?
    init(
        appState: AppState,
        onRefreshPermissionStatus: @escaping () -> Void,
        onOpenSystemSettings: @escaping () -> Void,
        onRevealTranscript: @escaping () -> Void,
        onClearTranscript: @escaping () -> Void,
        onToggleLaunchAtLogin: @escaping (Bool) -> Void,
        onExtractWords: @escaping () -> Void,
        onExportRankedWords: @escaping () -> Void,
        onPracticeNow: @escaping () -> Void,
        onOpenAnalytics: @escaping () -> Void
    ) {
        let rootView = SettingsRootView(
            appState: appState,
            viewModel: .init(
                onRefreshPermissionStatus: onRefreshPermissionStatus,
                onOpenSystemSettings: onOpenSystemSettings,
                onRevealTranscript: onRevealTranscript,
                onClearTranscript: onClearTranscript,
                onToggleLaunchAtLogin: onToggleLaunchAtLogin,
                onExtractWords: onExtractWords,
                onExportRankedWords: onExportRankedWords,
                onPracticeNow: onPracticeNow,
                onOpenAnalytics: onOpenAnalytics
            )
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.title = "TypingLens Settings"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.setContentSize(NSSize(width: 640, height: 520))

        super.init(window: window)
        window.delegate = self
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettingsWindow() {
        onWindowVisibilityChanged?(true)
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }

    func closeWindow() {
        onWindowVisibilityChanged?(false)
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        onWindowVisibilityChanged?(false)
    }
}
