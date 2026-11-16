import XCTest
@testable import SessionLens

final class UnifiedDiffParserTests: XCTestCase {

    private let sample = """
    diff --git a/Foo.swift b/Foo.swift
    index 111..222 100644
    --- a/Foo.swift
    +++ b/Foo.swift
    @@ -1,4 +1,5 @@
     context one
    -removed line
    +added line
    +another add
     context two
    diff --git a/Old.swift b/New.swift
    similarity index 90%
    rename from Old.swift
    rename to New.swift
    --- a/Old.swift
    +++ b/New.swift
    @@ -1 +1 @@
    -old
    +new
    """

    func testParsesFileHeaders() {
        let files = UnifiedDiffParser.parse(sample)
        XCTAssertEqual(files.count, 2)
        XCTAssertEqual(files[0].oldPath, "Foo.swift")
        XCTAssertEqual(files[0].newPath, "Foo.swift")
        XCTAssertFalse(files[0].isRename)
    }

    func testDetectsRename() {
        let files = UnifiedDiffParser.parse(sample)
        XCTAssertTrue(files[1].isRename)
        XCTAssertEqual(files[1].oldPath, "Old.swift")
        XCTAssertEqual(files[1].newPath, "New.swift")
    }

    func testHunkLinesAndNumbers() {
        let files = UnifiedDiffParser.parse(sample)
        let hunk = files[0].hunks[0]
        XCTAssertEqual(hunk.oldStart, 1)
        XCTAssertEqual(hunk.newStart, 1)
        XCTAssertEqual(hunk.lines.count, 5)
        XCTAssertEqual(hunk.added, 2)
        XCTAssertEqual(hunk.removed, 1)

        let remove = hunk.lines[1]
        XCTAssertEqual(remove.kind, .remove)
        XCTAssertEqual(remove.oldNumber, 2)
        XCTAssertNil(remove.newNumber)
        XCTAssertEqual(remove.text, "removed line")

        let add = hunk.lines[2]
        XCTAssertEqual(add.kind, .add)
        XCTAssertEqual(add.newNumber, 2)
        XCTAssertNil(add.oldNumber)

        let ctx = hunk.lines[0]
        XCTAssertEqual(ctx.kind, .context)
        XCTAssertEqual(ctx.oldNumber, 1)
        XCTAssertEqual(ctx.newNumber, 1)
    }

    func testNewAndDeletedFiles() {
        let text = """
        diff --git a/Gone.swift b/Gone.swift
        deleted file mode 100644
        --- a/Gone.swift
        +++ /dev/null
        @@ -1,1 +0,0 @@
        -bye
        diff --git a/Brand.swift b/Brand.swift
        new file mode 100644
        --- /dev/null
        +++ b/Brand.swift
        @@ -0,0 +1,1 @@
        +hi
        """
        let files = UnifiedDiffParser.parse(text)
        XCTAssertEqual(files.count, 2)
        XCTAssertTrue(files[0].isDeleted)
        XCTAssertTrue(files[1].isNew)
        XCTAssertEqual(files[1].hunks[0].lines[0].kind, .add)
        XCTAssertEqual(files[1].hunks[0].lines[0].newNumber, 1)
    }

    func testMultipleHunks() {
        let text = """
        diff --git a/M.swift b/M.swift
        --- a/M.swift
        +++ b/M.swift
        @@ -1,2 +1,2 @@
         a
        -b
        +c
        @@ -10,2 +10,3 @@
         d
        +e
         f
        """
        let files = UnifiedDiffParser.parse(text)
        XCTAssertEqual(files[0].hunks.count, 2)
        XCTAssertEqual(files[0].hunks[1].oldStart, 10)
        XCTAssertEqual(files[0].hunks[1].lines[1].kind, .add)
        XCTAssertEqual(files[0].hunks[1].lines[1].newNumber, 11)
    }

    func testNoNewlineMarker() {
        let text = """
        diff --git a/N.swift b/N.swift
        --- a/N.swift
        +++ b/N.swift
        @@ -1 +1 @@
        -old
        \\ No newline at end of file
        +new
        \\ No newline at end of file
        """
        let files = UnifiedDiffParser.parse(text)
        XCTAssertTrue(files[0].hunks[0].lines[0].text.contains("No newline"))
    }

    func testDemoDiffParses() {
        let files = UnifiedDiffParser.parse(DemoFixture.sampleDiff)
        XCTAssertEqual(files.count, 4)
        XCTAssertTrue(files[1].isRename)
        XCTAssertTrue(files[2].isDeleted)
        XCTAssertFalse(files[2].isNew)
        XCTAssertTrue(files[3].isNew)
        XCTAssertFalse(files[3].isDeleted)
        XCTAssertEqual(files[0].hunks[0].added, 4)
        XCTAssertEqual(files[0].hunks[0].removed, 0)
    }

    func testEmptyInput() {
        XCTAssertTrue(UnifiedDiffParser.parse("").isEmpty)
    }
}
