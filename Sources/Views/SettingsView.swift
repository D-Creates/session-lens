import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: Store

    var body: some View {
        Form {
            Section("About") {
                LabeledContent("App", value: "Session Lens")
                LabeledContent("Version", value: "1.0")
                HStack {
                    Text("Mode")
                    Spacer()
                    Text(store.isDemo ? "Demo data" : (store.rootURL?.lastPathComponent ?? "None"))
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("settings.mode")
                }
            }
            Section("Launch arguments") {
                Text("-resetData — clear stored state")
                Text("-demo — load bundled sample logs and diffs")
                Text("-tab=N — select tab 0..3 on launch")
            }
            .accessibilityIdentifier("settings.launchArgs")
            Section("Privacy") {
                Text("Session Lens works fully offline. It reads only folders you select, runs no network requests and sends nothing anywhere.")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .accessibilityIdentifier("settings.form")
    }
}
