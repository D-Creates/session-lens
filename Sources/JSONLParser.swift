import Foundation

/// Parses JSONL chat-log text into log events. Pure function, no I/O.
enum JSONLParser {

    struct Result: Equatable, Sendable {
        var events: [LogEvent]
        var skippedLines: Int
    }

    static func parse(text: String, sourceFile: String) -> Result {
        var events: [LogEvent] = []
        var skipped = 0
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        for (index, rawLine) in lines.enumerated() {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty else { continue }
            guard let data = line.data(using: .utf8),
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                skipped += 1
                continue
            }
            events.append(makeEvent(obj: obj, sourceFile: sourceFile, lineNumber: index + 1, raw: line))
        }
        return Result(events: events, skippedLines: skipped)
    }

    private static func makeEvent(obj: [String: Any], sourceFile: String, lineNumber: Int, raw: String) -> LogEvent {
        let kind = classify(obj: obj)
        let timestamp = parseTimestamp(obj: obj)
        let summary = makeSummary(obj: obj, kind: kind)
        return LogEvent(
            id: "\(sourceFile)#\(lineNumber)",
            sourceFile: sourceFile,
            lineNumber: lineNumber,
            timestamp: timestamp,
            kind: kind,
            summary: summary,
            detail: raw
        )
    }

    private static func classify(obj: [String: Any]) -> LogEvent.EventKind {
        if let type = obj["type"] as? String {
            switch type.lowercased() {
            case "user", "human": return .user
            case "assistant", "ai", "model": return .assistant
            case "tool_call", "toolcall", "tool_use", "function_call": return .toolCall
            case "tool_result", "toolresult", "function_response", "tool": return .toolResult
            case "system": return .system
            default: break
            }
        }
        if let role = obj["role"] as? String {
            switch role.lowercased() {
            case "user": return .user
            case "assistant": return .assistant
            case "tool": return .toolResult
            case "system": return .system
            default: break
            }
        }
        if obj["tool"] != nil || obj["tool_name"] != nil || obj["name"] as? String != nil && obj["arguments"] != nil {
            return .toolCall
        }
        return .other
    }

    private static func parseTimestamp(obj: [String: Any]) -> Date? {
        let candidates = ["timestamp", "time", "ts", "created_at", "createdAt", "date"]
        for key in candidates {
            if let value = obj[key] {
                if let interval = value as? Double { return Date(timeIntervalSince1970: interval) }
                if let interval = value as? Int { return Date(timeIntervalSince1970: TimeInterval(interval)) }
                if let str = value as? String {
                    let iso = ISO8601DateFormatter()
                    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                    if let d = iso.date(from: str) { return d }
                    iso.formatOptions = [.withInternetDateTime]
                    if let d = iso.date(from: str) { return d }
                    if let n = Double(str) { return Date(timeIntervalSince1970: n) }
                }
            }
        }
        return nil
    }

    private static func makeSummary(obj: [String: Any], kind: LogEvent.EventKind) -> String {
        // Tool name first when present.
        if let name = (obj["tool_name"] as? String) ?? (obj["tool"] as? String) ?? (obj["name"] as? String) {
            let args = (obj["arguments"] as? String) ?? (obj["input"] as? String) ?? ""
            let short = String(args.prefix(120))
            return short.isEmpty ? "Tool call: \(name)" : "Tool call: \(name) — \(short)"
        }
        if let name = obj["name"] as? String, obj["type"] as? String == "tool_result" {
            return "Tool result: \(name)"
        }
        // Message / content text.
        for key in ["message", "content", "text", "prompt", "response"] {
            if let value = obj[key] {
                if let str = value as? String {
                    return String(str.prefix(160))
                }
                if let parts = value as? [[String: Any]] {
                    let joined = parts.compactMap { part -> String? in
                        if let t = part["text"] as? String { return t }
                        if let c = part["content"] as? String { return c }
                        return nil
                    }.joined(separator: " ")
                    if !joined.isEmpty { return String(joined.prefix(160)) }
                }
                if let dict = value as? [String: Any], let t = dict["text"] as? String {
                    return String(t.prefix(160))
                }
            }
        }
        let label: String
        switch kind {
        case .user: label = "User"
        case .assistant: label = "Assistant"
        case .toolCall: label = "Tool call"
        case .toolResult: label = "Tool result"
        case .system: label = "System"
        case .other: label = "Event"
        }
        if let type = obj["type"] as? String { return "\(label) (\(type))" }
        return label
    }
}
