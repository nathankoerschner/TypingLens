import AppKit

protocol ActivationPolicySetting {
    @discardableResult
    func setActivationPolicy(_ activationPolicy: NSApplication.ActivationPolicy) -> Bool
}

extension NSApplication: ActivationPolicySetting {}

final class WindowActivationController {
    private let application: ActivationPolicySetting
    private let onPromoteToRegularApp: () -> Void
    private var visibleWindowIdentifiers: Set<String> = []

    init(
        application: ActivationPolicySetting,
        onPromoteToRegularApp: @escaping () -> Void = { TypingLensBranding.applyAppIcon() }
    ) {
        self.application = application
        self.onPromoteToRegularApp = onPromoteToRegularApp
    }

    func setWindowVisible(_ isVisible: Bool, identifier: String) {
        if isVisible {
            visibleWindowIdentifiers.insert(identifier)
        } else {
            visibleWindowIdentifiers.remove(identifier)
        }

        let activationPolicy: NSApplication.ActivationPolicy = visibleWindowIdentifiers.isEmpty ? .accessory : .regular
        _ = application.setActivationPolicy(activationPolicy)

        if !visibleWindowIdentifiers.isEmpty {
            onPromoteToRegularApp()
        }
    }
}
