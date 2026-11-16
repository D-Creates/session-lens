import Foundation

/// Bundled sample data for `-demo` mode: fabricated logs and diffs.
/// No real session data; all content is invented for this app.
enum DemoFixture {

    static let sampleJSONL: String = """
    {"type":"system","message":"Session started. Working directory: /demo/project"}
    {"type":"user","message":"Add a login button to the home screen and wire it to the auth service.","timestamp":"2026-11-13T09:02:11Z"}
    {"type":"assistant","content":[{"text":"I will add the button in HomeView.swift and call AuthService.signIn()."}],"timestamp":"2026-11-13T09:02:14Z"}
    {"type":"tool_call","tool_name":"edit_file","arguments":"{\\\"path\\\":\\\"HomeView.swift\\\",\\\"change\\\":\\\"add Button(\\\"Sign in\\\") { AuthService.signIn() }}","timestamp":"2026-11-13T09:02:15Z"}
    {"type":"tool_result","name":"edit_file","content":"Applied 1 edit to HomeView.swift (+12 lines).","timestamp":"2026-11-13T09:02:16Z"}
    {"type":"tool_call","tool_name":"run_tests","arguments":"{\\\"target\\\":\\\"HomeViewTests\\\"}","timestamp":"2026-11-13T09:02:31Z"}
    {"type":"tool_result","name":"run_tests","content":"2 tests passed, 0 failed.","timestamp":"2026-11-13T09:02:40Z"}
    {"type":"user","message":"Now rename the old helper to make the naming consistent.","timestamp":"2026-11-13T09:05:02Z"}
    {"type":"tool_call","tool_name":"rename_file","arguments":"{\\\"from\\\":\\\"Helpers.swift\\\",\\\"to\\\":\\\"AuthHelpers.swift\\\"}","timestamp":"2026-11-13T09:05:04Z"}
    {"type":"tool_result","name":"rename_file","content":"Renamed Helpers.swift -> AuthHelpers.swift.","timestamp":"2026-11-13T09:05:05Z"}
    {"type":"assistant","content":[{"text":"Done. The login flow is tested and the helper file is renamed."}],"timestamp":"2026-11-13T09:05:20Z"}
    this line is not json and must be skipped
    {"type":"user","message":"Summarize what changed in one sentence.","timestamp":"2026-11-13T09:06:00Z"}
    """

    static let secondJSONL: String = """
    {"type":"system","message":"Resumed session. 3 checkpoints available."}
    {"type":"user","message":"Fix the crash when the log folder is empty.","timestamp":"2026-11-13T10:14:00Z"}
    {"type":"tool_call","tool_name":"read_file","arguments":"{\\\"path\\\":\\\"LogLoader.swift\\\"}","timestamp":"2026-11-13T10:14:03Z"}
    {"type":"tool_result","name":"read_file","content":"Found nil force-unwrap on empty array at line 42.","timestamp":"2026-11-13T10:14:05Z"}
    {"type":"tool_call","tool_name":"edit_file","arguments":"{\\\"path\\\":\\\"LogLoader.swift\\\",\\\"change\\\":\\\"use optional chaining\\\"}","timestamp":"2026-11-13T10:14:09Z"}
    {"type":"tool_result","name":"edit_file","content":"Applied 1 edit to LogLoader.swift (+2 -1).","timestamp":"2026-11-13T10:14:10Z"}
    """

    static let sampleDiff: String = """
    diff --git a/HomeView.swift b/HomeView.swift
    index 1a2b3c4..5d6e7f8 100644
    --- a/HomeView.swift
    +++ b/HomeView.swift
    @@ -10,7 +10,19 @@ struct HomeView: View {
         var body: some View {
             VStack {
                 Text("Welcome")
    +            Button("Sign in") {
    +                AuthService.signIn()
    +            }
    +            .accessibilityIdentifier("home.signInButton")
                 Spacer()
             }
         }
    }
    diff --git a/Helpers.swift b/AuthHelpers.swift
    similarity index 92%
    rename from Helpers.swift
    rename to AuthHelpers.swift
    --- a/Helpers.swift
    +++ b/AuthHelpers.swift
    @@ -1,5 +1,5 @@
    -func oldHelper() -> String { return "x" }
    +func authHelper() -> String { return "x" }
     func shared() -> String { return "s" }
    diff --git a/LegacyView.swift b/LegacyView.swift
    deleted file mode 100644
    --- a/LegacyView.swift
    +++ /dev/null
    @@ -1,3 +0,0 @@
    -struct LegacyView: View {
    -    var body: some View { Text("old") }
    -}
    diff --git a/NewFeature.swift b/NewFeature.swift
    new file mode 100644
    --- /dev/null
    +++ b/NewFeature.swift
    @@ -0,0 +1,2 @@
    +struct NewFeature: View {
    +    var body: some View { Text("new") }
    """

    static let secondDiff: String = """
    diff --git a/LogLoader.swift b/LogLoader.swift
    index 9f8e7d6..1a2b3c4 100644
    --- a/LogLoader.swift
    +++ b/LogLoader.swift
    @@ -40,7 +40,8 @@
     func load() -> [String] {
         let lines = readLines()
    -    return lines.first!.components(separatedBy: ",")
    +    guard let first = lines.first else { return [] }
    +    return first.components(separatedBy: ",")
     }
    """
}
