import Foundation

/// Orders log events into a stable timeline.
enum TimelineBuilder {

    static func build(events: [LogEvent]) -> [TimelineItem] {
        events
            .map { TimelineItem(id: $0.id, event: $0) }
            .sorted { a, b in
                let ka = a.sortKey, kb = b.sortKey
                if ka.0 != kb.0 {
                    if ka.0 == nil { return true }  // nil timestamps sort first
                    if kb.0 == nil { return false }
                    return ka.0! < kb.0!
                }
                if ka.1 != kb.1 { return ka.1 < kb.1 }
                return ka.2 < kb.2
            }
    }
}
