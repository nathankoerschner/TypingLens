import Foundation

struct PracticePrompt: Equatable {
    let words: [String]
}

struct PracticePromptBuilder {
    private let randomValue: () -> Double

    init(randomValue: @escaping () -> Double = { Double.random(in: 0..<1) }) {
        self.randomValue = randomValue
    }

    func build(from ranked: RankedWordResult, wordCount: Int = 50) -> PracticePrompt {
        let pool = Array(ranked.words.prefix(30))
        guard !pool.isEmpty, wordCount > 0 else {
            return PracticePrompt(words: [])
        }

        let weights = pool.map { max($0.compositeScore, 0.01) }
        var output: [String] = []

        while output.count < wordCount {
            let next = weightedPick(from: pool, weights: weights)
            if pool.count > 1, output.last == next.word {
                continue
            }
            output.append(next.word)
        }

        return PracticePrompt(words: output)
    }

    private func weightedPick(from pool: [RankedWord], weights: [Double]) -> RankedWord {
        let weightedPool = Array(zip(pool, weights))
        guard let first = weightedPool.first else { return pool[0] }

        let totalWeight = weightedPool.reduce(0) { total, weightedWord in
            total + max(weightedWord.1, 0.0)
        }
        let threshold = randomValue() * totalWeight

        var runningTotal = 0.0
        for (word, weight) in weightedPool {
            runningTotal += max(weight, 0.0)
            if threshold < runningTotal {
                return word
            }
        }

        return first.0
    }
}
