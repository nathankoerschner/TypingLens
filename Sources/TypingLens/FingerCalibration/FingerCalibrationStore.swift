import Foundation

enum FingerCalibrationStoreError: Error, Equatable {
    case missingFile(UUID)
}

final class FingerCalibrationStore {
    private let fileLocations: FileLocations
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        fileLocations: FileLocations,
        fileManager: FileManager = .default,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.fileLocations = fileLocations
        self.fileManager = fileManager
        self.encoder = encoder
        self.decoder = decoder
    }

    func save(_ calibration: FingerCalibration) throws {
        try fileManager.createDirectory(
            at: fileLocations.fingerCalibrationsDirectoryURL,
            withIntermediateDirectories: true
        )

        let destinationURL = calibrationFileURL(for: calibration.id)
        let data = try encoder.encode(calibration)
        try data.write(to: destinationURL, options: .atomic)
    }

    func load(id: UUID) throws -> FingerCalibration {
        let fileURL = calibrationFileURL(for: id)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw FingerCalibrationStoreError.missingFile(id)
        }

        let data = try Data(contentsOf: fileURL)
        return try decoder.decode(FingerCalibration.self, from: data)
    }

    func delete(id: UUID) throws {
        let fileURL = calibrationFileURL(for: id)
        guard fileManager.fileExists(atPath: fileURL.path) else {
            throw FingerCalibrationStoreError.missingFile(id)
        }

        try fileManager.removeItem(at: fileURL)
    }

    func listSummaries() throws -> [SavedCalibrationSummary] {
        guard fileManager.fileExists(atPath: fileLocations.fingerCalibrationsDirectoryURL.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: fileLocations.fingerCalibrationsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        let calibrations: [SavedCalibrationSummary] = urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { url in
                guard let data = try? Data(contentsOf: url),
                      let calibration = try? decoder.decode(FingerCalibration.self, from: data) else {
                    return nil
                }

                return SavedCalibrationSummary(
                    id: calibration.id,
                    name: calibration.name,
                    updatedAt: calibration.updatedAt,
                    fileURL: url
                )
            }
            .sorted { first, second in
                if first.updatedAt != second.updatedAt {
                    return first.updatedAt > second.updatedAt
                }
                return first.name.localizedStandardCompare(second.name) == .orderedAscending
            }

        return calibrations
    }

    private func calibrationFileURL(for id: UUID) -> URL {
        fileLocations.fingerCalibrationsDirectoryURL
            .appendingPathComponent("\(id.uuidString).json", isDirectory: false)
    }
}
