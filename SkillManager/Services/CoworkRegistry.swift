import Foundation

actor CoworkRegistry {
    private let claudeSkillsDir: URL

    init(claudeSkillsDir: URL = Constants.defaultClaudeSkillsDirectory) {
        self.claudeSkillsDir = claudeSkillsDir
    }

    private func findSyncedBucket() -> (dir: URL, manifest: URL)? {
        let syncedDir = claudeSkillsDir.appendingPathComponent("synced")
        let fm = FileManager.default

        guard let contents = try? fm.contentsOfDirectory(
            at: syncedDir,
            includingPropertiesForKeys: [.isDirectoryKey]
        ) else { return nil }

        for item in contents {
            var isDir: ObjCBool = false
            fm.fileExists(atPath: item.path, isDirectory: &isDir)
            guard isDir.boolValue else { continue }

            let manifest = item.appendingPathComponent("manifest.json")
            if fm.fileExists(atPath: manifest.path) {
                return (item, manifest)
            }
        }

        return nil
    }

    func registerSkill(name: String, description: String, installDir: URL) throws {
        guard let bucket = findSyncedBucket() else { return }

        let fm = FileManager.default
        let data = try Data(contentsOf: bucket.manifest)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var skillsArray = json["skills"] as? [[String: Any]] else {
            return
        }

        let alreadyExists = skillsArray.contains { ($0["name"] as? String) == name }
        if alreadyExists { return }

        let skillDir = bucket.dir.appendingPathComponent(name)
        let sourceSkillMD = installDir.appendingPathComponent(name).appendingPathComponent("SKILL.md")

        if fm.fileExists(atPath: sourceSkillMD.path) {
            try fm.createDirectory(at: skillDir, withIntermediateDirectories: true)
            let destSkillMD = skillDir.appendingPathComponent("SKILL.md")
            if fm.fileExists(atPath: destSkillMD.path) {
                try fm.removeItem(at: destSkillMD)
            }
            try fm.copyItem(at: sourceSkillMD, to: destSkillMD)
        }

        let skillId = "skill_\(UUID().uuidString.prefix(24).replacingOccurrences(of: "-", with: ""))"
        let entry: [String: Any] = [
            "skillId": skillId,
            "name": name,
            "description": description,
            "source": "plugin",
            "updatedAt": ISO8601DateFormatter().string(from: Date())
        ]

        skillsArray.append(entry)
        json["skills"] = skillsArray
        json["lastUpdated"] = Int(Date().timeIntervalSince1970 * 1000)

        let outputData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try outputData.write(to: bucket.manifest, options: .atomic)
    }

    func isSkillRegistered(name: String) -> Bool {
        guard let bucket = findSyncedBucket(),
              let data = try? Data(contentsOf: bucket.manifest),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let skillsArray = json["skills"] as? [[String: Any]] else {
            return false
        }
        return skillsArray.contains { ($0["name"] as? String) == name }
    }

    func unregisterSkill(name: String) throws {
        guard let bucket = findSyncedBucket() else { return }

        let fm = FileManager.default
        let data = try Data(contentsOf: bucket.manifest)
        guard var json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              var skillsArray = json["skills"] as? [[String: Any]] else {
            return
        }

        skillsArray.removeAll { ($0["name"] as? String) == name }
        json["skills"] = skillsArray
        json["lastUpdated"] = Int(Date().timeIntervalSince1970 * 1000)

        let outputData = try JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys])
        try outputData.write(to: bucket.manifest, options: .atomic)

        let skillDir = bucket.dir.appendingPathComponent(name)
        if fm.fileExists(atPath: skillDir.path) {
            try fm.removeItem(at: skillDir)
        }
    }
}
