import SwiftUI

struct PracticeRootView: View {
    @ObservedObject var viewModel: PracticeViewModel
    @State private var focusToken = UUID()
    private let onClose: () -> Void

    init(viewModel: PracticeViewModel, onClose: @escaping () -> Void = {}) {
        self.viewModel = viewModel
        self.onClose = onClose
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            PracticeKeyCaptureView(
                isDisabled: viewModel.isFinished,
                focusToken: focusToken,
                onInsert: { viewModel.handleInsert($0) },
                onSubmit: { viewModel.handleSubmit() },
                onDeleteBackward: { viewModel.handleDeleteBackward() }
            )
            .frame(width: 0, height: 0)

            VStack(spacing: 24) {
                metricsRow
                promptView
                Spacer(minLength: 0)
                actionRow
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(32)
        .background(TypingLensTheme.background)
        .foregroundColor(TypingLensTheme.text)
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
        HStack(spacing: 28) {
            MetricChip(label: "wpm", value: String(format: "%.1f", viewModel.wpm))
            MetricChip(label: "acc", value: "\(Int(viewModel.accuracy.rounded()))%")
            MetricChip(label: "words", value: viewModel.progressLabel)

            if viewModel.isFinished {
                Text("Finished")
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.primary)
                    .padding(.leading, 8)
            }
        }
        .font(.system(size: 16, weight: .medium, design: .monospaced))
    }

    private var promptView: some View {
        PracticeWordSurface(
            wordRenderStates: viewModel.wordRenderStates,
            caretState: viewModel.caretState
        )
        .font(.system(size: 36, weight: .regular, design: .monospaced))
        .multilineTextAlignment(.leading)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .layoutPriority(1)
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button("Restart", action: viewModel.restart)
                .buttonStyle(TypingLensFilledButtonStyle())
            Button("New Prompt", action: viewModel.requestNewPrompt)
                .buttonStyle(TypingLensFilledButtonStyle(backgroundColor: TypingLensTheme.primary, foregroundColor: TypingLensTheme.background))
            Button("Close", action: onClose)
                .buttonStyle(TypingLensFilledButtonStyle())
        }
    }

}

private struct MetricChip: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .textCase(.uppercase)
                .foregroundStyle(TypingLensTheme.subdued)
            Text(value)
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .foregroundStyle(TypingLensTheme.primary)
        }
    }
}

private struct PracticeWordSurface: View {
    let wordRenderStates: [PracticeWordRenderState]
    let caretState: PracticeCaretState?

    var body: some View {
        if wordRenderStates.isEmpty {
            Text("No words available")
                .foregroundColor(TypingLensTheme.subdued)
                .font(.system(size: 22, weight: .medium, design: .monospaced))
        } else {
            PracticeFlowLayout(horizontalSpacing: 12, verticalSpacing: 14) {
                ForEach(wordRenderStates) { word in
                    PracticeWordView(
                        wordRenderState: word,
                        caretState: caretState?.wordIndex == word.wordIndex ? caretState : nil
                    )
                    .equatable()
                }
            }
        }
    }
}

private struct PracticeWordView: View, Equatable {
    let wordRenderState: PracticeWordRenderState
    let caretState: PracticeCaretState?

    var body: some View {
        if caretState == nil {
            wordLetters
                .fixedSize()
        } else {
            measuredWordLetters
                .fixedSize()
        }
    }

    private var wordColor: Color {
        switch wordRenderState.role {
        case .submitted:
            return TypingLensTheme.text
        case .active:
            return TypingLensTheme.subdued
        case .upcoming:
            return TypingLensTheme.subdued.opacity(0.52)
        }
    }

    private var wordLetters: some View {
        HStack(spacing: 0) {
            ForEach(wordRenderState.letters) { letter in
                PracticeLetterView(
                    letter: letter,
                    wordRole: wordRenderState.role,
                    fallbackColor: wordColor
                )
            }
        }
    }

    private var measuredWordLetters: some View {
        let coordinateSpace = PracticeWordCoordinateSpace(wordIndex: wordRenderState.wordIndex)

        return HStack(spacing: 0) {
            ForEach(wordRenderState.letters) { letter in
                PracticeLetterView(
                    letter: letter,
                    wordRole: wordRenderState.role,
                    fallbackColor: wordColor
                )
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: PracticeLetterFrameKey.self,
                                value: [letter.id: proxy.frame(in: .named(coordinateSpace))]
                            )
                        }
                    )
            }
        }
        .coordinateSpace(name: coordinateSpace)
        .overlayPreferenceValue(PracticeLetterFrameKey.self) { frames in
            GeometryReader { geometry in
                if let caretState,
                   let caretX = caretX(from: frames, letterIndex: caretState.letterIndex, fallbackWidth: geometry.size.width) {
                    PracticeCaretView(caretHeight: geometry.size.height)
                        .offset(x: caretX, y: 0)
                }
            }
        }
    }

    private func caretX(from frames: [Int: CGRect], letterIndex: Int, fallbackWidth: CGFloat) -> CGFloat? {
        guard !wordRenderState.letters.isEmpty else {
            return 0
        }

        let clampedIndex = min(max(letterIndex, 0), wordRenderState.letters.count)

        if clampedIndex == 0 {
            return 0
        }

        if let targetFrame = frames[clampedIndex] {
            return targetFrame.minX
        }

        if let lastFrame = frames.values.max(by: { $0.minX < $1.minX }) {
            return lastFrame.maxX
        }

        return fallbackWidth
    }
}

