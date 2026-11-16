import SwiftUI

struct DiffView: View {
    @EnvironmentObject var store: Store
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @Binding var selectedDiffID: String?

    private var isRegularWidth: Bool {
        #if os(macOS)
        return true
        #else
        return horizontalSizeClass == .regular
        #endif
    }

    var selectedFile: DiffFile? {
        store.diffFiles.first { $0.id == selectedDiffID }
            ?? store.diffFiles.first { $0.id == store.preselectedDiffID }
            ?? store.diffFiles.first
    }

    var body: some View {
        Group {
            if store.diffFiles.isEmpty {
                ContentUnavailableView(
                    "No diffs",
                    systemImage: "doc.on.doc",
                    description: Text("Open a folder with .diff/.patch files or load the demo data.")
                )
                .accessibilityIdentifier("diff.empty")
            } else if isRegularWidth {
                HStack(spacing: 0) {
                    diffFileList
                        .frame(minWidth: 190, idealWidth: 220, maxWidth: 260)
                    Divider()
                    if let file = selectedFile {
                        DiffPaneView(file: file, isCompact: false)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    diffFileList
                        .frame(height: 150)
                    Divider()
                    if let file = selectedFile {
                        DiffPaneView(file: file, isCompact: true)
                    }
                }
            }
        }
        .navigationTitle("Diff")
    }

    private var diffFileList: some View {
        List {
            ForEach(store.diffFiles) { file in
                Button {
                    selectedDiffID = file.id
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(file.displayPath).lineLimit(1)
                            if file.isRename { Label("renamed", systemImage: "arrow.right.square").font(.caption2).foregroundStyle(.secondary).fixedSize() }
                            if file.isNew { Label("new", systemImage: "plus.square").font(.caption2).foregroundStyle(.green).fixedSize() }
                            if file.isDeleted { Label("deleted", systemImage: "minus.square").font(.caption2).foregroundStyle(.red).fixedSize() }
                            Spacer(minLength: 0)
                        }
                        Text("+\(file.hunks.reduce(0) { $0 + $1.added }) -\(file.hunks.reduce(0) { $0 + $1.removed })")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .listRowBackground(selectedFile?.id == file.id ? Color.accentColor.opacity(0.12) : nil)
                .accessibilityIdentifier("diff.fileRow.\(file.displayPath)")
            }
        }
        .listStyle(.plain)
        .accessibilityIdentifier("diff.fileList")
    }
}

/// Diff pane: side-by-side on regular width, unified full-width lines on compact width.
struct DiffPaneView: View {
    let file: DiffFile
    var isCompact: Bool = false

    private func rowColor(_ kind: DiffLine.Kind) -> Color {
        switch kind {
        case .add: return Color.green.opacity(0.18)
        case .remove: return Color.red.opacity(0.18)
        case .context: return Color.clear
        }
    }

    private func prefix(_ kind: DiffLine.Kind) -> String {
        switch kind {
        case .add: return "+"
        case .remove: return "-"
        case .context: return " "
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(file.displayPath)
                    .font(.headline)
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .accessibilityIdentifier("diffPane.title")
                ForEach(Array(file.hunks.enumerated()), id: \.offset) { _, hunk in
                    Text(hunk.header)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .accessibilityIdentifier("diffPane.hunkHeader")
                    ForEach(Array(hunk.lines.enumerated()), id: \.offset) { _, line in
                        if isCompact {
                            HStack(spacing: 6) {
                                Text(line.oldNumber.map(String.init) ?? "")
                                    .frame(width: 28, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Text(line.newNumber.map(String.init) ?? "")
                                    .frame(width: 28, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Text("\(prefix(line.kind))\(line.text)")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .background(rowColor(line.kind))
                            .accessibilityIdentifier("diffPane.line.\(line.kind.rawValue)")
                        } else {
                            HStack(spacing: 0) {
                                // Left: old side
                                Text(line.kind == .add ? "" : (line.oldNumber.map(String.init) ?? ""))
                                    .frame(width: 44, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Text(line.kind == .add ? "" : line.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(rowColor(line.kind == .remove ? .remove : .context))
                                Divider()
                                // Right: new side
                                Text(line.kind == .remove ? "" : (line.newNumber.map(String.init) ?? ""))
                                    .frame(width: 44, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                Text(line.kind == .remove ? "" : line.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(rowColor(line.kind == .add ? .add : .context))
                            }
                            .font(.system(.caption, design: .monospaced))
                            .accessibilityIdentifier("diffPane.line.\(line.kind.rawValue)")
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("diffPane.scroll")
    }
}
