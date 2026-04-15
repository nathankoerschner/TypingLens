import Foundation

enum WordLexiconError: LocalizedError, Equatable {
    case resourceNotFound(String)
    case unreadableResource(String)

    var errorDescription: String? {
        switch self {
        case let .resourceNotFound(name):
            return "Missing lexicon resource: \(name).txt"
        case let .unreadableResource(name):
            return "Could not read lexicon resource: \(name).txt"
        }
    }
}

struct WordLexicon {
    let words: [String]
    private let membership: Set<String>
    private let rankByWord: [String: Int]

    init(orderedWords: [String]) {
        self.words = orderedWords
        self.membership = Set(orderedWords)

        var ranks: [String: Int] = [:]
        for (index, word) in orderedWords.enumerated() {
            if ranks[word] == nil {
                ranks[word] = index
            }
        }
        self.rankByWord = ranks
    }

    init(bundle: Bundle = .module, resourceName: String = "common-words-en") throws {
        guard let url = bundle.url(forResource: resourceName, withExtension: "txt") else {
            throw WordLexiconError.resourceNotFound(resourceName)
        }

        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let orderedWords = content
                .split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            self.init(orderedWords: orderedWords)
        } catch {
            throw WordLexiconError.unreadableResource(resourceName)
        }
    }

    func contains(_ word: String) -> Bool {
        membership.contains(word)
    }

    func commonnessRank(for word: String) -> Int {
        rankByWord[word] ?? Int.max
    }
}
