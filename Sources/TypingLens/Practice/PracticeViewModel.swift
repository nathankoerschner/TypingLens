import Foundation

final class PracticeViewModel: ObservableObject {
    @Published var promptWords: [String]
    @Published var currentInput: String = ""
    @Published var submittedWords: [String] = []
    @Published var startedAt: Date?
    @Published var finishedAt: Date?

    private let now: () -> Date
    private let onNewPrompt: () -> Void

    private var totalExpectedCharactersTyped: Int = 0
    private var accuracyCorrectCharacters: Int = 0
    private var accuracyTotalCharacters: Int = 0

    init(
        prompt: PracticePrompt,
        now: @escaping () -> Date = Date.init,
        onNewPrompt: @escaping () -> Void = {}
    ) {
        self.promptWords = prompt.words
        self.now = now
        self.onNewPrompt = onNewPrompt
    }

    var currentWordIndex: Int {
        submittedWords.count
    }

    var isFinished: Bool {
        currentWordIndex >= promptWords.count
    }

    var progressLabel: String {
        "\(min(currentWordIndex, promptWords.count)) / \(promptWords.count)"
    }

    var wpm: Double {
        guard currentWordIndex > 0 else { return 0 }
        guard let startedAt else { return 0 }

        let endTime = finishedAt ?? now()
        let elapsed = endTime.timeIntervalSince(startedAt)
        guard elapsed > 0 else { return 0 }

        return Double(totalExpectedCharactersTyped) / 5.0 / (elapsed / 60.0)
    }

    var accuracy: Double {
        guard accuracyTotalCharacters > 0 else { return 100 }
        return (Double(accuracyCorrectCharacters) / Double(accuracyTotalCharacters)) * 100
    }

    func handleTypedCharacter(_ character: Character) {
        guard !isFinished else {
            currentInput = ""
            return
        }

        if character.isWhitespace || character.isNewline {
            submitCurrentWord()
            return
        }

        currentInput.append(character)
    }

    func handleBackspace() {
        guard !currentInput.isEmpty else { return }
        currentInput.removeLast()
    }

    func submitCurrentWord() {
        guard !isFinished else { return }

        let expectedWord = promptWords[currentWordIndex]
        let typedWord = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        currentInput = ""

        guard !typedWord.isEmpty else { return }

        if startedAt == nil {
            startedAt = now()
        }

        let (correct, total) = typedCharacterComparison(expected: expectedWord, typed: typedWord)
        accuracyCorrectCharacters += correct
        accuracyTotalCharacters += total
        totalExpectedCharactersTyped += expectedWord.count
        submittedWords.append(typedWord)

        if isFinished {
            finishedAt = now()
        }
    }

    func restart() {
        currentInput = ""
        submittedWords.removeAll()
        startedAt = nil
        finishedAt = nil
        totalExpectedCharactersTyped = 0
        accuracyCorrectCharacters = 0
        accuracyTotalCharacters = 0
    }

    func requestNewPrompt() {
        onNewPrompt()
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
