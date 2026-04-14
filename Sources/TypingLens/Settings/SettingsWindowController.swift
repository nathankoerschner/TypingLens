import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController, SettingsWindowShowing {
    init(
        appState: AppState,
        onRefreshPermissionStatus: @escaping () -> Void,
        onOpenSystemSettings: @escaping () -> Void,
        onRevealTranscript: @escaping () -> Void,
        onClearTranscript: @escaping () -> Void,
        onToggleLaunchAtLogin: @escaping (Bool) -> Void
    ) {
        let rootView = SettingsRootView(
            appState: appState,
            viewModel: .init(
                onRefreshPermissionStatus: onRefreshPermissionStatus,
                onOpenSystemSettings: onOpenSystemSettings,
                onRevealTranscript: onRevealTranscript,
                onClearTranscript: onClearTranscript,
                onToggleLaunchAtLogin: onToggleLaunchAtLogin
            )
        )
        let hostingController = NSHostingController(rootView: rootView)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 260),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "TypingLens Settings"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        window.setContentSize(NSSize(width: 560, height: 260))

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func showSettingsWindow() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
