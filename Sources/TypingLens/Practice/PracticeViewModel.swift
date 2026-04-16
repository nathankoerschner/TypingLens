import Foundation

enum PracticeWordRole: Equatable {
    case submitted
    case active
    case upcoming
}

enum PracticeLetterRole: Equatable {
    case correct
    case incorrect
    case pending
    case extra
    case missing
}

struct PracticeLetterRenderState: Equatable, Identifiable {
    let id: Int
    let character: Character
    let role: PracticeLetterRole
}

struct PracticeWordRenderState: Equatable, Identifiable {
    let id: Int
    let wordIndex: Int
    let role: PracticeWordRole
    let letters: [PracticeLetterRenderState]
}

struct PracticeCaretState: Equatable {
    let wordIndex: Int
    let letterIndex: Int
}

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

    var canRestorePreviousWord: Bool {
        guard session.currentInput.isEmpty else { return false }
        return !session.committedWords.isEmpty
    }

    var wordRenderStates: [PracticeWordRenderState] {
        promptWords.enumerated().map { index, word in
            PracticeWordRenderState(
                id: index,
                wordIndex: index,
                role: wordRole(at: index),
                letters: wordRenderLetters(for: word, at: index)
            )
        }
    }

    var caretState: PracticeCaretState? {
        guard !session.promptWords.isEmpty else { return nil }
        guard !isFinished else { return nil }

        return PracticeCaretState(
            wordIndex: min(currentWordIndex, session.promptWords.count - 1),
            letterIndex: session.currentInput.count
        )
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
        guard !session.isFinished,
              let expectedWord = promptWords[safe: currentWordIndex] else { return }

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

    private func wordRole(at index: Int) -> PracticeWordRole {
        if index < session.committedWords.count {
            return .submitted
        }

        if index == session.currentWordIndex && !session.isFinished {
            return .active
        }

        return .upcoming
    }

    private func wordRenderLetters(for word: String, at index: Int) -> [PracticeLetterRenderState] {
        let expectedChars = Array(word)
        let role = wordRole(at: index)

        switch role {
        case .upcoming:
            return expectedChars.enumerated().map { offset, char in
                PracticeLetterRenderState(
                    id: offset,
                    character: char,
                    role: .pending
                )
            }

        case .active:
            let typedChars = Array(session.currentInput)
            let renderedCount = max(expectedChars.count, typedChars.count)

            guard renderedCount > 0 else {
                return []
            }

            return (0..<renderedCount).map { letterIndex in
                if letterIndex < expectedChars.count {
                    if letterIndex < typedChars.count {
                        let role: PracticeLetterRole =
                            typedChars[letterIndex] == expectedChars[letterIndex] ? .correct : .incorrect
                        return PracticeLetterRenderState(
                            id: letterIndex,
                            character: expectedChars[letterIndex],
                            role: role
                        )
                    }

                    return PracticeLetterRenderState(
                        id: letterIndex,
                        character: expectedChars[letterIndex],
                        role: .pending
                    )
                }

                return PracticeLetterRenderState(
                    id: letterIndex,
                    character: typedChars[letterIndex],
                    role: .extra
                )
            }

        case .submitted:
            let committedTyped = session.committedWords[safe: index].map { Array($0.typed) } ?? []
            let renderedCount = max(expectedChars.count, committedTyped.count)

            guard renderedCount > 0 else {
                return []
            }

            return (0..<renderedCount).map { letterIndex in
                if letterIndex < expectedChars.count {
                    if letterIndex < committedTyped.count {
                        let role: PracticeLetterRole =
                            committedTyped[letterIndex] == expectedChars[letterIndex] ? .correct : .incorrect
                        return PracticeLetterRenderState(
                            id: letterIndex,
                            character: expectedChars[letterIndex],
                            role: role
                        )
                    }

                    return PracticeLetterRenderState(
                        id: letterIndex,
                        character: expectedChars[letterIndex],
                        role: .missing
                    )
                }

                return PracticeLetterRenderState(
                    id: letterIndex,
                    character: committedTyped[letterIndex],
                    role: .extra
                )
            }
        }
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

private extension Array {
    subscript(safe index: Index) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
