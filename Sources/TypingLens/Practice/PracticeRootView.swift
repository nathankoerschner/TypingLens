import SwiftUI

struct PracticeRootView: View {
    @StateObject var viewModel: PracticeViewModel
    @State private var focusToken = UUID()
    private let onClose: () -> Void

    init(viewModel: PracticeViewModel, onClose: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: viewModel)
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            PracticeKeyCaptureView(
                isDisabled: viewModel.isFinished,
                focusToken: focusToken,
                onCharacter: { viewModel.handleTypedCharacter($0) },
                onBackspace: { viewModel.handleBackspace() }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            VStack(spacing: 24) {
                metricsRow
                promptView
                actionRow
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(32)
        .background(Color.black)
        .foregroundColor(.white)
        .contentShape(Rectangle())
        .onAppear {
            focusToken = UUID()
        }
        .onChange(of: viewModel.promptWords) { _ in
            focusToken = UUID()
        }
        .onTapGesture {
            focusToken = UUID()
        }
    }

    private var metricsRow: some View {
        HStack(spacing: 24) {
            metric("WPM", String(format: "%.1f", viewModel.wpm))
            metric("Accuracy", "\(Int(viewModel.accuracy.rounded()))%")
            metric("Progress", viewModel.progressLabel)
        }
        .font(.headline)
    }

    private var promptView: some View {
        renderedPrompt
            .font(.system(size: 34, weight: .regular, design: .monospaced))
            .multilineTextAlignment(.leading)
            .lineSpacing(10)
            .textSelection(.enabled)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            Button("Restart", action: viewModel.restart)
            Button("New Prompt", action: viewModel.requestNewPrompt)
            Button("Close", action: onClose)
        }
    }

    private var renderedPrompt: Text {
        guard !viewModel.promptWords.isEmpty else {
            return Text("No words available")
                .foregroundColor(Color.white.opacity(0.5))
        }

        var rendered = Text("")

        for index in viewModel.promptWords.indices {
            if index > 0 {
                rendered = rendered + Text(" ")
            }
            rendered = rendered + render(word: viewModel.promptWords[index], at: index)
        }

        return rendered
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundColor(Color.white.opacity(0.6))
            Text(value)
                .fontWeight(.bold)
        }
    }

    private func render(word: String, at index: Int) -> Text {
        if index < viewModel.currentWordIndex {
            return Text(word)
                .foregroundColor(Color.white.opacity(0.65))
        }

        if index > viewModel.currentWordIndex {
            return Text(word)
                .foregroundColor(Color.white.opacity(0.28))
        }

        return renderCurrentWord(word: word, typed: viewModel.currentInput)
    }

    private func renderCurrentWord(word: String, typed: String) -> Text {
        let targetChars = Array(word)
        let typedChars = Array(typed)
        let renderedCount = max(targetChars.count, typedChars.count)

        guard renderedCount > 0 else {
            return Text(word)
                .foregroundColor(.white)
        }

        var rendered = Text("")

        for index in 0..<renderedCount {
            if index < targetChars.count {
                let targetChar = targetChars[index]

                if index < typedChars.count {
                    let typedChar = typedChars[index]
                    let style: Color = typedChar == targetChar ? .green : .red

                    rendered = rendered + Text(String(targetChar))
                        .foregroundColor(style)
                } else {
                    rendered = rendered + Text(String(targetChar))
                        .foregroundColor(Color.white.opacity(0.45))
                }
            } else if index < typedChars.count {
                rendered = rendered + Text(String(typedChars[index]))
                    .foregroundColor(.red)
            }
        }

        return rendered
    }
}
