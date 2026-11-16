import XCTest
@testable import SessionLens

final class JSONLParserTests: XCTestCase {

    func testParsesAllValidLines() {
        let text = """
        {"type":"user","message":"hello"}
        {"type":"assistant","content":"hi there"}
        {"type":"tool_call","tool_name":"ls","arguments":"-la"}
        """
        let result = JSONLParser.parse(text: text, sourceFile: "a.jsonl")
        XCTAssertEqual(result.events.count, 3)
        XCTAssertEqual(result.skippedLines, 0)
    }

    func testSkipsBlankAndInvalidLines() {
        let text = """
        {"type":"user","message":"ok"}

        not json at all
        {"broken": }
        """
        let result = JSONLParser.parse(text: text, sourceFile: "a.jsonl")
        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.skippedLines, 2)
    }

    func testClassifiesEventKinds() {
        let text = """
        {"type":"user","message":"u"}
        {"role":"assistant","content":"a"}
        {"type":"tool_call","tool_name":"read","arguments":"{}"}
        {"type":"tool_result","name":"read","content":"done"}
        {"type":"system","message":"s"}
        {"foo":"bar"}
        """
        let result = JSONLParser.parse(text: text, sourceFile: "k.jsonl")
        let kinds = result.events.map { $0.kind }
        XCTAssertEqual(kinds, [.user, .assistant, .toolCall, .toolResult, .system, .other])
    }

    func testExtractsISOAndEpochTimestamps() {
        let text = """
        {"type":"user","message":"a","timestamp":"2026-11-13T09:02:11Z"}
        {"type":"user","message":"b","timestamp":1763000000}
        {"type":"user","message":"c"}
        """
        let result = JSONLParser.parse(text: text, sourceFile: "t.jsonl")
        XCTAssertNotNil(result.events[0].timestamp)
        XCTAssertNotNil(result.events[1].timestamp)
        XCTAssertNil(result.events[2].timestamp)
    }

    func testSummaries() {
        let text = """
        {"type":"user","message":"fix the bug"}
        {"type":"tool_call","tool_name":"edit_file","arguments":"path=x"}
        """
        let result = JSONLParser.parse(text: text, sourceFile: "s.jsonl")
        XCTAssertEqual(result.events[0].summary, "fix the bug")
        XCTAssertTrue(result.events[1].summary.contains("edit_file"))
        XCTAssertTrue(result.events[1].summary.contains("path=x"))
    }

    func testContentArraySummary() {
        let text = #"{"type":"assistant","content":[{"text":"hello world"}]}"#
        let result = JSONLParser.parse(text: text, sourceFile: "c.jsonl")
        XCTAssertEqual(result.events.first?.summary, "hello world")
    }

    func testDemoFixtureParses() {
        let result = JSONLParser.parse(text: DemoFixture.sampleJSONL, sourceFile: "demo.jsonl")
        XCTAssertEqual(result.events.count, 12)
        XCTAssertEqual(result.skippedLines, 1)
    }
}

final class JSONLParserEdgeCaseTests: XCTestCase {

    func testLineNumbersAndIDsCountBlankAndInvalidLines() {
        let text = "{\"type\":\"user\",\"message\":\"a\"}\n\nnot json\n   {\"type\":\"user\",\"message\":\"b\"}  \n"
        let result = JSONLParser.parse(text: text, sourceFile: "f.jsonl")
        XCTAssertEqual(result.events.map { $0.lineNumber }, [1, 4])
        XCTAssertEqual(result.events.map { $0.id }, ["f.jsonl#1", "f.jsonl#4"])
        XCTAssertEqual(result.skippedLines, 1)
        XCTAssertEqual(result.events[1].detail, #"{"type":"user","message":"b"}"#)
    }

    func testNonObjectJSONIsSkipped() {
        let text = "[1,2,3]\n42\n\"just a string\""
        let result = JSONLParser.parse(text: text, sourceFile: "n.jsonl")
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.skippedLines, 3)
    }

