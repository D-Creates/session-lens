import SwiftUI

struct SidebarView: View {
    @EnvironmentObject var store: Store
    @Binding var selectedEventID: String?
    @State private var showingOpenPanel = false

    var body: some View {
        List {
            Section("Folder") {
                if let root = store.rootURL {
                    Label(root.lastPathComponent, systemImage: "folder")
                        .accessibilityIdentifier("sidebar.folderName")
                } else if store.isDemo {
                    Label("Demo data", systemImage: "sparkles")
                        .accessibilityIdentifier("sidebar.folderName")
                } else {
                    Label("No folder selected", systemImage: "folder.badge.questionmark")
                        .accessibilityIdentifier("sidebar.folderName")
                }
                Button {
                    showingOpenPanel = true
                } label: {
                    Label("Open Folder…", systemImage: "folder.badge.plus")
                }
                .accessibilityIdentifier("sidebar.openFolderButton")
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
                .accessibilityIdentifier("sidebar.loadDemoButton")

                #if os(macOS)
                if store.rootURL != nil {
                    Button {
                        store.runGitDiff()
                    } label: {
                        Label("Run git diff", systemImage: "arrow.triangle.2.circlepath")
                    }
                    .accessibilityIdentifier("sidebar.gitDiffButton")
                }
                #endif
            }

            Section("Session logs") {
                ForEach(store.sessionFiles) { file in
                    HStack {
                        Image(systemName: "doc.text")
                        VStack(alignment: .leading) {
                            Text(file.name).lineLimit(1)
                            Text("\(file.eventCount) events\(file.skippedLines > 0 ? ", \(file.skippedLines) skipped" : "")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.selectedTab = 0
                    }
                    .accessibilityIdentifier("sidebar.sessionFile.\(file.name)")
                }
            }

            Section("Diff files") {
                ForEach(store.diffSources) { source in
                    HStack {
                        Image(systemName: "doc.on.doc")
                        VStack(alignment: .leading) {
                            Text(source.name).lineLimit(1)
                            Text("\(source.fileCount) files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        store.selectedTab = 2
                    }
                    .accessibilityIdentifier("sidebar.diffSource.\(source.name)")
                }
            }
        }
        .listStyle(.sidebar)
        .accessibilityIdentifier("sidebar.list")
        .navigationTitle("Session Lens")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .safeAreaInset(edge: .bottom) {
            VStack(alignment: .leading, spacing: 0) {
                Divider()
                Text(store.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(.bar)
                    .accessibilityIdentifier("sidebar.statusMessage")
            }
        }
        .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 320)
    }
}
