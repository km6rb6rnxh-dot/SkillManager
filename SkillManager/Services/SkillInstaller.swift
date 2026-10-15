import Foundation

actor SkillInstaller {
    private let shell: ShellRunner
    private let registry: SkillRegistry
    private let coworkRegistry: CoworkRegistry

    var installDirectory: URL
    var claudeSkillsDirectory: URL

    typealias ProgressCallback = @Sendable (Double) -> Void

    private func log(_ message: String, level: LogEntry.Level = .info) {
        Task { @MainActor in InstallLogger.shared.log(message, level: level) }
    }

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

    // MARK: - Tarball-based extraction

    private func extractTarball(_ tarball: URL, to destination: URL) async throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        log("Extracting archive to \(destination.lastPathComponent)...")
        let result = try await shell.run(
            "/usr/bin/tar",
            arguments: ["xzf", tarball.path, "-C", destination.path, "--strip-components=1"]
        )
        guard result.success else {
            log("Extraction failed: \(result.stderr)", level: .error)
            throw SkillManagerError.cloneFailed("tar extraction failed: \(result.stderr)")
        }
        log("Archive extracted")
    }

    // MARK: - Fast Install (tarball)

    func installFast(
        candidate: SkillCandidate,
        ownerRepo: String,
        ref: String? = nil,
        progress: ProgressCallback? = nil
    ) async throws -> SkillEntry {
        let fm = FileManager.default
        let parts = ownerRepo.split(separator: "/")
        guard parts.count == 2 else {
            throw SkillManagerError.invalidRepoIdentifier(ownerRepo)
        }

        progress?(0.05)

        log("Downloading tarball for \(ownerRepo)...")
        let github = GitHubService(
            token: UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken)
        )
        let tarball = try await github.downloadTarball(
            owner: String(parts[0]), repo: String(parts[1]), ref: ref
        )
        defer { try? fm.removeItem(at: tarball) }
        log("Tarball downloaded")

        progress?(0.50)

        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }
        try await extractTarball(tarball, to: tempDir)

        progress?(0.65)

        let sourceFolder: URL
        if candidate.folderPath.isEmpty {
            sourceFolder = tempDir
        } else {
            sourceFolder = tempDir.appendingPathComponent(candidate.folderPath)
        }

        guard fm.fileExists(atPath: sourceFolder.path) else {
            log("Skill folder '\(candidate.folderPath)' not found in archive", level: .error)
            throw SkillManagerError.skillNotFoundInRepo(candidate.name)
        }

        let destFolder = installDirectory.appendingPathComponent(candidate.name)
        try fm.createDirectory(at: installDirectory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: destFolder.path) {
            log("Replacing existing install at \(destFolder.lastPathComponent)")
            try fm.removeItem(at: destFolder)
        }
        try fm.copyItem(at: sourceFolder, to: destFolder)
        log("Files copied to \(destFolder.path)")

        let gitDir = destFolder.appendingPathComponent(".git")
        if fm.fileExists(atPath: gitDir.path) {
            try fm.removeItem(at: gitDir)
        }

        progress?(0.75)

        log("Creating symlink for Claude Code...")
        try createSymlink(for: candidate.name)

        progress?(0.82)

        log("Updating skill registry...")
        let repoURL = "https://github.com/\(ownerRepo).git"
        let now = ISO8601DateFormatter().string(from: Date())
        let entry = SkillEntry(
            source: ownerRepo,
            sourceType: "github",
            sourceUrl: repoURL,
            skillPath: candidate.skillPath,
            skillFolderHash: candidate.treeSHA,
            installedAt: now,
            updatedAt: now,
            ref: ref
        )

        try await registry.addSkill(name: candidate.name, entry: entry)

        progress?(0.92)

        log("Registering with Cowork...")
        let skillMDPath = destFolder.appendingPathComponent("SKILL.md")
        if let content = try? String(contentsOf: skillMDPath, encoding: .utf8),
           let metadata = FrontmatterParser.parse(content) {
            try? await coworkRegistry.registerSkill(
                name: candidate.name,
                description: metadata.description,
                installDir: installDirectory
            )
        }

        progress?(1.0)
        return entry
    }

    func installResourceFast(
        ownerRepo: String,
        skillName: String,
        description: String,
        contentFiles: [String],
        toCode: Bool,
        toCowork: Bool,
        progress: ProgressCallback? = nil
    ) async throws -> SkillEntry {
        let fm = FileManager.default
        let parts = ownerRepo.split(separator: "/")
        guard parts.count == 2 else {
            throw SkillManagerError.invalidRepoIdentifier(ownerRepo)
        }

        progress?(0.05)

        log("Downloading tarball for resource \(ownerRepo)...")
        let github = GitHubService(
            token: UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken)
        )
        let tarball = try await github.downloadTarball(
            owner: String(parts[0]), repo: String(parts[1])
        )
        defer { try? fm.removeItem(at: tarball) }
        log("Tarball downloaded")

        progress?(0.50)

        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }
        try await extractTarball(tarball, to: tempDir)

        progress?(0.65)

        log("Generating SKILL.md from \(contentFiles.count) content file(s)...")
        var skillContent = "---\nname: \(skillName)\ndescription: \"\(description)\"\n---\n\n"
        for file in contentFiles {
            let filePath = tempDir.appendingPathComponent(file)
            if let content = try? String(contentsOf: filePath, encoding: .utf8) {
                if contentFiles.count > 1 {
                    skillContent += "# \(file)\n\n"
                }
                skillContent += content + "\n\n"
                log("  Included: \(file)")
            } else {
                log("  Not found: \(file)", level: .error)
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
        log("SKILL.md written to \(destFolder.path)")

        progress?(0.75)

        if toCode {
            log("Creating symlink for Claude Code...")
            try createSymlink(for: skillName)
        }

        progress?(0.85)

        log("Updating skill registry...")
        let repoURL = "https://github.com/\(ownerRepo).git"

        log("Fetching tree hash for consistent update checks...")
        let github2 = GitHubService(
            token: UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken)
        )
        let hash: String
        do {
            let tree = try await github2.fetchTree(
                owner: String(parts[0]), repo: String(parts[1])
            )
            hash = tree.sha
        } catch {
            let hashResult = try await shell.runGit(["hash-object", skillMDPath.path])
            hash = hashResult.success ? hashResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : UUID().uuidString
        }

        let now = ISO8601DateFormatter().string(from: Date())
        let entry = SkillEntry(
            source: ownerRepo,
            sourceType: "github",
            sourceUrl: repoURL,
            skillPath: "SKILL.md",
            skillFolderHash: hash,
            installedAt: now,
            updatedAt: now,
            ref: nil
        )

        try await registry.addSkill(name: skillName, entry: entry)

        progress?(0.92)

        if toCowork {
            log("Registering with Cowork...")
            try? await coworkRegistry.registerSkill(
                name: skillName,
                description: description,
                installDir: installDirectory
            )
        }

        progress?(1.0)
        return entry
    }

    // MARK: - Legacy Install (git clone fallback)

    func install(
        candidate: SkillCandidate,
        repoURL: String,
        ownerRepo: String,
        ref: String? = nil
    ) async throws -> SkillEntry {
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }

        var gitArgs = ["clone", "--depth", "1", "--no-tags", "--single-branch"]
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

        let cloneResult = try await shell.runGit(["clone", "--depth", "1", "--no-tags", "--single-branch", repoURL, tempDir.path])
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

        if toCode {
            try createSymlink(for: skillName)
        }

        let parsedParts = ownerRepo.split(separator: "/")
        let hash: String
        if parsedParts.count == 2 {
            let gh = GitHubService(
                token: UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken)
            )
            do {
                let tree = try await gh.fetchTree(
                    owner: String(parsedParts[0]), repo: String(parsedParts[1])
                )
                hash = tree.sha
            } catch {
                let hashResult = try await shell.runGit(["hash-object", skillMDPath.path])
                hash = hashResult.success ? hashResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : UUID().uuidString
            }
        } else {
            let hashResult = try await shell.runGit(["hash-object", skillMDPath.path])
            hash = hashResult.success ? hashResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines) : UUID().uuidString
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

    func updateFast(
        skillName: String,
        skill: SkillEntry,
        progress: ProgressCallback? = nil
    ) async throws -> SkillEntry {
        let fm = FileManager.default
        let parts = skill.source.split(separator: "/")
        guard parts.count == 2 else {
            throw SkillManagerError.invalidRepoIdentifier(skill.source)
        }
        let owner = String(parts[0])
        let repo = String(parts[1])

        progress?(0.05)
        log("Downloading tarball for update of '\(skillName)'...", level: .step)

        let github = GitHubService(
            token: UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken)
        )
        let tarball = try await github.downloadTarball(
            owner: owner, repo: repo, ref: skill.ref
        )
        defer { try? fm.removeItem(at: tarball) }
        log("Tarball downloaded")

        progress?(0.45)

        let tempDir = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? fm.removeItem(at: tempDir) }
        try await extractTarball(tarball, to: tempDir)

        progress?(0.60)

        let folderPath: String
        if skill.skillPath == "SKILL.md" {
            folderPath = ""
        } else if skill.skillPath.hasSuffix("/SKILL.md") {
            folderPath = String(skill.skillPath.dropLast("/SKILL.md".count))
        } else {
            folderPath = ""
        }

        let sourceFolder: URL
        if folderPath.isEmpty {
            sourceFolder = tempDir
        } else {
            sourceFolder = tempDir.appendingPathComponent(folderPath)
        }

        let skillMDCheck = sourceFolder.appendingPathComponent("SKILL.md")

        if !fm.fileExists(atPath: skillMDCheck.path) {
            // Resource-type skill: SKILL.md was auto-generated, not in repo
            log("No SKILL.md in repo — resource update mode", level: .step)

            let existingPath = installDirectory
                .appendingPathComponent(skillName)
                .appendingPathComponent("SKILL.md")
            let existingContent = (try? String(contentsOf: existingPath, encoding: .utf8)) ?? ""
            let existingMeta = FrontmatterParser.parse(existingContent)
            let name = existingMeta?.name ?? skillName
            let description = existingMeta?.description ?? skillName

            let allFiles = (try? fm.contentsOfDirectory(atPath: sourceFolder.path)) ?? []
            let mdFiles = allFiles
                .filter { $0.hasSuffix(".md") && $0 != "SKILL.md" && !$0.hasPrefix(".") }
                .sorted()

            if mdFiles.isEmpty {
                log("No .md content files found in repo", level: .error)
                throw SkillManagerError.skillNotFoundInRepo(skillName)
            }

            log("Found \(mdFiles.count) content file(s)")

            var skillContent = "---\nname: \(name)\ndescription: \"\(description)\"\n---\n\n"
            for file in mdFiles {
                let filePath = sourceFolder.appendingPathComponent(file)
                if let content = try? String(contentsOf: filePath, encoding: .utf8) {
                    if mdFiles.count > 1 {
                        skillContent += "# \(file)\n\n"
                    }
                    skillContent += content + "\n\n"
                    log("  Included: \(file)")
                }
            }

            progress?(0.70)

            log("Replacing skill files...")
            let destFolder = installDirectory.appendingPathComponent(skillName)
            if fm.fileExists(atPath: destFolder.path) {
                try fm.removeItem(at: destFolder)
            }
            try fm.createDirectory(at: destFolder, withIntermediateDirectories: true)

            let destSkillMD = destFolder.appendingPathComponent("SKILL.md")
            try skillContent.write(to: destSkillMD, atomically: true, encoding: .utf8)
            log("SKILL.md regenerated")

            progress?(0.80)

            log("Updating symlink...")
            try createSymlink(for: skillName)

            progress?(0.85)

            log("Fetching tree hash...")
            let newHash: String
            do {
                let tree = try await github.fetchTree(owner: owner, repo: repo, ref: skill.ref)
                newHash = tree.sha
            } catch {
                let hashResult = try await shell.runGit(["hash-object", destSkillMD.path])
                newHash = hashResult.success
                    ? hashResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
                    : UUID().uuidString
            }

            let now = ISO8601DateFormatter().string(from: Date())
            let updatedEntry = SkillEntry(
                source: skill.source,
                sourceType: skill.sourceType,
                sourceUrl: skill.sourceUrl,
                skillPath: skill.skillPath,
                skillFolderHash: newHash,
                installedAt: skill.installedAt,
                updatedAt: now,
                ref: skill.ref
            )

            try await registry.addSkill(name: skillName, entry: updatedEntry)

            progress?(0.92)

            log("Updating Cowork registration...")
            try? await coworkRegistry.registerSkill(
                name: skillName,
                description: description,
                installDir: installDirectory
            )

            progress?(1.0)
            log("Update of '\(skillName)' complete (resource)", level: .success)
            return updatedEntry
        }

        // Normal skill update — SKILL.md exists in repo
        progress?(0.70)

        log("Replacing skill files...")
        let destFolder = installDirectory.appendingPathComponent(skillName)
        try fm.createDirectory(at: installDirectory, withIntermediateDirectories: true)
        if fm.fileExists(atPath: destFolder.path) {
            try fm.removeItem(at: destFolder)
        }
        try fm.copyItem(at: sourceFolder, to: destFolder)

        let gitDir = destFolder.appendingPathComponent(".git")
        if fm.fileExists(atPath: gitDir.path) {
            try fm.removeItem(at: gitDir)
        }

        progress?(0.80)

        log("Updating symlink...")
        try createSymlink(for: skillName)

        progress?(0.85)

        log("Computing new hash...")
        let hashResult = try await shell.runGit(["hash-object", skillMDCheck.path])
        let newHash = hashResult.success
            ? hashResult.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
            : UUID().uuidString

        let now = ISO8601DateFormatter().string(from: Date())
        let updatedEntry = SkillEntry(
            source: skill.source,
            sourceType: skill.sourceType,
            sourceUrl: skill.sourceUrl,
            skillPath: skill.skillPath,
            skillFolderHash: newHash,
            installedAt: skill.installedAt,
            updatedAt: now,
            ref: skill.ref
        )

        try await registry.addSkill(name: skillName, entry: updatedEntry)

        progress?(0.92)

        log("Updating Cowork registration...")
        let destSkillMD = destFolder.appendingPathComponent("SKILL.md")
        if let content = try? String(contentsOf: destSkillMD, encoding: .utf8),
           let metadata = FrontmatterParser.parse(content) {
            try? await coworkRegistry.registerSkill(
                name: skillName,
                description: metadata.description,
                installDir: installDirectory
            )
        }

        progress?(1.0)
        log("Update of '\(skillName)' complete", level: .success)
        return updatedEntry
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
