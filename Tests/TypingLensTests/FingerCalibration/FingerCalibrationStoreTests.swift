import Foundation
import XCTest
@testable import TypingLens

final class FingerCalibrationStoreTests: XCTestCase {
    func testSaveAndLoadRoundTripsCalibration() throws {
        let tempRoot = temporaryDirectory()
        defer { cleanupDirectory(at: tempRoot) }
        let fileLocations = FileLocations(appSupportBaseURL: tempRoot)
        let store = FingerCalibrationStore(fileLocations: fileLocations)

        var calibration = FingerCalibration.makeDefault(name: "Desk", imageSize: CGSize(width: 1_280, height: 720))
        calibration.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        calibration.keyAdjustments["A"] = KeyAdjustment(offsetX: 3, offsetY: 4)
        calibration.transform.offsetX = 7

        try store.save(calibration)
        let loaded = try store.load(id: calibration.id)

        XCTAssertEqual(loaded, calibration)
    }

    func testListSummariesReturnsSortedCalibrationsAndSkipsMissingDirectory() throws {
        let tempRoot = temporaryDirectory()
        defer { cleanupDirectory(at: tempRoot) }
        let fileLocations = FileLocations(appSupportBaseURL: tempRoot)
        let store = FingerCalibrationStore(fileLocations: fileLocations)

        XCTAssertEqual(try store.listSummaries(), [])

        var older = FingerCalibration.makeDefault(name: "Older", id: UUID())
        older.updatedAt = Date(timeIntervalSince1970: 10)

        var newer = FingerCalibration.makeDefault(name: "Newer", id: UUID())
        newer.updatedAt = Date(timeIntervalSince1970: 20)

        try store.save(older)
        try store.save(newer)

        let summaries = try store.listSummaries()

        XCTAssertEqual(summaries.map(\.id), [newer.id, older.id])
    }

    func testDeleteRemovesSavedCalibration() throws {
        let tempRoot = temporaryDirectory()
        defer { cleanupDirectory(at: tempRoot) }
        let fileLocations = FileLocations(appSupportBaseURL: tempRoot)
        let store = FingerCalibrationStore(fileLocations: fileLocations)

        let calibration = FingerCalibration.makeDefault(name: "Delete Me", id: UUID())
        try store.save(calibration)

        let summaries = try store.listSummaries()
        XCTAssertEqual(summaries.count, 1)

        try store.delete(id: calibration.id)

        let afterDelete = try store.listSummaries()
        XCTAssertEqual(afterDelete.count, 0)
        XCTAssertThrowsError(try store.load(id: calibration.id))
    }

    private func temporaryDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("FingerCalibrationStoreTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString)
    }

    private func cleanupDirectory(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}
