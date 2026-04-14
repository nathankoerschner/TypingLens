import Foundation

enum EventType: String, Codable {
    case keyDown
    case keyUp
}

struct TranscriptEvent: Codable, Equatable {
    let seq: Int64
    let ts: String
    let type: EventType
    let keyCode: UInt16
    let characters: String?
    let charactersIgnoringModifiers: String?
    let modifiers: [String]
    let isRepeat: Bool
    let keyboardLayout: String?
}

extension JSONEncoder {
    static func transcriptEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = []
        return encoder
    }
}
