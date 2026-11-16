import SwiftUI

struct TimelineView: View {
    @EnvironmentObject var store: Store
    @Binding var selectedEventID: String?
    @FocusState private var isSearchFocused: Bool

    private func icon(for kind: LogEvent.EventKind) -> String {
        switch kind {
        case .user: return "person.circle"
        case .assistant: return "sparkles"
        case .toolCall: return "wrench.and.screwdriver"
        case .toolResult: return "checkmark.rectangle"
        case .system: return "gear"
        case .other: return "circle"
        }
    }

    private func color(for kind: LogEvent.EventKind) -> Color {
        switch kind {
        case .user: return .blue
        case .assistant: return .purple
        case .toolCall: return .orange
        case .toolResult: return .green
        case .system: return .secondary
        case .other: return .secondary
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Search prompts, tool calls, files…", text: $store.searchQuery)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    #endif
                    .submitLabel(.search)
                    .focused($isSearchFocused)
                    .accessibilityIdentifier("timeline.searchField")
                if !store.searchQuery.isEmpty {
                    Button("Clear") {
                        store.searchQuery = ""
                        isSearchFocused = false
                    }
                    .accessibilityIdentifier("timeline.searchClear")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            if store.timeline.isEmpty {
                ContentUnavailableView(
                    "No timeline events",
                    systemImage: "clock",
                    description: Text("Open a folder with .jsonl logs or load the demo data.")
                )
                .accessibilityIdentifier("timeline.empty")
            } else {
                List {
                    ForEach(store.filteredTimeline) { item in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: icon(for: item.event.kind))
                                .foregroundStyle(color(for: item.event.kind))
                                .frame(width: 20)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.event.kind.rawValue)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if let ts = item.event.timestamp {
                                        Text(ts, style: .time)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Text(item.event.sourceFile)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    Text("line \(item.event.lineNumber)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.event.summary)
                                    .lineLimit(3)
                            }
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            isSearchFocused = false
                            selectedEventID = item.id
                        }
                        .listRowBackground(selectedEventID == item.id ? Color.accentColor.opacity(0.12) : nil)
                        .accessibilityIdentifier("timeline.row.\(item.id)")
                    }
                }
                .accessibilityIdentifier("timeline.list")
                .listStyle(.plain)
            }

            if !isSearchFocused, let selected = store.timeline.first(where: { $0.id == selectedEventID }) {
                Divider()
                ScrollView {
                    Text(selected.event.detail)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .accessibilityIdentifier("timeline.detailText")
                }
                .frame(height: 140)
                .accessibilityIdentifier("timeline.detailPane")
            }
        }
        .navigationTitle("Timeline")
    }
}
