import XCTest
@testable import SessionLens

final class TimelineBuilderTests: XCTestCase {

    private func event(_ file: String, _ line: Int, _ ts: Date?) -> LogEvent {
        LogEvent(id: "\(file)#\(line)", sourceFile: file, lineNumber: line,
                 timestamp: ts, kind: .other, summary: "s", detail: "d")
    }

    func testOrdersByTimestamp() {
        let t1 = Date(timeIntervalSince1970: 100)
        let t2 = Date(timeIntervalSince1970: 50)
        let events = [
            event("b.jsonl", 1, t1),
            event("a.jsonl", 1, t2),
        ]
        let timeline = TimelineBuilder.build(events: events)
        XCTAssertEqual(timeline[0].event.sourceFile, "a.jsonl")
        XCTAssertEqual(timeline[1].event.sourceFile, "b.jsonl")
    }

    func testStableTieBreakByFileAndLine() {
        let events = [
            event("b.jsonl", 2, nil),
            event("a.jsonl", 9, nil),
            event("a.jsonl", 1, nil),
        ]
        let timeline = TimelineBuilder.build(events: events)
        XCTAssertEqual(timeline.map { $0.id }, ["a.jsonl#1", "a.jsonl#9", "b.jsonl#2"])
    }

    func testNilTimestampsSortFirst() {
        let t = Date(timeIntervalSince1970: 10)
        let events = [
            event("a.jsonl", 1, t),
            event("b.jsonl", 1, nil),
        ]
        let timeline = TimelineBuilder.build(events: events)
        XCTAssertEqual(timeline[0].event.sourceFile, "b.jsonl")
    }
}