    func testEmptyTextProducesNothing() {
        let result = JSONLParser.parse(text: "", sourceFile: "e.jsonl")
        XCTAssertTrue(result.events.isEmpty)
        XCTAssertEqual(result.skippedLines, 0)
    }

    func testTypeAliasesAndRoleFallback() {
        let text = [
            #"{"type":"Human","message":"u"}"#,
            #"{"type":"ai","message":"a"}"#,
            #"{"type":"tool_use","input":"x"}"#,
            #"{"type":"function_response","content":"r"}"#,
            #"{"type":"unknown_kind","role":"tool"}"#,
            #"{"name":"grep","arguments":"-r foo"}"#,
        ].joined(separator: "\n")
        let kinds = JSONLParser.parse(text: text, sourceFile: "k.jsonl").events.map { $0.kind }
        XCTAssertEqual(kinds, [.user, .assistant, .toolCall, .toolResult, .toolResult, .toolCall])
    }

    func testTimestampFormatsAndAlternateKeys() {
        let text = [
            #"{"type":"user","message":"a","time":"1970-01-01T00:00:01.500Z"}"#,
            #"{"type":"user","message":"b","ts":"100"}"#,
            #"{"type":"user","message":"c","created_at":2.5}"#,
            #"{"type":"user","message":"d","timestamp":"not a date"}"#,
        ].joined(separator: "\n")
        let stamps = JSONLParser.parse(text: text, sourceFile: "t.jsonl").events.map { $0.timestamp?.timeIntervalSince1970 }
        XCTAssertEqual(stamps.count, 4)
        XCTAssertEqual(stamps[0] ?? -1, 1.5, accuracy: 0.001)
        XCTAssertEqual(stamps[1] ?? -1, 100, accuracy: 0.001)
        XCTAssertEqual(stamps[2] ?? -1, 2.5, accuracy: 0.001)
        XCTAssertNil(stamps[3])
    }

    func testLongMessageSummaryIsTruncated() {
        let long = String(repeating: "x", count: 300)
        let text = "{\"type\":\"user\",\"message\":\"\(long)\"}"
        let event = JSONLParser.parse(text: text, sourceFile: "l.jsonl").events.first
        XCTAssertEqual(event?.summary.count, 160)
        XCTAssertEqual(event?.detail, text)
    }

    func testFallbackSummaryLabels() {
        let text = [
            #"{"type":"user"}"#,
            #"{"role":"system"}"#,
            #"{"foo":"bar"}"#,
            #"{"tool":"ls"}"#,
        ].joined(separator: "\n")
        let summaries = JSONLParser.parse(text: text, sourceFile: "s.jsonl").events.map { $0.summary }
        XCTAssertEqual(summaries, ["User (user)", "System", "Event", "Tool call: ls"])
    }

    func testDiffFileDisplayPathAndChangeCount() {
        let hunk = DiffHunk(oldStart: 1, oldCount: 2, newStart: 1, newCount: 3, header: "@@", lines: [
            DiffLine(kind: .context, oldNumber: 1, newNumber: 1, text: "a"),
            DiffLine(kind: .remove, oldNumber: 2, newNumber: nil, text: "b"),
            DiffLine(kind: .add, oldNumber: nil, newNumber: 2, text: "c"),
            DiffLine(kind: .add, oldNumber: nil, newNumber: 3, text: "d"),
        ])
        XCTAssertEqual(hunk.added, 2)
        XCTAssertEqual(hunk.removed, 1)
        let deleted = DiffFile(id: "1", oldPath: "old.swift", newPath: "", isRename: false, isNew: false,
                               isDeleted: true, hunks: [hunk, hunk])
        XCTAssertEqual(deleted.displayPath, "old.swift")
        XCTAssertEqual(deleted.changeCount, 6)
        let renamed = DiffFile(id: "2", oldPath: "old.swift", newPath: "new.swift", isRename: true, isNew: false,
                               isDeleted: false, hunks: [])
        XCTAssertEqual(renamed.displayPath, "new.swift")
        XCTAssertEqual(renamed.changeCount, 0)
    }
}
