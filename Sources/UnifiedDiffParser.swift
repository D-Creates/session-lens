import Foundation

/// Parses unified-diff text (`diff -u`, `git diff`) into structured models.
/// Pure function, no I/O, no shell execution.
enum UnifiedDiffParser {

    static func parse(_ text: String, sourcePrefix: String = "diff") -> [DiffFile] {
        var files: [DiffFile] = []
        var current: DiffFile? = nil
        var hunk: DiffHunk? = nil
        var oldNo = 0
        var newNo = 0

        func flushHunk() {
            if var h = hunk {
                h.oldCount = max(h.oldCount, 0)
                h.newCount = max(h.newCount, 0)
                current?.hunks.append(h)
            }
            hunk = nil
        }
        func flushFile() {
            flushHunk()
            if let f = current { files.append(f) }
            current = nil
        }

        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(rawLine)
            if line.hasPrefix("diff --git ") {
                flushFile()
                let rest = line.dropFirst("diff --git ".count)
                // Format: a/<old> b/<new>
                let parts = rest.split(separator: " ")
                var oldP = ""
                var newP = ""
                for p in parts {
                    if p.hasPrefix("a/") { oldP = String(p.dropFirst(2)) }
                    if p.hasPrefix("b/") { newP = String(p.dropFirst(2)) }
                }
                current = DiffFile(
                    id: "\(sourcePrefix)#\(files.count)",
                    oldPath: oldP,
                    newPath: newP.isEmpty ? oldP : newP,
                    isRename: false, isNew: false, isDeleted: false,
                    hunks: []
                )
                continue
            }
            guard current != nil else { continue }

            if line.hasPrefix("rename from ") {
                flushHunk()
                current?.isRename = true
                current?.oldPath = String(line.dropFirst("rename from ".count))
                continue
            }
            if line.hasPrefix("rename to ") {
                current?.newPath = String(line.dropFirst("rename to ".count))
                continue
            }
            if line.hasPrefix("new file mode") {
                flushHunk()
                current?.isNew = true
                continue
            }
            if line.hasPrefix("deleted file mode") {
                flushHunk()
                current?.isDeleted = true
                continue
            }
            if line.hasPrefix("similarity index") || line.hasPrefix("dissimilarity index")
                || line.hasPrefix("index ") || line.hasPrefix("old mode") || line.hasPrefix("new mode")
                || line.hasPrefix("Binary files") {
                continue
            }
            if line.hasPrefix("--- ") {
                flushHunk()
                var p = String(line.dropFirst(4))
                if p == "/dev/null" { current?.isNew = true; p = "" }
                else if p.hasPrefix("a/") { p = String(p.dropFirst(2)) }
                current?.oldPath = p
                continue
            }
            if line.hasPrefix("+++ ") {
                var p = String(line.dropFirst(4))
                if p == "/dev/null" { current?.isDeleted = true; p = "" }
                else if p.hasPrefix("b/") { p = String(p.dropFirst(2)) }
                current?.newPath = p
                continue
            }
            if line.hasPrefix("@@") {
                flushHunk()
                if let ranges = parseHunkHeader(line) {
                    oldNo = ranges.oldStart
                    newNo = ranges.newStart
                    hunk = DiffHunk(
                        oldStart: ranges.oldStart, oldCount: ranges.oldCount,
                        newStart: ranges.newStart, newCount: ranges.newCount,
                        header: line, lines: []
                    )
                }
                continue
            }
            guard hunk != nil else { continue }

            if line.hasPrefix("\\") {
                // "\ No newline at end of file" — annotate last line.
                if var h = hunk, !h.lines.isEmpty {
                    h.lines[h.lines.count - 1].text += "\\ No newline at end of file"
                    hunk = h
                }
                continue
            }
            let kind: DiffLine.Kind
            let content: String
            if line.hasPrefix("+") { kind = .add; content = String(line.dropFirst()) }
            else if line.hasPrefix("-") { kind = .remove; content = String(line.dropFirst()) }
            else { kind = .context; content = line.hasPrefix(" ") ? String(line.dropFirst()) : line }

            var lineObj = DiffLine(kind: kind, oldNumber: nil, newNumber: nil, text: content)
            switch kind {
            case .context:
                lineObj.oldNumber = oldNo; lineObj.newNumber = newNo
                oldNo += 1; newNo += 1
            case .add:
                lineObj.newNumber = newNo
                newNo += 1
            case .remove:
                lineObj.oldNumber = oldNo
                oldNo += 1
            }
            hunk?.lines.append(lineObj)
        }
        flushFile()
        // Recompute hunk counts from actual lines (headers can lie in hand-made diffs).
        return files.map { file in
            var f = file
            f.hunks = f.hunks.map { h in
                var h2 = h
                h2.oldCount = h.lines.filter { $0.kind != .add }.count
                h2.newCount = h.lines.filter { $0.kind != .remove }.count
                return h2
            }
            return f
        }
    }

    private static func parseHunkHeader(_ line: String) -> (oldStart: Int, oldCount: Int, newStart: Int, newCount: Int)? {
        // @@ -oldStart,oldCount +newStart,newCount @@ optional header
        guard line.hasPrefix("@@") else { return nil }
        let body = line.dropFirst(2).dropLast(2) // strip @@ ... @@
        let segments = body.split(separator: " ")
        guard segments.count >= 2 else { return nil }
        let oldSeg = segments[0], newSeg = segments[1]
        guard oldSeg.hasPrefix("-"), newSeg.hasPrefix("+") else { return nil }
        let oldParts = oldSeg.dropFirst().split(separator: ",")
        let newParts = newSeg.dropFirst().split(separator: ",")
        let oldStart = Int(oldParts[0]) ?? 0
        let oldCount = oldParts.count > 1 ? (Int(oldParts[1]) ?? 0) : 1
        let newStart = Int(newParts[0]) ?? 0
        let newCount = newParts.count > 1 ? (Int(newParts[1]) ?? 0) : 1
        return (oldStart, oldCount, newStart, newCount)
    }
}
