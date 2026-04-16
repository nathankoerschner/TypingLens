import SwiftUI

struct AnalyticsRootView: View {
    @ObservedObject var viewModel: AnalyticsViewModel
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if let result = viewModel.result {
                if result.words.isEmpty {
                    emptyState
                } else {
                    HSplitView {
                        analyticsTable(result.words)
                        detailPane
                    }
                }
            } else if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.error)
                    .padding(16)
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(TypingLensTheme.background)
        .foregroundStyle(TypingLensTheme.text)
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Analytics")
                    .font(.system(size: 22, weight: .semibold))
                Text(viewModel.subtitle)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(TypingLensTheme.subdued)
            }

            Spacer()

            HStack(spacing: 10) {
                Button("Refresh", action: viewModel.onRefresh)
                    .buttonStyle(TypingLensFilledButtonStyle())
                Button("Close", action: onClose)
                    .buttonStyle(
                        TypingLensFilledButtonStyle(
                            backgroundColor: TypingLensTheme.errorMuted,
                            foregroundColor: TypingLensTheme.text
                        )
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No analytics data available yet")
                .font(.system(size: 20, weight: .semibold))
            Text("Collect more typing data and open analytics again to populate the weakness table.")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundStyle(TypingLensTheme.subdued)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(32)
    }

    private var detailPane: some View {
        Group {
            if let selectedWord {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(selectedWord.word)
                            .font(.system(size: 28, weight: .semibold, design: .monospaced))

                        statRow("Rank", value: "#\(selectedWord.rank)")
                        statRow("Average WPM", value: selectedWord.overallWPM.formatted(.number.precision(.fractionLength(1))))
                        statRow("Average ms/char", value: selectedWord.avgMsPerChar.formatted(.number.precision(.fractionLength(1))))
                        statRow("Times typed", value: "\(selectedWord.frequency)")
                        statRow("Total errors", value: "\(selectedWord.totalErrors)")
                        statRow("Total misspellings", value: "\(selectedWord.misspellingCount)")
                        statRow("Weakness score", value: selectedWord.compositeScore.formatted(.number.precision(.fractionLength(3))))

                        if selectedWord.misspellings.isEmpty {
                            Text("No misspellings recorded")
                                .foregroundStyle(TypingLensTheme.subdued)
                                .font(.system(size: 12, weight: .regular, design: .monospaced))
                        } else {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Misspelling variants")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(TypingLensTheme.subdued)

                                ForEach(selectedWord.misspellings) { misspelling in
                                    HStack {
                                        Text(misspelling.typed)
                                        Spacer()
                                        Text("\(misspelling.count)")
                                    }
                                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            } else {
                Text("Select a word to view details")
                    .foregroundStyle(TypingLensTheme.subdued)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedWord: AnalyticsWord? {
        viewModel.selectedWord
    }

    private func analyticsTable(_ words: [AnalyticsWord]) -> some View {
        VStack(spacing: 10) {
            analyticsHeaderRow

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 6) {
                    ForEach(words) { word in
                        analyticsRow(word)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 10)
            }
        }
        .frame(minWidth: 540, maxHeight: .infinity, alignment: .top)
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(TypingLensTheme.panel)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(TypingLensTheme.panelElevated, lineWidth: 1)
        )
    }

    private var analyticsHeaderRow: some View {
        HStack(spacing: 12) {
            headerCell("Rank", width: 56, alignment: .trailing)
            headerCell("Word", minWidth: 120, alignment: .leading)
            headerCell("Weakness", width: 96, alignment: .trailing)
            headerCell("Errors", width: 64, alignment: .trailing)
            headerCell("Misspellings", width: 104, alignment: .trailing)
            headerCell("WPM", width: 72, alignment: .trailing)
            headerCell("Typed", width: 64, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
    }

    private func analyticsRow(_ word: AnalyticsWord) -> some View {
        let isSelected = viewModel.selectedWordID == word.id

        return Button {
            viewModel.selectedWordID = word.id
        } label: {
            HStack(spacing: 12) {
                rowCell("\(word.rank)", width: 56, alignment: .trailing, isSelected: isSelected)
                rowCell(word.word, minWidth: 120, alignment: .leading, isSelected: isSelected)
                rowCell(
                    word.compositeScore.formatted(.number.precision(.fractionLength(2))),
                    width: 96,
                    alignment: .trailing,
                    color: isSelected ? TypingLensTheme.background : TypingLensTheme.primary,
                    isSelected: isSelected
                )
                rowCell("\(word.totalErrors)", width: 64, alignment: .trailing, isSelected: isSelected)
                rowCell("\(word.misspellingCount)", width: 104, alignment: .trailing, isSelected: isSelected)
                rowCell(
                    word.overallWPM.formatted(.number.precision(.fractionLength(1))),
                    width: 72,
                    alignment: .trailing,
                    isSelected: isSelected
                )
                rowCell("\(word.frequency)", width: 64, alignment: .trailing, isSelected: isSelected)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? TypingLensTheme.primary : TypingLensTheme.panelElevated.opacity(0.42))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? TypingLensTheme.primary : TypingLensTheme.panelElevated, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func headerCell(
        _ text: String,
        width: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        alignment: Alignment
    ) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(TypingLensTheme.subdued)
            .frame(minWidth: minWidth, maxWidth: width ?? .infinity, alignment: alignment)
    }

    private func rowCell(
        _ text: String,
        width: CGFloat? = nil,
        minWidth: CGFloat? = nil,
        alignment: Alignment,
        color: Color = TypingLensTheme.text,
        isSelected: Bool
    ) -> some View {
        Text(text)
            .font(.system(size: 12, weight: isSelected ? .semibold : .regular, design: .monospaced))
            .foregroundStyle(isSelected ? TypingLensTheme.background : color)
            .lineLimit(1)
            .frame(minWidth: minWidth, maxWidth: width ?? .infinity, alignment: alignment)
    }

    private func statRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(TypingLensTheme.subdued)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(TypingLensTheme.text)
        }
    }
}