private struct PracticeLetterView: View, Equatable {
    let letter: PracticeLetterRenderState
    let wordRole: PracticeWordRole
    let fallbackColor: Color

    var body: some View {
        Text(String(letter.character))
            .foregroundStyle(letterColor)
            .opacity(letterOpacity)
            .overlay(alignment: .bottom) {
                if underlineColor != .clear {
                    Rectangle()
                        .fill(underlineColor)
                        .frame(height: 2)
                        .offset(y: 3)
                }
            }
    }

    private var letterColor: Color {
        switch letter.role {
        case .correct:
            switch wordRole {
            case .active:
                return TypingLensTheme.text
            case .submitted:
                return TypingLensTheme.text
            case .upcoming:
                return fallbackColor
            }
        case .incorrect:
            return TypingLensTheme.error
        case .extra:
            return TypingLensTheme.errorMuted
        case .missing:
            return TypingLensTheme.subdued
        case .pending:
            return fallbackColor
        }
    }

    private var letterOpacity: Double {
        switch letter.role {
        case .correct:
            switch wordRole {
            case .active:
                return 1
            case .submitted:
                return 1
            case .upcoming:
                return 0.7
            }
        case .incorrect:
            return wordRole == .submitted ? 0.9 : 1
        case .extra:
            return wordRole == .submitted ? 0.82 : 0.95
        case .missing:
            return wordRole == .submitted ? 0.38 : 0.8
        case .pending:
            switch wordRole {
            case .active:
                return 0.88
            case .submitted:
                return 0.6
            case .upcoming:
                return 0.72
            }
        }
    }

    private var underlineColor: Color {
        switch letter.role {
        case .incorrect:
            return TypingLensTheme.error
        case .extra:
            return TypingLensTheme.errorMuted
        case .missing:
            return wordRole == .submitted ? TypingLensTheme.subdued.opacity(0.5) : .clear
        case .correct, .pending:
            return .clear
        }
    }
}

private struct PracticeCaretView: View {
    let caretHeight: CGFloat

    var body: some View {
        Rectangle()
            .fill(TypingLensTheme.primary)
            .frame(width: 2)
            .frame(height: max(caretHeight * 0.95, 24))
    }
}

private struct PracticeWordCoordinateSpace: Hashable {
    let wordIndex: Int
}

private struct PracticeFlowLayout: Layout {
    let horizontalSpacing: CGFloat
    let verticalSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let availableWidth = proposal.width ?? 10_000
        let rows = rowPlacements(for: subviews, availableWidth: availableWidth)

        guard !rows.isEmpty else { return .zero }
        let maxX = rows.map { $0.maxX }.max() ?? 0
        return CGSize(
            width: min(availableWidth, maxX),
            height: (rows.last?.bottom ?? 0)
        )
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let availableWidth = bounds.width > 0 ? bounds.width : 10_000
        let rows = rowPlacements(for: subviews, availableWidth: availableWidth)

        for (index, row) in rows.enumerated() {
            guard subviews.indices.contains(index) else { break }
            let targetPoint = CGPoint(x: bounds.minX + row.x, y: bounds.minY + row.y)
            let size = subviews[index].sizeThatFits(.unspecified)
            subviews[index].place(
                at: targetPoint,
                proposal: ProposedViewSize(width: size.width, height: size.height)
            )
        }
    }

    private func rowPlacements(for subviews: Subviews, availableWidth: CGFloat) -> [PlacedSubview] {
        var placements: [PlacedSubview] = []
        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let leadingSpacing = cursorX == 0 ? 0 : horizontalSpacing

            if cursorX + leadingSpacing + size.width > availableWidth && cursorX > 0 {
                cursorY += currentRowHeight + verticalSpacing
                cursorX = 0
                currentRowHeight = 0
            }

            let x = cursorX
            placements.append(
                PlacedSubview(x: x, y: cursorY, width: size.width, height: size.height)
            )

            cursorX += size.width
            if cursorX > 0 {
                cursorX += horizontalSpacing
            }
            currentRowHeight = max(currentRowHeight, size.height)
        }

        return placements
    }

    private struct PlacedSubview {
        let x: CGFloat
        let y: CGFloat
        let width: CGFloat
        let height: CGFloat

        var maxX: CGFloat { x + width }
        var bottom: CGFloat { y + height }
    }
}

private struct PracticeLetterFrameKey: PreferenceKey {
    static var defaultValue: [Int: CGRect] = [:]

    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { _, newest in newest })
    }
}
