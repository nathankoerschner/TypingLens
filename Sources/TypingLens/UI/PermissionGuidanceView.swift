import AppKit
import SwiftUI

struct PermissionGuidanceView: View {
    let openSystemSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Permission required")
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .foregroundStyle(TypingLensTheme.accent)
            Text("TypingLens needs permission to monitor keyboard input globally.")
                .font(.system(size: 14, weight: .medium, design: .monospaced))
            Text("Grant access in System Settings to enable logging.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(TypingLensTheme.subdued)

            HStack(spacing: 10) {
                Button("Cancel", action: dismiss)
                    .buttonStyle(TypingLensFilledButtonStyle())
                Button("Open System Settings") {
                    openSystemSettings()
                    dismiss()
                }
                .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.primary, foregroundColor: TypingLensTheme.background))
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 460)
        .background(TypingLensTheme.background)
        .foregroundStyle(TypingLensTheme.text)
    }
}

protocol PermissionGuidancePresenting {
    func presentGuidance(openSystemSettings: @escaping () -> Void)
}

final class PermissionGuidanceAlertPresenter: PermissionGuidancePresenting {
    func presentGuidance(openSystemSettings: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = "TypingLens needs permission to monitor keyboard input globally. Grant access in System Settings to enable logging."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        guard response == .alertFirstButtonReturn else { return }
        openSystemSettings()
    }
}
