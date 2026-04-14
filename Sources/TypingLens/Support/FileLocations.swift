import Foundation

struct FileLocations {
    let fileManager: FileManager
    let appSupportBaseURL: URL

    init(
        fileManager: FileManager = .default,
        appSupportBaseURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.appSupportBaseURL = appSupportBaseURL ?? fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
    }

    var appDirectoryURL: URL {
        appSupportBaseURL.appendingPathComponent("TypingLens", isDirectory: true)
    }

    var transcriptURL: URL {
        appDirectoryURL.appendingPathComponent("transcript.jsonl", isDirectory: false)
    }
}
