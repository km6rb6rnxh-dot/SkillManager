import Foundation

enum Constants {
    static let defaultAgentsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".agents")

    static let defaultSkillsInstallDirectory = defaultAgentsDirectory
        .appendingPathComponent("skills")

    static let defaultClaudeSkillsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
        .appendingPathComponent("skills")

    static let lockFileName = ".skill-lock.json"

    static var lockFilePath: URL {
        defaultAgentsDirectory.appendingPathComponent(lockFileName)
    }

    static let gitHubAPIBase = "https://api.github.com"
    static let userAgent = "SkillManager-macOS/1.0"

    static let gitExecutable = "/usr/local/bin/git"

    enum UserDefaultsKeys {
        static let installDirectory = "installDirectory"
        static let claudeSkillsDirectory = "claudeSkillsDirectory"
        static let autoCheckUpdates = "autoCheckUpdates"
        static let githubToken = "githubToken"
        static let appearance = "appearance"
        static let onboardingCompleted = "onboardingCompleted"
    }
}
