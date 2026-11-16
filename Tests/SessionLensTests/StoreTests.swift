import XCTest
@testable import SessionLens

@MainActor
final class StoreTests: XCTestCase {

    func testLoadDemoPopulatesLogsTimelineAndDiffsIdempotently() {
        let store = Store()
        store.loadDemo()
        XCTAssertTrue(store.isDemo)
        XCTAssertNil(store.rootURL)
        XCTAssertEqual(store.sessionFiles.count, 2)
        XCTAssertEqual(store.events.count, 18)
        XCTAssertEqual(store.timeline.count, 18)
        XCTAssertEqual(store.diffSources.count, 2)
        XCTAssertEqual(store.diffFiles.count, 5)
        XCTAssertEqual(Set(store.diffFiles.map(\.id)).count, 5)

        // Calling loadDemo() again must replace, not duplicate, entries.
        store.loadDemo()
        XCTAssertEqual(store.sessionFiles.count, 2)
        XCTAssertEqual(store.events.count, 18)
        XCTAssertEqual(store.diffFiles.count, 5)
    }

    func testFilteredTimelineRespectsSearchQuery() {
        let store = Store()
        store.loadDemo()
        XCTAssertEqual(store.filteredTimeline.count, 18)

        store.searchQuery = "AuthHelpers.swift"
        XCTAssertEqual(store.filteredTimeline.count, 2)

        store.searchQuery = ""
        XCTAssertEqual(store.filteredTimeline.count, 18)
    }

    func testLoadFolderReadsJSONLAndDiffFiles() throws {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("SessionLensTests-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let logURL = tempDir.appendingPathComponent("run.jsonl")
        try #"{"type":"user","message":"hello folder"}"#.write(to: logURL, atomically: true, encoding: .utf8)

        let patchURL = tempDir.appendingPathComponent("change.patch")
        let patch = """
        diff --git a/A.swift b/A.swift
        --- a/A.swift
        +++ b/A.swift
        @@ -1 +1 @@
        -old
        +new
        """
        try patch.write(to: patchURL, atomically: true, encoding: .utf8)

        let store = Store()
        store.loadFolder(tempDir)
        XCTAssertFalse(store.isDemo)
        XCTAssertEqual(store.rootURL, tempDir)
        XCTAssertEqual(store.sessionFiles.count, 1)
        XCTAssertEqual(store.events.count, 1)
        XCTAssertEqual(store.diffSources.count, 1)
        XCTAssertEqual(store.diffFiles.count, 1)
        XCTAssertEqual(store.diffFiles.first?.displayPath, "A.swift")
    }

    func testLaunchArgumentsParseAllFlags() {
        let args = LaunchArguments.parse(["SessionLens", "-resetData", "-demo", "-tab=2", "-search=login", "-diff=1"])
        XCTAssertTrue(args.resetData)
        XCTAssertTrue(args.demo)
        XCTAssertEqual(args.tab, 2)
        XCTAssertEqual(args.search, "login")
        XCTAssertEqual(args.diffIndex, 1)
    }
}
