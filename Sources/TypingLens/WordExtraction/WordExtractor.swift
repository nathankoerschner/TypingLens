import Foundation

struct WordExtractor {
    private static let timeGapThresholdSeconds: TimeInterval = 2.0
    /// Characters allowed inside a word buffer. Everything else acts as a word boundary.
    private static let allowedWordCharacters: CharacterSet = {
        var set = CharacterSet.letters
        set.insert(charactersIn: "'\u{2019}")  // apostrophe + smart apostrophe for contractions
        return set
    }()

    private static func isAllowedInWord(_ characters: String) -> Bool {
        !characters.isEmpty && characters.unicodeScalars.allSatisfy { allowedWordCharacters.contains($0) }
    }

    func extract(from events: [TranscriptEvent], at extractionDate: Date = Date()) -> WordExtractionResult {
        var words: [ExtractedWord] = []
        var buffer = WordBuffer()
        let iso = TimestampFormatter.iso8601WithFractionalSeconds

        for event in events {
            guard event.type == .keyDown else {
                if event.type == .keyUp, buffer.hasContent {
                    if let ts = iso.date(from: event.ts) {
                        buffer.lastKeyUpTime = ts
                    }
                }
                continue
            }

            guard !event.isRepeat else { continue }

            let modifiers = Set(event.modifiers)

            if modifiers.contains("command") || modifiers.contains("control") {
                let chars = event.characters ?? event.charactersIgnoringModifiers ?? ""
                if chars == "\u{7F}" || chars == "\u{08}" {
                    buffer = WordBuffer()
                }
                continue
            }

            let characters = event.characters ?? ""

            if buffer.hasContent, let currentTs = iso.date(from: event.ts) {
                if let lastTime = buffer.lastKeyDownTime,
                   currentTs.timeIntervalSince(lastTime) > Self.timeGapThresholdSeconds {
                    if let word = buffer.finalize() {
                        words.append(word)
                    }
                    buffer = WordBuffer()
                }
            }

            // Backspace → remove last character, increment mistakes
            if characters == "\u{7F}" || characters == "\u{08}" {
                buffer.handleBackspace()
                if let ts = iso.date(from: event.ts) {
                    buffer.lastKeyDownTime = ts
                }
                continue
            }

            // Only letters and apostrophes are allowed in words.
            // Everything else (spaces, punctuation, digits, symbols) is a word boundary.
            guard Self.isAllowedInWord(characters) else {
                if let word = buffer.finalize() {
                    words.append(word)
                }
                buffer = WordBuffer()
                continue
            }

            if let ts = iso.date(from: event.ts) {
                if buffer.firstKeyDownTime == nil {
                    buffer.firstKeyDownTime = ts
                }
                buffer.lastKeyDownTime = ts
            }
            buffer.text.append(characters)
        }

        if let word = buffer.finalize() {
            words.append(word)
        }

        let filtered = words.filter { word in
            guard word.characters > 1 else { return false }
            let scalars = word.word.unicodeScalars
            let isPunctuationOnly = scalars.allSatisfy {
                CharacterSet.punctuationCharacters.contains($0) || CharacterSet.symbols.contains($0)
            }
            return !isPunctuationOnly
        }

        return WordExtractionResult(
            extractedAt: TimestampFormatter.string(from: extractionDate),
            totalWords: filtered.count,
            words: filtered
        )
    }
}

private struct WordBuffer {
    var text: String = ""
    var mistakeCount: Int = 0
    var firstKeyDownTime: Date?
    var lastKeyDownTime: Date?
    var lastKeyUpTime: Date?

    var hasContent: Bool { !text.isEmpty || mistakeCount > 0 }

    mutating func handleBackspace() {
        if !text.isEmpty {
            text.removeLast()
        }
        mistakeCount += 1
    }

    func finalize() -> ExtractedWord? {
        // Trim leading/trailing apostrophes (keep internal ones like don't)
        let trimmed = text.trimmingCharacters(in: CharacterSet(charactersIn: "'\u{2019}"))
        guard !trimmed.isEmpty else { return nil }

        let endTime = lastKeyUpTime ?? lastKeyDownTime
        let durationMs: Double
        if let start = firstKeyDownTime, let end = endTime {
            durationMs = end.timeIntervalSince(start) * 1000.0
        } else {
            durationMs = 0
        }

        return ExtractedWord(
            word: trimmed,
            characters: trimmed.count,
            durationMs: durationMs,
            mistakeCount: mistakeCount
        )
    }
}
