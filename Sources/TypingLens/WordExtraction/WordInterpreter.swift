import Foundation

struct WordInterpreter {
    private struct CandidateMatch {
        let word: String
        let distance: Int
        let commonnessRank: Int
        let isConfident: Bool
    }

    let lexicon: WordLexicon

    init(lexicon: WordLexicon = try! WordLexicon()) {
        self.lexicon = lexicon
    }

    func interpret(_ words: [ExtractedWord]) -> WordInterpretationResult {
        var interpreted: [InterpretedWord] = []
        var correctedCount = 0
        var droppedCount = 0

        for word in words {
            switch interpret(word) {
            case let .accepted(normalized):
                interpreted.append(
                    InterpretedWord(
                        originalWord: word.word,
                        normalizedWord: normalized,
                        characters: normalized.count,
                        durationMs: word.durationMs,
                        transcriptMistakeCount: word.mistakeCount,
                        inferredSpellingPenalty: 0,
                        wasCorrected: false
                    )
                )
            case let .corrected(_, corrected, inferredPenalty):
                correctedCount += 1
                interpreted.append(
                    InterpretedWord(
                        originalWord: word.word,
                        normalizedWord: corrected,
                        characters: corrected.count,
                        durationMs: word.durationMs,
                        transcriptMistakeCount: word.mistakeCount,
                        inferredSpellingPenalty: inferredPenalty,
                        wasCorrected: true
                    )
                )
            case .dropped:
                droppedCount += 1
            }
        }

        return WordInterpretationResult(
            words: interpreted,
            correctedCount: correctedCount,
            droppedCount: droppedCount
        )
    }

    func interpret(_ word: ExtractedWord) -> WordDecision {
        let normalized = normalize(word.word)

        if normalized.isEmpty {
            return .dropped(original: word.word, reason: .notInLexicon)
        }

        if lexicon.contains(normalized) {
            return .accepted(word: normalized)
        }

        if shouldDropAsGibberish(normalized) {
            return .dropped(original: word.word, reason: .gibberishHeuristic)
        }

        guard let match = bestCandidate(for: normalized) else {
            return .dropped(original: word.word, reason: .notInLexicon)
        }

        guard match.isConfident else {
            return .dropped(original: word.word, reason: .lowConfidenceCorrection)
        }

        return .corrected(
            original: word.word,
            corrected: match.word,
            inferredPenalty: 1
        )
    }

    private func bestCandidate(for token: String) -> CandidateMatch? {
        let maxDistance = allowedEditDistance(for: token)

        let candidates = lexicon.words.compactMap { candidate -> CandidateMatch? in
            guard let distance = DamerauLevenshtein.distance(
                between: token,
                and: candidate,
                maxDistance: maxDistance
            ) else {
                return nil
            }

            return CandidateMatch(
                word: candidate,
                distance: distance,
                commonnessRank: lexicon.commonnessRank(for: candidate),
                isConfident: false
            )
        }
        .sorted {
            if $0.distance != $1.distance {
                return $0.distance < $1.distance
            }
            return $0.commonnessRank < $1.commonnessRank
        }

        guard let best = candidates.first else { return nil }

        let secondBest = candidates.dropFirst().first
        let isUniqueBest = secondBest == nil
            || secondBest!.distance > best.distance
            || secondBest!.commonnessRank == best.commonnessRank

        return CandidateMatch(
            word: best.word,
            distance: best.distance,
            commonnessRank: best.commonnessRank,
            isConfident: isUniqueBest
        )
    }

    private func allowedEditDistance(for token: String) -> Int {
        switch token.count {
        case 0...1:
            return 0
        case 2...4:
            return 1
        default:
            return 2
        }
    }

    private func normalize(_ raw: String) -> String {
        raw
            .lowercased()
            .replacingOccurrences(of: "\u{2019}", with: "'")
            .trimmingCharacters(in: CharacterSet(charactersIn: "'"))
    }

    private func shouldDropAsGibberish(_ token: String) -> Bool {
        guard token.count >= 4 else { return false }

        let characters = Array(token)
        let uniqueCount = Set(characters).count
        let maxRunLength = longestRepeatedRun(in: characters)
        let vowelCount = characters.filter { "aeiouy".contains($0) }.count

        if maxRunLength >= 4 {
            return true
        }

        if token.count >= 6 && uniqueCount <= 2 {
            return true
        }

        if token.count >= 6 && vowelCount == 0 {
            return true
        }

        if hasRepeatedChunk(token) {
            return true
        }

        return false
    }

    private func longestRepeatedRun(in characters: [Character]) -> Int {
        guard let first = characters.first else { return 0 }

        var currentRun = 1
        var maxRun = 1
        var previous = first

        for character in characters.dropFirst() {
            if character == previous {
                currentRun += 1
                maxRun = max(maxRun, currentRun)
            } else {
                currentRun = 1
                previous = character
            }
        }

        return maxRun
    }

    private func hasRepeatedChunk(_ token: String) -> Bool {
        let characters = Array(token)
        let maxChunkLength = max(1, characters.count / 2)

        for chunkLength in 1...min(3, maxChunkLength) {
            guard chunkLength > 0 else { continue }

            if characters.count >= chunkLength * 2 {
                for start in 0...characters.count - (chunkLength * 2) {
                    let firstChunk = characters[start..<start + chunkLength]
                    let secondChunk = characters[start + chunkLength..<start + chunkLength * 2]
                    if firstChunk == secondChunk {
                        return true
                    }
                }
            }
        }

        return false
    }
}
