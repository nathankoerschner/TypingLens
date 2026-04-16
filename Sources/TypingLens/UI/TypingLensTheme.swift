import SwiftUI

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

enum TypingLensTheme {
    static let background = Color(hex: 0x323437)
    static let panel = Color(hex: 0x2C2E31)
    static let panelElevated = Color(hex: 0x3A3D41)
    static let primary = Color(hex: 0xFF8A3D)
    static let accent = Color(hex: 0xFF8A3D)
    static let titleStyle = LinearGradient(
        colors: [accent, accent],
        startPoint: .top,
        endPoint: .bottom
    )
    static let text = Color(hex: 0xD1D0C5)
    static let subdued = Color(hex: 0x646669)
    static let error = Color(hex: 0xCA4754)
    static let errorMuted = Color(hex: 0x7E2A33)
}

struct TypingLensFilledButtonStyle: ButtonStyle {
    let backgroundColor: Color
    let foregroundColor: Color

    init(backgroundColor: Color = TypingLensTheme.panel, foregroundColor: Color = TypingLensTheme.text) {
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .medium, design: .monospaced))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(foregroundColor)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(backgroundColor.opacity(configuration.isPressed ? 0.82 : 1))
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

struct TypingLensCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(TypingLensTheme.panel)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(TypingLensTheme.panelElevated, lineWidth: 1)
            )
    }
}

extension View {
    func typingLensCard() -> some View {
        modifier(TypingLensCardModifier())
    }
}
