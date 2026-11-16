import Foundation

/// One parsed line of a JSONL chat log.
struct LogEvent: Identifiable, Equatable, Sendable {
    let id: String
    let sourceFile: String
    let lineNumber: Int
    let timestamp: Date?
    let kind: EventKind
    let summary: String
    let detail: String

    enum EventKind: String, Sendable, CaseIterable {
        case user
        case assistant
        case toolCall = "tool_call"
        case toolResult = "tool_result"
        case system
        case other
    }
}

/// A timeline row: an ordered log event.
struct TimelineItem: Identifiable, Equatable, Sendable {
    let id: String
    let event: LogEvent

    var sortKey: (Date?, String, Int) {
        (event.timestamp, event.sourceFile, event.lineNumber)
    }
}

/// One file inside a unified diff.
struct DiffFile: Identifiable, Equatable, Sendable {
    let id: String
    var oldPath: String
    var newPath: String
    var isRename: Bool
    var isNew: Bool
    var isDeleted: Bool
    var hunks: [DiffHunk]

    var displayPath: String { newPath.isEmpty ? oldPath : newPath }
    var changeCount: Int { hunks.reduce(0) { $0 + $1.added + $1.removed } }
}

struct DiffHunk: Equatable, Sendable {
    var oldStart: Int
    var oldCount: Int
    var newStart: Int
    var newCount: Int
    var header: String
    var lines: [DiffLine]

    var added: Int { lines.filter { $0.kind == .add }.count }
    var removed: Int { lines.filter { $0.kind == .remove }.count }
}

struct DiffLine: Equatable, Sendable {
    enum Kind: String, Sendable { case context, add, remove }
    var kind: Kind
    var oldNumber: Int?
    var newNumber: Int?
    var text: String
}

/// A discovered session log file.
struct SessionFile: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    var eventCount: Int
    var skippedLines: Int

    var name: String { url.lastPathComponent }
}

/// A discovered unified-diff file.
struct DiffSourceFile: Identifiable, Equatable, Sendable {
    let id: String
    let url: URL
    var fileCount: Int

    var name: String { url.lastPathComponent }
}
