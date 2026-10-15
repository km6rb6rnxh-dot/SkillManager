import Foundation

actor SkillInstaller {
    private let shell: ShellRunner
    private let registry: SkillRegistry
    private let coworkRegistry: CoworkRegistry

    var installDirectory: URL
    var claudeSkillsDirectory: URL

    init(
        shell: ShellRunner = ShellRunner(),
        registry: SkillRegistry = SkillRegistry(),
        coworkRegistry: CoworkRegistry = CoworkRegistry(),
        installDirectory: URL = Constants.defaultSkillsInstallDirectory,
        claudeSkillsDirectory: URL = Constants.defaultClaudeSkillsDirectory
    ) {
        self.shell = shell
        self.registry = registry
        self.coworkRegistry = coworkRegistry
        self.installDirectory = installDirectory
        self.claudeSkillsDirectory = claudeSkillsDirectory
    }

    func install(
        candidate: SkillCandidate,
        repoURL: String,
        ownerRepo: String,
        ref: String? = nil
    ) async throws -> SkillEntry {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }

        var gitArgs = ["clone", "--depth", "1"]
        if let ref { gitArgs += ["--branch", ref] }
        gitArgs += [repoURL, tempDir.path]

        let cloneResult = try await shell.runGit(gitArgs)
        guard cloneResult.success else {
            throw SkillManagerError.cloneFailed(cloneResult.stderr)
        }

        let hashResult = try await shell.runGit(
            ["rev-parse", "--verify", "HEAD:\(candidate.folderPath)"],
            in: tempDir
        )
        let treeHash: String
        if hashResult.success {
            treeHash = hashResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            treeHash = candidate.treeSHA
        }

        let sourceFolder: URL
        if candidate.folderPath.isEmpty {
            sourceFolder = tempDir
        } else {
            sourceFolder = tempDir.appendingPathComponent(candidate.folderPath)
        }

        guard fm.fileExists(atPath: sourceFolder.path) else {
            throw SkillManagerError.skillNotFoundInRepo(candidate.name)
        }

        let destFolder = installDirectory.appendingPathComponent(candidate.name)

        try fm.createDirectory(at: installDirectory, withIntermediateDirectories: true)

        if fm.fileExists(atPath: destFolder.path) {
            try fm.removeItem(at: destFolder)
        }
        try fm.copyItem(at: sourceFolder, to: destFolder)

        // Remove .git if present (when folderPath is root)
        let gitDir = destFolder.appendingPathComponent(".git")
        if fm.fileExists(atPath: gitDir.path) {
            try fm.removeItem(at: gitDir)
        }

        try createSymlink(for: candidate.name)

        let now = ISO8601DateFormatter().string(from: Date())
        let entry = SkillEntry(
            source: ownerRepo,
            sourceType: "github",
            sourceUrl: repoURL.hasSuffix(".git") ? repoURL : repoURL + ".git",
            skillPath: candidate.skillPath,
            skillFolderHash: treeHash,
            installedAt: now,
            updatedAt: now,
            ref: ref
        )

        try await registry.addSkill(name: candidate.name, entry: entry)

        let skillMDPath = destFolder.appendingPathComponent("SKILL.md")
        if let content = try? String(contentsOf: skillMDPath, encoding: .utf8),
           let metadata = FrontmatterParser.parse(content) {
            try? await coworkRegistry.registerSkill(
                name: candidate.name,
                description: metadata.description,
                installDir: installDirectory
            )
        }

        return entry
    }

    func installResource(
        repoURL: String,
        ownerRepo: String,
        skillName: String,
        description: String,
        contentFiles: [String],
        toCode: Bool,
        toCowork: Bool
    ) async throws -> SkillEntry {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }

        let cloneResult = try await shell.runGit(["clone", "--depth", "1", repoURL, tempDir.path])
        guard cloneResult.success else {
            throw SkillManagerError.cloneFailed(cloneResult.stderr)
        }

        var skillContent = "---\nname: \(skillName)\ndescription: \"\(description)\"\n---\n\n"
        for file in contentFiles {
            let filePath = tempDir.appendingPathComponent(file)
            if let content = try? String(contentsOf: filePath, encoding: .utf8) {
                if contentFiles.count > 1 {
                    skillContent += "# \(file)\n\n"
                }
                skillContent += content + "\n\n"
            }
        }

        let destFolder = installDirectory.appendingPathComponent(skillName)
        try fm.createDirectory(at: installDirectory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: destFolder.path) {
            try fm.removeItem(at: destFolder)
        }
        try fm.createDirectory(at: destFolder, withIntermediateDirectories: true)

        let skillMDPath = destFolder.appendingPathComponent("SKILL.md")
        try skillContent.write(to: skillMDPath, atomically: true, encoding: .utf8)

        let hashResult = try await shell.runGit(["hash-object", skillMDPath.path])
        let hash = hashResult.success ? hashResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : UUID().uuidString

        if toCode {
            try createSymlink(for: skillName)
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let entry = SkillEntry(
            source: ownerRepo,
            sourceType: "github",
            sourceUrl: repoURL.hasSuffix(".git") ? repoURL : repoURL + ".git",
            skillPath: "SKILL.md",
            skillFolderHash: hash,
            installedAt: now,
            updatedAt: now,
            ref: nil
        )

        try await registry.addSkill(name: skillName, entry: entry)

        if toCowork {
            try? await coworkRegistry.registerSkill(
                name: skillName,
                description: description,
                installDir: installDirectory
            )
        }

        return entry
    }

    func update(
        skillName: String,
        candidate: SkillCandidate,
        repoURL: String,
        ownerRepo: String,
        ref: String? = nil
    ) async throws -> SkillEntry {
        try await remove(skillName: skillName, fromRegistry: false)
        let entry = try await install(
            candidate: candidate,
            repoURL: repoURL,
            ownerRepo: ownerRepo,
            ref: ref
        )
        return entry
    }

    func remove(skillName: String, fromRegistry: Bool = true) async throws {
        let fm = FileManager.default

        let skillFolder = installDirectory.appendingPathComponent(skillName)
        if fm.fileExists(atPath: skillFolder.path) {
            try fm.removeItem(at: skillFolder)
        }

        try removeSymlink(for: skillName)

        if fromRegistry {
            try await registry.removeSkill(name: skillName)
            try? await coworkRegistry.unregisterSkill(name: skillName)
        }
    }

    func createSymlink(for skillName: String) throws {
        let fm = FileManager.default
        let linkPath = claudeSkillsDirectory.appendingPathComponent(skillName)
        let targetPath = installDirectory.appendingPathComponent(skillName)

        try fm.createDirectory(at: claudeSkillsDirectory, withIntermediateDirectories: true)

        if fm.fileExists(atPath: linkPath.path) || (try? fm.destinationOfSymbolicLink(atPath: linkPath.path)) != nil {
            try fm.removeItem(at: linkPath)
        }

        try fm.createSymbolicLink(
            atPath: linkPath.path,
            withDestinationPath: targetPath.path
        )
    }

    func removeSymlink(for skillName: String) throws {
        let linkPath = claudeSkillsDirectory.appendingPathComponent(skillName)
        let fm = FileManager.default
        if fm.fileExists(atPath: linkPath.path) || (try? fm.destinationOfSymbolicLink(atPath: linkPath.path)) != nil {
            try fm.removeItem(at: linkPath)
        }
    }
}
