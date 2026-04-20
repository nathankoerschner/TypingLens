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
        XCTAssertTrue(lexicon.contains("favorite"))
        XCTAssertTrue(lexicon.contains("awesome"))
        XCTAssertTrue(lexicon.contains("typing"))
        XCTAssertTrue(lexicon.contains("practice"))
    }

    func testBundledLexiconHasExpectedSize() throws {
        let lexicon = try WordLexicon()
        XCTAssertEqual(lexicon.words.count, 10_000)
        XCTAssertEqual(Set(lexicon.words).count, 10_000)
    }
}
