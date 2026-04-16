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
        PracticeWordSurface(
            wordRenderStates: viewModel.wordRenderStates,
            caretState: viewModel.caretState
        )
        .font(.system(size: 34, weight: .regular, design: .monospaced))
        .multilineTextAlignment(.leading)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .layoutPriority(1)
    }

    private var actionRow: some View {
        HStack(spacing: 16) {
            Button("Restart", action: viewModel.restart)
            Button("New Prompt", action: viewModel.requestNewPrompt)
            Button("Close", action: onClose)
        }
    }

    private func metric(_ label: String, _ value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundColor(Color.white.opacity(0.6))
            Text(value)
                .fontWeight(.bold)
        }
    }
}

private struct PracticeWordSurface: View {
    let wordRenderStates: [PracticeWordRenderState]
    let caretState: PracticeCaretState?

    var body: some View {
        if wordRenderStates.isEmpty {
            Text("No words available")
                .foregroundColor(Color.white.opacity(0.5))
                .font(.title3)
        } else {
            PracticeFlowLayout(horizontalSpacing: 12, verticalSpacing: 14) {
                ForEach(wordRenderStates) { word in
                    PracticeWordView(
                        wordRenderState: word,
                        caretState: caretState?.wordIndex == word.wordIndex ? caretState : nil
                    )
                }
            }
        }
    }
}

private struct PracticeWordView: View {
    let wordRenderState: PracticeWordRenderState
    let caretState: PracticeCaretState?

    var body: some View {
        let wordColor: Color = {
            switch wordRenderState.role {
            case .submitted:
                return Color.white.opacity(0.65)
            case .active:
                return .white
            case .upcoming:
                return Color.white.opacity(0.28)
            }
        }()

        let coordinateSpace = PracticeWordCoordinateSpace(wordIndex: wordRenderState.wordIndex)

        HStack(spacing: 0) {
            ForEach(wordRenderState.letters) { letter in
                PracticeLetterView(letter: letter, fallbackColor: wordColor)
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
        .fixedSize()
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

private struct PracticeLetterView: View {
    let letter: PracticeLetterRenderState
    let fallbackColor: Color

    var body: some View {
        Text(String(letter.character))
            .foregroundStyle(letterColor)
    }

    private var letterColor: Color {
        switch letter.role {
        case .correct:
            return .green
        case .incorrect:
            return .red
        case .extra:
            return .red
        case .missing:
            return fallbackColor
        case .pending:
            return fallbackColor
        }
    }
}

private struct PracticeCaretView: View {
    let caretHeight: CGFloat

    var body: some View {
        Rectangle()
            .fill(Color.yellow)
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
