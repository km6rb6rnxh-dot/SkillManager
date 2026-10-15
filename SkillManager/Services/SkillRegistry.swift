import Foundation

actor SkillRegistry {
    private let lockFilePath: URL

    init(lockFilePath: URL = Constants.lockFilePath) {
        self.lockFilePath = lockFilePath
    }

    func load() throws -> (skills: [String: SkillEntry], rawJSON: [String: Any]) {
        guard FileManager.default.fileExists(atPath: lockFilePath.path) else {
            let empty: [String: Any] = ["version": 3, "skills": [String: Any]()]
            return ([:], empty)
        }

        let data = try Data(contentsOf: lockFilePath)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw SkillManagerError.lockFileCorrupted("Invalid JSON structure")
        }

        guard let skillsDict = json["skills"] as? [String: Any] else {
            return ([:], json)
        }

        var entries: [String: SkillEntry] = [:]
        let decoder = JSONDecoder()

        for (key, value) in skillsDict {
            let entryData = try JSONSerialization.data(withJSONObject: value)
            entries[key] = try decoder.decode(SkillEntry.self, from: entryData)
        }

        return (entries, json)
    }

    func save(skills: [String: SkillEntry], preserving rawJSON: [String: Any]) throws {
        var json = rawJSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        var skillsDict: [String: Any] = [:]
        for (key, entry) in skills {
            let entryData = try encoder.encode(entry)
            skillsDict[key] = try JSONSerialization.jsonObject(with: entryData)
        }
        json["skills"] = skillsDict

        let outputData = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        )

        let dir = lockFilePath.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try outputData.write(to: lockFilePath, options: .atomic)
    }

    func addSkill(name: String, entry: SkillEntry) throws {
        var (skills, rawJSON) = try load()
        skills[name] = entry
        try save(skills: skills, preserving: rawJSON)
    }

    func removeSkill(name: String) throws {
        var (skills, rawJSON) = try load()
        skills.removeValue(forKey: name)
        try save(skills: skills, preserving: rawJSON)
    }

    func updateSkill(name: String, newHash: String, updatedAt: Date = Date()) throws {
        var (skills, rawJSON) = try load()
        guard var entry = skills[name] else {
            throw SkillManagerError.skillNotInstalled(name)
        }
        entry.skillFolderHash = newHash
        entry.updatedAt = ISO8601DateFormatter().string(from: updatedAt)
        skills[name] = entry
        try save(skills: skills, preserving: rawJSON)
    }
}

enum SkillManagerError: LocalizedError {
    case lockFileCorrupted(String)
    case invalidRepoIdentifier(String)
    case repoNotFound(String)
    case rateLimited(resetDate: Date?)
    case networkError(Error)
    case apiError(statusCode: Int, message: String)
    case gitNotFound
    case cloneFailed(String)
    case skillNotFoundInRepo(String)
    case hashComputationFailed
    case copyFailed(String)
    case symlinkFailed(String)
    case skillAlreadyInstalled(String)
    case skillNotInstalled(String)

    var errorDescription: String? {
        switch self {
        case .lockFileCorrupted(let msg): return "Lock file corrupted: \(msg)"
        case .invalidRepoIdentifier(let id): return "Invalid repo: \(id)"
        case .repoNotFound(let repo): return "Repository not found: \(repo)"
        case .rateLimited: return "GitHub API rate limit exceeded"
        case .networkError(let err): return "Network error: \(err.localizedDescription)"
        case .apiError(let code, let msg): return "GitHub API error \(code): \(msg)"
        case .gitNotFound: return "git not found on system"
        case .cloneFailed(let msg): return "Clone failed: \(msg)"
        case .skillNotFoundInRepo(let name): return "Skill '\(name)' not found in repo"
        case .hashComputationFailed: return "Failed to compute skill hash"
        case .copyFailed(let msg): return "Copy failed: \(msg)"
        case .symlinkFailed(let msg): return "Symlink creation failed: \(msg)"
        case .skillAlreadyInstalled(let name): return "Skill '\(name)' is already installed"
        case .skillNotInstalled(let name): return "Skill '\(name)' is not installed"
        }
    }
}
