import AppKit
import SwiftUI

struct PermissionGuidanceView: View {
    let openSystemSettings: () -> Void
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TypingLens needs permission to monitor keyboard input globally.")
            Text("Grant access in System Settings to enable logging.")
                .foregroundStyle(.secondary)

            HStack {
                Button("Cancel", action: dismiss)
                Button("Open System Settings") {
                    openSystemSettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 420)
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
