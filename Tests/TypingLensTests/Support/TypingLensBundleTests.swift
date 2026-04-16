import XCTest
@testable import TypingLens

final class TypingLensBundleTests: XCTestCase {
    func testResourcesBundleContainsBundledLexicon() {
        let url = TypingLensBundle.resources.url(forResource: "common-words-en", withExtension: "txt")
        XCTAssertNotNil(url)
    }

    func testWordLexiconLoadsFromDefaultBundle() throws {
        let lexicon = try WordLexicon()
        XCTAssertTrue(lexicon.contains("the"))
    }
}
