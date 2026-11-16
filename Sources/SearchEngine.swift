import Foundation

/// Case-insensitive text search over timeline items.
enum SearchEngine {

    static func filter(_ items: [TimelineItem], query: String) -> [TimelineItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return items }
        return items.filter { item in
            item.event.summary.lowercased().contains(q)
                || item.event.detail.lowercased().contains(q)
                || item.event.sourceFile.lowercased().contains(q)
                || item.event.kind.rawValue.contains(q)
        }
    }

    static func filterFiles(_ files: [SessionFile], query: String) -> [SessionFile] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return files }
        return files.filter { $0.name.lowercased().contains(q) }
    }
}
