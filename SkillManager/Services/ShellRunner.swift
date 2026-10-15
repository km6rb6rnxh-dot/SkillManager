import Foundation

actor ShellRunner {
    struct CommandResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
        var success: Bool { exitCode == 0 }
    }

    func run(
        _ executable: String,
        arguments: [String],
        currentDirectory: URL? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 120
    ) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments

            if let dir = currentDirectory {
                process.currentDirectoryURL = dir
            }

            var env = ProcessInfo.processInfo.environment
            env["GIT_TERMINAL_PROMPT"] = "0"
            env["GIT_OPTIONAL_LOCKS"] = "0"
            if let extra = environment {
                env.merge(extra) { _, new in new }
            }
            process.environment = env

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            process.terminationHandler = { _ in
                let outData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let errData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let result = CommandResult(
                    exitCode: process.terminationStatus,
                    stdout: String(data: outData, encoding: .utf8) ?? "",
                    stderr: String(data: errData, encoding: .utf8) ?? ""
                )
                continuation.resume(returning: result)
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    func runGit(_ arguments: [String], in directory: URL? = nil) async throws -> CommandResult {
        let gitPath: String
        if FileManager.default.fileExists(atPath: Constants.gitExecutable) {
            gitPath = Constants.gitExecutable
        } else {
            gitPath = "/usr/bin/git"
        }
        return try await run(gitPath, arguments: arguments, currentDirectory: directory)
    }
}
