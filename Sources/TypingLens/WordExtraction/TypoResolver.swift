import Foundation

enum TypoResolution: Equatable {
    case corrected(String, inferredPenalty: Int)
    case dropped(DropReason)
}

protocol TypoResolver {
    func resolve(_ token: String) -> TypoResolution
}
