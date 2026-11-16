import XCTest
@testable import SessionLens

final class SearchEngineTests: XCTestCase {

    private let items: [TimelineItem] = {
        let e1 = LogEvent(id: "1", sourceFile: "a.jsonl", lineNumber: 1, timestamp: nil,
                          kind: .user, summary: "Fix the login bug", detail: "{\"type\":\"user\"}")
        let e2 = LogEvent(id: "2", sourceFile: "b.jsonl", lineNumber: 4, timestamp: nil,
                          kind: .toolCall, summary: "Tool call: edit_file — path=Login.swift", detail: "{}")
        return TimelineBuilder.build(events: [e1, e2])
    }()

    func testEmptyQueryReturnsAll() {
        XCTAssertEqual(SearchEngine.filter(items, query: "").count, 2)
        XCTAssertEqual(SearchEngine.filter(items, query: "   ").count, 2)
    }

    func testCaseInsensitiveMatch() {
        XCTAssertEqual(SearchEngine.filter(items, query: "LOGIN").count, 2)
    }

    func testMatchOnDetailAndKind() {
        XCTAssertEqual(SearchEngine.filter(items, query: "tool_call").count, 1)
        XCTAssertEqual(SearchEngine.filter(items, query: "\"type\":\"user\"").count, 1)
    }

    func testNoMatch() {
        XCTAssertTrue(SearchEngine.filter(items, query: "zzz-no-match").isEmpty)
    }

    func testFileSearch() {
        let files = [
            SessionFile(id: "1", url: URL(fileURLWithPath: "/x/alpha.jsonl"), eventCount: 1, skippedLines: 0),
            SessionFile(id: "2", url: URL(fileURLWithPath: "/x/beta.jsonl"), eventCount: 2, skippedLines: 0),
        ]
        XCTAssertEqual(SearchEngine.filterFiles(files, query: "alpha").count, 1)
        XCTAssertEqual(SearchEngine.filterFiles(files, query: "").count, 2)
    }
}
