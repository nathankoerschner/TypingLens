import Foundation

struct WordRanker {
    struct Weights: Equatable {
        var speed: Double = 1.0
        var error: Double = 1.0
        var frequency: Double = 1.0
    }

    func rank(
        _ words: [ExtractedWord],
        weights: Weights = Weights(),
        at analysisDate: Date = Date()
    ) -> RankedWordResult {
        let grouped = groupByWord(words)
        let cleaned = grouped.compactMapValues { removeOutliers(from: $0) }
            .filter { !$0.value.isEmpty }
        let aggregated = cleaned.map { aggregate(key: $0.key, group: $0.value) }

        guard !aggregated.isEmpty else {
            return RankedWordResult(
                analyzedAt: TimestampFormatter.string(from: analysisDate),
                totalUniqueWords: 0,
                words: []
            )
        }

        let normalized = normalize(aggregated)
        let scored = score(normalized, weights: weights)
        let sorted = scored.sorted { $0.compositeScore > $1.compositeScore }

        return RankedWordResult(
            analyzedAt: TimestampFormatter.string(from: analysisDate),
            totalUniqueWords: sorted.count,
            words: sorted
        )
    }

    func rank(
        _ words: [InterpretedWord],
        weights: Weights = Weights(),
        at analysisDate: Date = Date()
    ) -> RankedWordResult {
        let reconstructed = words.map { word in
            ExtractedWord(
                word: word.normalizedWord,
                characters: word.characters,
                durationMs: word.durationMs,
                mistakeCount: word.transcriptMistakeCount + word.inferredSpellingPenalty
            )
        }

        return rank(reconstructed, weights: weights, at: analysisDate)
    }

    // MARK: - Pipeline Steps

    private func groupByWord(_ words: [ExtractedWord]) -> [String: [ExtractedWord]] {
        Dictionary(grouping: words) { $0.word.lowercased() }
    }

    private func removeOutliers(from group: [ExtractedWord]) -> [ExtractedWord] {
        guard group.count >= 3 else { return group }

        let durations = group.map(\.durationMs)
        let mean = durations.reduce(0, +) / Double(durations.count)
        let variance = durations.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(durations.count)
        let stddev = sqrt(variance)

        let sortedDurations = durations.sorted()
        let secondLargestDuration = sortedDurations[sortedDurations.count - 2]
        let durationCutoff = min(mean + 2 * stddev, secondLargestDuration * 2)

        return group.filter { word in
            let durationOk = word.durationMs <= durationCutoff
            let mistakeOk = word.mistakeCount <= 2 * word.characters
            return durationOk && mistakeOk
        }
    }

    private struct AggregatedWord {
        let word: String
        let characters: Int
        let frequency: Int
        let avgMsPerChar: Double
        let errorRate: Double
    }

    private func aggregate(key: String, group: [ExtractedWord]) -> AggregatedWord {
        let frequency = group.count
        let totalMsPerChar = group.map { $0.durationMs / Double($0.characters) }.reduce(0, +)
        let avgMsPerChar = totalMsPerChar / Double(frequency)
        let totalMistakes = group.map(\.mistakeCount).reduce(0, +)
        let totalChars = group.map(\.characters).reduce(0, +)
        let errorRate = totalChars > 0 ? Double(totalMistakes) / Double(totalChars) : 0

        return AggregatedWord(
            word: key,
            characters: group[0].characters,
            frequency: frequency,
            avgMsPerChar: avgMsPerChar,
            errorRate: errorRate
        )
    }

    private struct NormalizedWord {
        let word: String
        let characters: Int
        let frequency: Int
        let avgMsPerChar: Double
        let errorRate: Double
        let normSpeed: Double
        let normError: Double
        let normFrequency: Double
    }

    private func normalize(_ words: [AggregatedWord]) -> [NormalizedWord] {
        let speeds = words.map(\.avgMsPerChar)
        let errors = words.map(\.errorRate)
        let freqs = words.map { Double($0.frequency) }

        let speedRange = (speeds.max() ?? 0) - (speeds.min() ?? 0)
        let errorRange = (errors.max() ?? 0) - (errors.min() ?? 0)
        let freqRange = (freqs.max() ?? 0) - (freqs.min() ?? 0)

        let minSpeed = speeds.min() ?? 0
        let minError = errors.min() ?? 0
        let minFreq = freqs.min() ?? 0

        return words.map { w in
            NormalizedWord(
                word: w.word,
                characters: w.characters,
                frequency: w.frequency,
                avgMsPerChar: w.avgMsPerChar,
                errorRate: w.errorRate,
                normSpeed: speedRange > 0 ? (w.avgMsPerChar - minSpeed) / speedRange : 0,
                normError: errorRange > 0 ? (w.errorRate - minError) / errorRange : 0,
                normFrequency: freqRange > 0 ? (Double(w.frequency) - minFreq) / freqRange : 0
            )
        }
    }

    private func score(_ words: [NormalizedWord], weights: Weights) -> [RankedWord] {
        words.map { w in
            let composite = weights.speed * w.normSpeed
                + weights.error * w.normError
                + weights.frequency * w.normFrequency

            return RankedWord(
                word: w.word,
                characters: w.characters,
                frequency: w.frequency,
                avgMsPerChar: w.avgMsPerChar,
                errorRate: w.errorRate,
                compositeScore: composite
            )
        }
    }
}
