import Foundation

struct WordInterpreter {
    let lexicon: WordLexicon
    let typoResolver: TypoResolver?

    init(
        lexicon: WordLexicon = try! WordLexicon(),
        typoResolver: TypoResolver? = MapTypoResolver()
    ) {
        self.lexicon = lexicon
        self.typoResolver = typoResolver
    }

    func interpret(_ words: [ExtractedWord]) -> WordInterpretationResult {
        // Pass 1: normalize and classify exact lexicon matches.
        var decisionCache: [String: WordDecision] = [:]
        decisionCache.reserveCapacity(min(words.count, 128))

        var unknownTokens = Set<String>()
        var normalizedWords: [(ExtractedWord, String)] = []
        normalizedWords.reserveCapacity(words.count)

        for word in words {
            let normalized = normalize(word.word)
            normalizedWords.append((word, normalized))

            if decisionCache[normalized] != nil {
                continue
            }

            if normalized.isEmpty {
                decisionCache[normalized] = .dropped(original: "", reason: .notInLexicon)
            } else if lexicon.contains(normalized) {
                decisionCache[normalized] = .accepted(word: normalized)
            } else {
                unknownTokens.insert(normalized)
            }
        }

        // Pass 2: resolve unknown tokens through a dedicated resolver.
        let unknownDecisions = resolveUnknownTokens(for: unknownTokens)
        decisionCache.merge(unknownDecisions) { current, _ in
            current
        }

        // Pass 3: build interpreted words from the resolved decision cache.
        var interpreted: [InterpretedWord] = []
        interpreted.reserveCapacity(words.count)

        var correctedCount = 0
        var droppedCount = 0

        for (word, normalized) in normalizedWords {
            let cachedDecision = decisionCache[normalized] ?? .dropped(original: "", reason: .notInLexicon)

            switch cachedDecision {
            case let .accepted(word: normalized):
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
            case let .dropped(_, reason):
                _ = reason
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
        let decision = decision(for: normalized)

        switch decision {
        case let .accepted(word: word):
            return .accepted(word: word)
        case let .corrected(_, corrected, inferredPenalty):
            return .corrected(
                original: word.word,
                corrected: corrected,
                inferredPenalty: inferredPenalty
            )
        case let .dropped(_, reason):
            return .dropped(original: word.word, reason: reason)
        }
    }

    private func decision(for normalized: String) -> WordDecision {
        if normalized.isEmpty {
            return .dropped(original: "", reason: .notInLexicon)
        }

        if lexicon.contains(normalized) {
            return .accepted(word: normalized)
        }

        return resolveUnknownTokens(for: [normalized])[normalized]
            ?? .dropped(original: "", reason: .notInLexicon)
    }

    private func resolveUnknownTokens(for tokens: Set<String>) -> [String: WordDecision] {
        var decisions: [String: WordDecision] = [:]

        for token in tokens {
            if shouldDropAsGibberish(token) {
                decisions[token] = .dropped(original: "", reason: .gibberishHeuristic)
                continue
            }

            guard let typoResolver else {
                decisions[token] = .dropped(original: "", reason: .notInLexicon)
                continue
            }

            switch typoResolver.resolve(token) {
            case let .corrected(corrected, inferredPenalty: inferredPenalty):
                decisions[token] = .corrected(
                    original: "",
                    corrected: corrected,
                    inferredPenalty: inferredPenalty
                )
            case let .dropped(reason):
                decisions[token] = .dropped(original: "", reason: reason)
            }
        }

        return decisions
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
                for start in 0...(characters.count - (chunkLength * 2)) {
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
