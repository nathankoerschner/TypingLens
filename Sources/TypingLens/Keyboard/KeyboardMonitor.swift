import AppKit

protocol KeyboardMonitoring {
    func start(handler: @escaping (NormalizedKeyEvent) -> Void) throws
    func stop()
}

protocol EventMonitoring {
    @discardableResult
    func addGlobalMonitorForEvents(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any

    func removeMonitor(_ monitor: Any)
}

final class SystemEventMonitoring: EventMonitoring {
    func addGlobalMonitorForEvents(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any {
        NSEvent.addGlobalMonitorForEvents(matching: mask, handler: handler) as Any
    }

    func removeMonitor(_ monitor: Any) {
        NSEvent.removeMonitor(monitor)
    }
}

final class KeyboardMonitor: KeyboardMonitoring {
    private let eventMonitoring: EventMonitoring

    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?

    init(eventMonitoring: EventMonitoring = SystemEventMonitoring()) {
        self.eventMonitoring = eventMonitoring
    }

    func start(handler: @escaping (NormalizedKeyEvent) -> Void) throws {
        stop()

        keyDownMonitor = eventMonitoring.addGlobalMonitorForEvents(matching: .keyDown) { event in
            handler(Self.normalize(event, type: .keyDown))
        }

        keyUpMonitor = eventMonitoring.addGlobalMonitorForEvents(matching: .keyUp) { event in
            handler(Self.normalize(event, type: .keyUp))
        }
    }

    func stop() {
        if let keyDownMonitor {
            eventMonitoring.removeMonitor(keyDownMonitor)
        }

        if let keyUpMonitor {
            eventMonitoring.removeMonitor(keyUpMonitor)
        }

        keyDownMonitor = nil
        keyUpMonitor = nil
    }

    private static func normalize(_ event: NSEvent, type: EventType) -> NormalizedKeyEvent {
        NormalizedKeyEvent(
            type: type,
            keyCode: event.keyCode,
            characters: event.characters,
            charactersIgnoringModifiers: event.charactersIgnoringModifiers,
            modifiers: ModifierNormalizer.names(from: event.modifierFlags),
            isRepeat: event.isARepeat,
            keyboardLayout: nil
        )
    }
}
