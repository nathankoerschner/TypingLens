import AppKit
import SwiftUI

enum TypingLensBranding {
    static let appIcon: NSImage? = {
        guard let url = Bundle.module.url(forResource: "app-icon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
    }()

    static func applyAppIcon() {
        guard let appIcon else { return }

        NSApplication.shared.applicationIconImage = appIcon
        _ = NSWorkspace.shared.setIcon(appIcon, forFile: Bundle.main.bundlePath, options: [])
    }
}

struct TypingLensLogoMark: View {
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 28, color: Color = TypingLensTheme.primary) {
        self.size = size
        self.color = color
    }

    var body: some View {
        Group {
            if let image = TypingLensBranding.appIcon {
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .foregroundStyle(color)
                    .frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

struct TypingLensTitleLockup: View {
    let logoSize: CGFloat
    let spacing: CGFloat
    let logoColor: Color

    init(logoSize: CGFloat = 28, spacing: CGFloat = 10, logoColor: Color = TypingLensTheme.primary) {
        self.logoSize = logoSize
        self.spacing = spacing
        self.logoColor = logoColor
    }

    var body: some View {
        HStack(spacing: spacing) {
            TypingLensLogoMark(size: logoSize, color: logoColor)
            Text("TypingLens")
                .font(.system(size: 28, weight: .semibold, design: .monospaced))
                .foregroundStyle(TypingLensTheme.titleStyle)
        }
    }
}
