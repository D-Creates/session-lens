import Foundation
import Combine

/// App state: discovered session logs, timeline, diffs, selected folder.
@MainActor
final class Store: ObservableObject {
    @Published var rootURL: URL?
    @Published var sessionFiles: [SessionFile] = []
    @Published var events: [LogEvent] = []
    @Published var timeline: [TimelineItem] = []
    @Published var diffSources: [DiffSourceFile] = []
    @Published var diffFiles: [DiffFile] = []
    @Published var selectedTab: Int = 0
    @Published var searchQuery: String = ""
    @Published var statusMessage: String = "Choose a folder of session logs."
    @Published var isDemo: Bool = false
    @Published var preselectedDiffID: String?

    var filteredTimeline: [TimelineItem] {
        SearchEngine.filter(timeline, query: searchQuery)
    }

    func loadFolder(_ url: URL) {
        isDemo = false
        rootURL = url
        sessionFiles = []
        events = []
        timeline = []
        diffSources = []
        diffFiles = []
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else {
            statusMessage = "Cannot read folder."
            return
        }
        var jsonl: [URL] = []
        var diffs: [URL] = []
        var depth = 0
        for case let file as URL in enumerator {
            let res = (try? file.resourceValues(forKeys: [.isDirectoryKey])) 
            if res?.isDirectory == true {
                depth += 1
                if depth > 6 { enumerator.skipDescendants() }
                continue
            }
            let ext = file.pathExtension.lowercased()
            if ext == "jsonl" { jsonl.append(file) }
            if ext == "diff" || ext == "patch" { diffs.append(file) }
        }
        var allEvents: [LogEvent] = []
        var skippedTotal = 0
        for file in jsonl.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if let text = try? String(contentsOf: file, encoding: .utf8) {
                let result = JSONLParser.parse(text: text, sourceFile: file.lastPathComponent)
                allEvents.append(contentsOf: result.events)
                skippedTotal += result.skippedLines
                sessionFiles.append(SessionFile(
                    id: file.absoluteString,
                    url: file,
                    eventCount: result.events.count,
                    skippedLines: result.skippedLines
                ))
            }
        }
        events = allEvents
        timeline = TimelineBuilder.build(events: allEvents)
        for file in diffs.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            if let text = try? String(contentsOf: file, encoding: .utf8) {
                let parsed = UnifiedDiffParser.parse(text, sourcePrefix: file.lastPathComponent)
                diffFiles.append(contentsOf: parsed)
                diffSources.append(DiffSourceFile(id: file.absoluteString, url: file, fileCount: parsed.count))
            }
        }
        statusMessage = "\(sessionFiles.count) log file(s), \(allEvents.count) events (\(skippedTotal) skipped), \(diffFiles.count) changed file(s)."
    }

    func loadDemo() {
        isDemo = true
        rootURL = nil
        sessionFiles = []
        events = []
        timeline = []
        diffSources = []
        diffFiles = []
        let logs: [(String, String)] = [
            ("session-demo-01.jsonl", DemoFixture.sampleJSONL),
            ("session-demo-02.jsonl", DemoFixture.secondJSONL),
        ]
        var allEvents: [LogEvent] = []
        for (name, text) in logs {
            let result = JSONLParser.parse(text: text, sourceFile: name)
            allEvents.append(contentsOf: result.events)
            sessionFiles.append(SessionFile(
                id: name, url: URL(fileURLWithPath: "/demo/\(name)"),
                eventCount: result.events.count, skippedLines: result.skippedLines
            ))
        }
        events = allEvents
        timeline = TimelineBuilder.build(events: allEvents)
        let parsed1 = UnifiedDiffParser.parse(DemoFixture.sampleDiff, sourcePrefix: "demo.diff")
        let parsed2 = UnifiedDiffParser.parse(DemoFixture.secondDiff, sourcePrefix: "fix.diff")
        diffFiles = parsed1 + parsed2
        diffSources = [
            DiffSourceFile(id: "demo.diff", url: URL(fileURLWithPath: "/demo/demo.diff"), fileCount: parsed1.count),
            DiffSourceFile(id: "fix.diff", url: URL(fileURLWithPath: "/demo/fix.diff"), fileCount: parsed2.count),
        ]
        statusMessage = "Demo data loaded: \(sessionFiles.count) log file(s), \(allEvents.count) events, \(diffFiles.count) changed file(s)."
    }

    func runGitDiff() {
        guard let root = rootURL else { return }
        let result = GitRunner.diffWorkingTree(at: root)
        guard let text = result.output else {
            statusMessage = "git diff failed: \(result.error ?? "unknown error")"
            return
        }
        let parsed = UnifiedDiffParser.parse(text)
        diffFiles = parsed
        diffSources = [DiffSourceFile(id: "git-diff", url: root, fileCount: parsed.count)]
        statusMessage = "git diff: \(parsed.count) changed file(s)."
    }
}
