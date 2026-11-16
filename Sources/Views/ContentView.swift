import SwiftUI

/// Adaptive root layout for iPhone and iPad:
/// - regular width (iPad, all orientations): NavigationSplitView with persistent
///   sidebar and a detail column driven by the segmented tab picker
/// - compact width (iPhone): TabView with a NavigationStack per section
struct ContentView: View {
    @EnvironmentObject var store: Store
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var selectedEventID: String?
    @State private var selectedDiffID: String?

    var body: some View {
        #if os(macOS)
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView(selectedEventID: $selectedEventID)
                .environmentObject(store)
        } detail: {
            detailContent
        }
        .navigationSplitViewStyle(.balanced)
        #else
        if horizontalSizeClass == .regular {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(selectedEventID: $selectedEventID)
                    .environmentObject(store)
            } detail: {
                NavigationStack {
                    detailContent
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .navigationSplitViewStyle(.balanced)
        } else {
            TabView(selection: $store.selectedTab) {
                NavigationStack {
                    SessionsView()
                        .environmentObject(store)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("Sessions", systemImage: "doc.text") }
                .tag(0)

                NavigationStack {
                    TimelineView(selectedEventID: $selectedEventID)
                        .environmentObject(store)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("Timeline", systemImage: "clock") }
                .tag(1)

                NavigationStack {
                    DiffView(selectedDiffID: $selectedDiffID)
                        .environmentObject(store)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("Diff", systemImage: "doc.on.doc") }
                .tag(2)

                NavigationStack {
                    SettingsView()
                        .environmentObject(store)
                        .navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { Label("Settings", systemImage: "gear") }
                .tag(3)
            }
        }
        #endif
    }

    /// Detail column for the regular-width split view: tab picker plus content.
    private var detailContent: some View {
        VStack(spacing: 0) {
            Picker("Tab", selection: $store.selectedTab) {
                Text("Sessions").tag(0)
                Text("Timeline").tag(1)
                Text("Diff").tag(2)
                Text("Settings").tag(3)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .accessibilityIdentifier("main.tabPicker")

            switch store.selectedTab {
            case 0:
                SessionsView()
            case 1:
                TimelineView(selectedEventID: $selectedEventID)
            case 2:
                DiffView(selectedDiffID: $selectedDiffID)
            default:
                SettingsView()
            }
        }
        .environmentObject(store)
    }
}
