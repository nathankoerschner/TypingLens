import Foundation

struct MapTypoResolver: TypoResolver {
    private let corrections: [String: String]
    private let inferredPenalty: Int

    init(
        corrections: [String: String] = [
            "teh": "the",
            "becuase": "because",
            "wrod": "word"
        ],
        inferredPenalty: Int = 1
    ) {
        self.corrections = corrections
        self.inferredPenalty = inferredPenalty
    }

    func resolve(_ token: String) -> TypoResolution {
        guard let corrected = corrections[token] else {
            return .dropped(.notInLexicon)
        }

        return .corrected(corrected, inferredPenalty: inferredPenalty)
    }
}
