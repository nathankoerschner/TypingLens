import AppKit

enum ApplicationBootstrap {
    static func configureMenuBarActivationPolicy(application: NSApplication = .shared) {
        _ = application.setActivationPolicy(.accessory)
    }

    static func configureWindowActivationPolicy(application: NSApplication = .shared) {
        _ = application.setActivationPolicy(.regular)
    }
}
