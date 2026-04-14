import AppKit

enum ApplicationBootstrap {
    static func configureMenuBarActivationPolicy(application: NSApplication = .shared) {
        _ = application.setActivationPolicy(.accessory)
    }
}
