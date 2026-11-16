import SwiftUI

struct SessionsView: View {
    @EnvironmentObject var store: Store
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var showingOpenPanel = false

    private var isRegularWidth: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    var body: some View {
        VStack(spacing: 0) {
            #if os(iOS)
            if !isRegularWidth {
                compactFolderBar
                Divider()
            }
            #endif

            if store.sessionFiles.isEmpty {
                ContentUnavailableView(
                    "No session logs",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Open a folder with .jsonl logs or load the demo data.")
                )
                .accessibilityIdentifier("sessions.empty")
            } else if isRegularWidth {
                Table(store.sessionFiles) {
                    TableColumn("File") { (file: SessionFile) in
                        Text(file.name)
                            .accessibilityIdentifier("sessions.row.\(file.name)")
                    }
                    TableColumn("Events") { (file: SessionFile) in
                        Text("\(file.eventCount)")
                            .accessibilityIdentifier("sessions.table.eventsColumn")
                    }
                    TableColumn("Skipped lines") { (file: SessionFile) in
                        Text("\(file.skippedLines)")
                    }
                }
                .accessibilityIdentifier("sessions.table")
            } else {
                #if os(iOS)
                List {
                    Section("Session logs") {
                        ForEach(store.sessionFiles) { file in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(file.name)
                                        .font(.body)
                                        .lineLimit(1)
                                        .accessibilityIdentifier("sessions.row.\(file.name)")
                                    if file.skippedLines > 0 {
                                        Text("\(file.skippedLines) skipped")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Text("\(file.eventCount) events")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .accessibilityIdentifier("sessions.table.eventsColumn")
                            }
                        }
                    }
                    if !store.diffSources.isEmpty {
                        Section("Diff files") {
                            ForEach(store.diffSources) { source in
                                HStack {
                                    Text(source.name).lineLimit(1)
                                    Spacer()
                                    Text("\(source.fileCount) files")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .accessibilityIdentifier("sessions.table")
                #endif
            }
        }
        .navigationTitle("Sessions")
    }

    private var compactFolderBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                Button {
                    showingOpenPanel = true
                } label: {
                    Label("Open Folder…", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityIdentifier("sessions.openFolderButton")
                .fileImporter(
                    isPresented: $showingOpenPanel,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    if case .success(let urls) = result, let url = urls.first {
                        _ = url.startAccessingSecurityScopedResource()
                        store.loadFolder(url)
                    }
                }

                Button {
                    store.loadDemo()
                } label: {
                    Label("Load Demo Data", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityIdentifier("sessions.loadDemoButton")

                Spacer(minLength: 0)
            }
            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .accessibilityIdentifier("sessions.statusMessage")
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }
}
