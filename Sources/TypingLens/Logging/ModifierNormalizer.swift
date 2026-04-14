import AppKit

enum ModifierNormalizer {
    static func names(from flags: NSEvent.ModifierFlags) -> [String] {
        var result: [String] = []

        if flags.contains(.shift) { result.append("shift") }
        if flags.contains(.control) { result.append("control") }
        if flags.contains(.option) { result.append("option") }
        if flags.contains(.command) { result.append("command") }
        if flags.contains(.capsLock) { result.append("capsLock") }
        if flags.contains(.function) { result.append("function") }

        return result
    }
}
