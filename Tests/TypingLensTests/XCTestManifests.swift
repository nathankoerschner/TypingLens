import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    [
        testCase(AppStateTests.allTests),
        testCase(TranscriptWriterTests.allTests),
    ]
}
#endif
