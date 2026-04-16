import AppKit
import SwiftUI

enum TypingLensBranding {
    static let appIcon: NSImage? = loadAppIcon()
    static let toolbarIcon: NSImage? = loadImage(named: "logging-enabled")

    static func menuBarIcon(size: CGFloat = 20) -> NSImage? {
        guard let image = toolbarIcon?.copy() as? NSImage else { return nil }
        image.isTemplate = true
        let aspectRatio = image.size.width / max(image.size.height, 1)
        image.size = NSSize(width: size * aspectRatio, height: size)
        return image
    }

    static func applyAppIcon() {
        guard let appIcon else { return }

        NSApplication.shared.applicationIconImage = appIcon
        NSApplication.shared.dockTile.display()
        _ = NSWorkspace.shared.setIcon(appIcon, forFile: Bundle.main.bundlePath, options: [])
    }

    private static func loadAppIcon() -> NSImage? {
        if let catalogIcon = NSImage(named: "AppIcon") {
            return catalogIcon
        }

        if let icnsURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let icnsImage = NSImage(contentsOf: icnsURL) {
            return icnsImage
        }

        return loadImage(named: "app-icon")
    }

    private static func loadImage(named name: String) -> NSImage? {
        guard let url = TypingLensBundle.resources.url(forResource: name, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            return nil
        }
        return image
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
            if let image = TypingLensBranding.toolbarIcon {
                let aspectRatio = image.size.width / max(image.size.height, 1)
                Image(nsImage: image)
                    .renderingMode(.template)
                    .resizable()
                    .interpolation(.high)
                    .foregroundStyle(color)
                    .frame(width: size * aspectRatio, height: size)
            }
        }
        .accessibilityHidden(true)
    }
}

struct TypingLensTitleLockup: View {
    let logoSize: CGFloat
    let spacing: CGFloat
    let logoColor: Color

    init(logoSize: CGFloat = 28, spacing: CGFloat = 6, logoColor: Color = TypingLensTheme.primary) {
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
