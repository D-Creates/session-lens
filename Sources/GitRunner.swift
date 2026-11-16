import Foundation

/// Runs `/usr/bin/git` via Process on a user-selected repo only.
/// `GIT_OPTIONAL_LOCKS=0` keeps the repo untouched (no index writes).
/// Process is unavailable on iOS, so only macOS runs git; other platforms
/// return an error result.
enum GitRunner {

    struct Result: Sendable {
        var output: String?
        var error: String?
    }

    static func diffWorkingTree(at repoURL: URL) -> Result {
        runGit(arguments: ["diff", "--no-ext-diff", "--", "."], at: repoURL)
    }

#if os(macOS)
    static func runGit(arguments: [String], at repoURL: URL) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        process.currentDirectoryURL = repoURL
        var env = ProcessInfo.processInfo.environment
        env["GIT_OPTIONAL_LOCKS"] = "0"
        env["GIT_CONFIG_NOSYSTEM"] = "1"
        process.environment = env
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
            process.waitUntilExit()
            let outData = out.fileHandleForReading.readDataToEndOfFile()
            let errData = err.fileHandleForReading.readDataToEndOfFile()
            if process.terminationStatus == 0 {
                return Result(output: String(data: outData, encoding: .utf8), error: nil)
            }
            return Result(output: nil, error: String(data: errData, encoding: .utf8) ?? "exit \(process.terminationStatus)")
        } catch {
            return Result(output: nil, error: error.localizedDescription)
        }
    }
#else
    static func runGit(arguments: [String], at repoURL: URL) -> Result {
        Result(output: nil, error: "git diff is not available on this platform")
    }
#endif
}
