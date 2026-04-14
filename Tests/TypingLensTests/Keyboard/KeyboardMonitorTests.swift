import AppKit
import XCTest
@testable import TypingLens

final class KeyboardMonitorTests: XCTestCase {
    func testModifierNamesAreNormalizedInFixedOrder() {
        let flags: NSEvent.ModifierFlags = [.option, .shift, .command, .capsLock, .control, .function]
        XCTAssertEqual(
            ModifierNormalizer.names(from: flags),
            ["shift", "control", "option", "command", "capsLock", "function"]
        )
    }

    func testStartRegistersGlobalMonitorsForKeyDownAndKeyUp() throws {
        let spyMonitor = SpyEventMonitoring()
        let keyboardMonitor = KeyboardMonitor(eventMonitoring: spyMonitor)

        try keyboardMonitor.start { _ in }

        XCTAssertEqual(spyMonitor.addedMonitors.count, 2)
        XCTAssertEqual(spyMonitor.addedMonitors.map(\.mask), [.keyDown, .keyUp])
    }

    func testStopRemovesAllActiveMonitors() throws {
        let spyMonitor = SpyEventMonitoring()
        let keyboardMonitor = KeyboardMonitor(eventMonitoring: spyMonitor)

        try keyboardMonitor.start { _ in }
        keyboardMonitor.stop()

        XCTAssertEqual(spyMonitor.removedMonitors.count, 2)
    }

    func testRestartingStartCleansUpPriorMonitors() throws {
        let spyMonitor = SpyEventMonitoring()
        let keyboardMonitor = KeyboardMonitor(eventMonitoring: spyMonitor)

        try keyboardMonitor.start { _ in }
        try keyboardMonitor.start { _ in }

        XCTAssertEqual(spyMonitor.addedMonitors.count, 4)
        XCTAssertEqual(spyMonitor.removedMonitors.count, 2)
    }
}

private final class SpyEventMonitoring: EventMonitoring {
    struct RecordedMonitor {
        let token: Int
        let mask: NSEvent.EventTypeMask
    }

    private(set) var addedMonitors: [RecordedMonitor] = []
    private(set) var removedMonitors: [RecordedMonitor] = []
    private var nextToken = 0

    @discardableResult
    func addGlobalMonitorForEvents(
        matching mask: NSEvent.EventTypeMask,
        handler: @escaping (NSEvent) -> Void
    ) -> Any {
        let token = RecordedMonitor(token: nextToken, mask: mask)
        nextToken += 1
        addedMonitors.append(token)
        return token
    }

    func removeMonitor(_ monitor: Any) {
        if let token = monitor as? RecordedMonitor {
            removedMonitors.append(token)
        }
    }
}
