import Foundation

struct PracticeCommittedWord: Equatable {
    let expected: String
    let typed: String
}

struct PracticeSession: Equatable {
    let promptWords: [String]
    var committedWords: [PracticeCommittedWord]
    var currentInput: String
    var startedAt: Date?
    var finishedAt: Date?

    var currentWordIndex: Int {
        committedWords.count
    }

    var isFinished: Bool {
        currentWordIndex >= promptWords.count
    }
}

final class PracticeViewModel: ObservableObject {
    @Published private(set) var session: PracticeSession

    private let now: () -> Date
    private let onNewPrompt: () -> Void

    init(
        prompt: PracticePrompt,
        now: @escaping () -> Date = Date.init,
        onNewPrompt: @escaping () -> Void = {}
    ) {
        self.session = PracticeSession(
            promptWords: prompt.words,
            committedWords: [],
            currentInput: "",
            startedAt: nil,
            finishedAt: nil
        )
        self.now = now
        self.onNewPrompt = onNewPrompt
    }

    var promptWords: [String] { session.promptWords }
    var currentInput: String { session.currentInput }
    var submittedWords: [String] { session.committedWords.map(\.typed) }
    var startedAt: Date? { session.startedAt }
    var finishedAt: Date? { session.finishedAt }
    var currentWordIndex: Int { session.currentWordIndex }
    var isFinished: Bool { session.isFinished }

    var canRestorePreviousWord: Bool {
        guard session.currentInput.isEmpty else { return false }
        return !session.committedWords.isEmpty
    }

    var progressLabel: String {
        "\(min(currentWordIndex, promptWords.count)) / \(promptWords.count)"
    }

    var wpm: Double {
        guard currentWordIndex > 0 else { return 0 }
        guard let startedAt = session.startedAt else { return 0 }

        let endTime = session.finishedAt ?? now()
        let elapsed = endTime.timeIntervalSince(startedAt)
        guard elapsed > 0 else { return 0 }

        let expectedCharacterCount = session.committedWords.reduce(0) { partialResult, committed in
            partialResult + committed.expected.count
        }
        return Double(expectedCharacterCount) / 5.0 / (elapsed / 60.0)
    }

    var accuracy: Double {
        let (correct, total) = accuracyTotals()
        guard total > 0 else { return 100 }
        return (Double(correct) / Double(total)) * 100
    }

    var currentWordExpected: String {
        promptWords.indices.contains(currentWordIndex) ? promptWords[currentWordIndex] : ""
    }

    func handleInsert(_ character: Character) {
        if character.isWhitespace || character.isNewline {
            handleSubmit()
            return
        }

        guard !isFinished else { return }

        updateSession {
            $0.currentInput.append(character)
        }
    }

    func handleSubmit() {
        guard !session.isFinished else { return }
        let expectedWord = promptWords[currentWordIndex]

        let typedWord = session.currentInput.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !typedWord.isEmpty else {
            updateSession { session in
                session.currentInput = ""
            }
            return
        }

        updateSession { session in
            session.currentInput = ""

            if session.startedAt == nil {
                session.startedAt = now()
            }

            session.committedWords.append(
                PracticeCommittedWord(expected: expectedWord, typed: typedWord)
            )

            if session.isFinished {
                session.finishedAt = now()
            }
        }
    }

    func handleDeleteBackward() {
        guard !session.currentInput.isEmpty else {
            restorePreviousWordIfPossible()
            return
        }

        updateSession {
            _ = $0.currentInput.removeLast()
        }
    }

    func restart() {
        updateSession {
            $0.committedWords.removeAll()
            $0.currentInput = ""
            $0.startedAt = nil
            $0.finishedAt = nil
        }
    }

    func requestNewPrompt() {
        onNewPrompt()
    }

    // Backward-compatible API used by existing call sites and tests.
    func handleTypedCharacter(_ character: Character) {
        handleInsert(character)
    }

    func handleBackspace() {
        handleDeleteBackward()
    }

    private func restorePreviousWordIfPossible() {
        guard canRestorePreviousWord else {
            return
        }

        updateSession { session in
            guard let restored = session.committedWords.popLast() else { return }
            session.currentInput = restored.typed
            session.finishedAt = nil
        }
    }

    private func updateSession(_ update: (inout PracticeSession) -> Void) {
        var updated = session
        update(&updated)
        session = updated
    }

    private func accuracyTotals() -> (correct: Int, total: Int) {
        session.committedWords.reduce((0, 0)) { partial, committed in
            let comparison = typedCharacterComparison(
                expected: committed.expected,
                typed: committed.typed
            )
            return (partial.0 + comparison.correct, partial.1 + comparison.total)
        }
    }

    private func typedCharacterComparison(expected: String, typed: String) -> (correct: Int, total: Int) {
        let expectedChars = Array(expected)
        let typedChars = Array(typed)
        let maxCount = max(expectedChars.count, typedChars.count)

        if maxCount == 0 {
            return (0, 0)
        }

        var correctCount = 0
        for index in 0..<min(expectedChars.count, typedChars.count) {
            if expectedChars[index] == typedChars[index] {
                correctCount += 1
            }
        }

        return (correctCount, maxCount)
    }
}
