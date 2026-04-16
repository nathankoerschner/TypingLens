import Foundation

@MainActor
final class AnalyticsViewModel: ObservableObject {
    @Published private(set) var result: AnalyticsResult?
    @Published var selectedWordID: String?
    @Published private(set) var errorMessage: String?

    var onRefresh: () -> Void

    init(onRefresh: @escaping () -> Void = {}) {
        self.onRefresh = onRefresh
    }

    func show(result: AnalyticsResult) {
        let previousSelection = selectedWordID
        self.result = result
        errorMessage = nil

        if let previousSelection,
           result.words.contains(where: { $0.id == previousSelection }) {
            selectedWordID = previousSelection
        } else {
            selectedWordID = result.words.first?.id
        }
    }

    var subtitle: String {
        guard let result else { return "" }
        return "\(result.totalUniqueWords) unique words analyzed • \(result.analyzedAt)"
    }

    var selectedWord: AnalyticsWord? {
        guard let result, let selectedWordID else { return nil }
        return result.words.first(where: { $0.id == selectedWordID })
    }
}
