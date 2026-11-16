import SwiftUI

/// Launch arguments (all in `-key=value` form):
/// - `-resetData` clear persisted state
/// - `-demo` load bundled sample logs and diffs
/// - `-tab=N` select tab 0..3 on launch
/// - `-search=<text>` prefill the timeline search
/// - `-diff=<index>` preselect a changed file in the Diff tab
struct LaunchArguments {
    var resetData: Bool
    var demo: Bool
    var tab: Int?
    var search: String?
    var diffIndex: Int?

    static func parse(_ args: [String] = ProcessInfo.processInfo.arguments) -> LaunchArguments {
        var reset = false
        var demo = false
        var tab: Int? = nil
        var search: String? = nil
        var diffIndex: Int? = nil
        for arg in args {
            if arg == "-resetData" || arg == "--resetData" { reset = true }
            if arg.hasPrefix("-demo=") || arg == "-demo" || arg == "--demo" { demo = true }
            if arg.hasPrefix("-tab=") { tab = Int(arg.dropFirst("-tab=".count)) }
            if arg.hasPrefix("--tab=") { tab = Int(arg.dropFirst("--tab=".count)) }
            if arg.hasPrefix("-search=") { search = String(arg.dropFirst("-search=".count)) }
            if arg.hasPrefix("--search=") { search = String(arg.dropFirst("--search=".count)) }
            if arg.hasPrefix("-diff=") { diffIndex = Int(arg.dropFirst("-diff=".count)) }
            if arg.hasPrefix("--diff=") { diffIndex = Int(arg.dropFirst("--diff=".count)) }
        }
        return LaunchArguments(resetData: reset, demo: demo, tab: tab, search: search, diffIndex: diffIndex)
    }
}

@main
struct SessionLensApp: App {
    @StateObject private var store = Store()
    @State private var didApplyLaunchArgs = false

    init() {
        let args = LaunchArguments.parse()
        if args.resetData {
            let fm = FileManager.default
            if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                let dir = appSupport.appendingPathComponent("SessionLens", isDirectory: true)
                try? fm.removeItem(at: dir)
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    guard !didApplyLaunchArgs else { return }
                    didApplyLaunchArgs = true
                    let args = LaunchArguments.parse()
                    if args.demo { store.loadDemo() }
                    if let tab = args.tab { store.selectedTab = min(max(tab, 0), 3) }
                    if let search = args.search { store.searchQuery = search }
                    if let diffIndex = args.diffIndex, diffIndex >= 0, diffIndex < store.diffFiles.count {
                        store.preselectedDiffID = store.diffFiles[diffIndex].id
                    }
                }
        }
        #if os(macOS)
        .defaultSize(width: 1000, height: 680)
        #endif
    }
}
