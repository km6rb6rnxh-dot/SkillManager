import Foundation
import SwiftUI

@MainActor @Observable
class SkillListViewModel {
    var skills: [Skill] = []
    var selectedSkillID: String?
    var isLoading = false
    var isCheckingUpdates = false
    var showAddSheet = false
    var showFindSheet = false
    var errorMessage: String?
    var searchText = ""
    var updatingSkillID: String?
    var updateProgress: Double = 0

    private let registry: SkillRegistry
    private let github: GitHubService
    private let installer: SkillInstaller
    private let updateChecker: UpdateChecker
    private let coworkRegistry: CoworkRegistry
    private let shell: ShellRunner

    var filteredSkills: [Skill] {
        if searchText.isEmpty {
            return skills.sorted { $0.id < $1.id }
        }
        return skills.filter {
            $0.id.localizedCaseInsensitiveContains(searchText) ||
            $0.entry.source.localizedCaseInsensitiveContains(searchText) ||
            ($0.metadata?.description ?? "").localizedCaseInsensitiveContains(searchText)
        }.sorted { $0.id < $1.id }
    }

    var selectedSkill: Skill? {
        skills.first { $0.id == selectedSkillID }
    }

    var skillsWithUpdates: [Skill] {
        skills.filter {
            if case .updateAvailable = $0.updateStatus { return true }
            return false
        }
    }

    init() {
        let shell = ShellRunner()
        let registry = SkillRegistry()
        let token = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken)
        let github = GitHubService(token: token)
        let coworkRegistry = CoworkRegistry()

        self.shell = shell
        self.registry = registry
        self.github = github
        self.coworkRegistry = coworkRegistry
        self.installer = SkillInstaller(shell: shell, registry: registry, coworkRegistry: coworkRegistry)
        self.updateChecker = UpdateChecker(github: github)
    }

    func loadSkills() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let (entries, _) = try await registry.load()

            let installDir = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.installDirectory)
                .map { URL(fileURLWithPath: $0) } ?? Constants.defaultSkillsInstallDirectory

            let claudeSkillsDir = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.claudeSkillsDirectory)
                .map { URL(fileURLWithPath: $0) } ?? Constants.defaultClaudeSkillsDirectory

            skills = await withTaskGroup(of: Skill.self, returning: [Skill].self) { group in
                for (name, entry) in entries {
                    group.addTask {
                        var skill = Skill(id: name, entry: entry)

                        let skillMDPath = installDir
                            .appendingPathComponent(name)
                            .appendingPathComponent("SKILL.md")

                        if let content = try? String(contentsOf: skillMDPath, encoding: .utf8) {
                            skill.metadata = FrontmatterParser.parse(content)
                        }

                        let symlinkPath = claudeSkillsDir.appendingPathComponent(name)
                        let hasSymlink = (try? FileManager.default.destinationOfSymbolicLink(atPath: symlinkPath.path)) != nil
                        let inCowork = await self.coworkRegistry.isSkillRegistered(name: name)

                        skill.environment = SkillEnvironment(code: hasSymlink, cowork: inCowork)

                        return skill
                    }
                }

                var results: [Skill] = []
                for await skill in group {
                    results.append(skill)
                }
                return results
            }

            let autoCheck = UserDefaults.standard.object(forKey: Constants.UserDefaultsKeys.autoCheckUpdates) as? Bool ?? true
            if autoCheck {
                await checkForUpdates()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func checkForUpdates() async {
        let log = InstallLogger.shared
        log.step("Checking updates for \(skills.count) skill(s)...")

        isCheckingUpdates = true

        for i in skills.indices {
            skills[i].updateStatus = .checking
        }

        let results = await updateChecker.checkAll(skills: skills)

        var updatesFound = 0
        var errors = 0
        for i in skills.indices {
            if let status = results[skills[i].id] {
                skills[i].updateStatus = status
                if case .updateAvailable = status { updatesFound += 1 }
                if case .error(let msg) = status {
                    errors += 1
                    log.error("Check failed for '\(skills[i].id)': \(msg)")
                }
            }
        }

        if updatesFound > 0 {
            log.log("\(updatesFound) update(s) available")
        } else if errors == 0 {
            log.success("All skills up to date")
        } else {
            log.log("\(errors) skill(s) could not be checked")
        }

        isCheckingUpdates = false
    }

    func updateSkill(_ skill: Skill) async {
        guard case .updateAvailable = skill.updateStatus else { return }

        let log = InstallLogger.shared
        log.step("Updating '\(skill.id)' from \(skill.entry.source)...")
        log.log("Current hash: \(skill.entry.skillFolderHash.prefix(12))..., skillPath: \(skill.entry.skillPath)")

        updatingSkillID = skill.id
        updateProgress = 0

        do {
            let progressCallback: @Sendable (Double) -> Void = { [weak self] value in
                Task { @MainActor in
                    withAnimation(.easeOut(duration: 0.25)) {
                        self?.updateProgress = value
                    }
                }
            }

            let _ = try await installer.updateFast(
                skillName: skill.id,
                skill: skill.entry,
                progress: progressCallback
            )

            withAnimation { updateProgress = 1.0 }
            try? await Task.sleep(for: .milliseconds(300))

            await loadSkills()
        } catch {
            log.error("Update failed for '\(skill.id)': \(error.localizedDescription)")
            errorMessage = error.localizedDescription
        }

        updateProgress = 0
        updatingSkillID = nil
    }

    func updateAll() async {
        let toUpdate = skillsWithUpdates
        let log = InstallLogger.shared
        log.step("Updating \(toUpdate.count) skill(s)...")

        for skill in toUpdate {
            await updateSkill(skill)
        }

        log.success("Update all complete")
    }

    func removeSkill(_ skill: Skill) async {
        do {
            try await installer.remove(skillName: skill.id)
            skills.removeAll { $0.id == skill.id }
            if selectedSkillID == skill.id {
                selectedSkillID = nil
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func revealInFinder(_ skill: Skill) {
        let installDir = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.installDirectory)
            .map { URL(fileURLWithPath: $0) } ?? Constants.defaultSkillsInstallDirectory
        let path = installDir.appendingPathComponent(skill.id)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path.path)
    }

    func openInGitHub(_ skill: Skill) {
        if let url = skill.repoURL {
            NSWorkspace.shared.open(url)
        }
    }

    func toggleCodeEnvironment(for skill: Skill) async {
        guard let idx = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        do {
            if skill.environment.code {
                try await installer.removeSymlink(for: skill.id)
            } else {
                try await installer.createSymlink(for: skill.id)
            }
            skills[idx].environment.code.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCoworkEnvironment(for skill: Skill) async {
        guard let idx = skills.firstIndex(where: { $0.id == skill.id }) else { return }
        do {
            if skill.environment.cowork {
                try await coworkRegistry.unregisterSkill(name: skill.id)
            } else {
                let installDir = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.installDirectory)
                    .map { URL(fileURLWithPath: $0) } ?? Constants.defaultSkillsInstallDirectory
                let description = skill.metadata?.description ?? skill.id
                try await coworkRegistry.registerSkill(
                    name: skill.id,
                    description: description,
                    installDir: installDir
                )
            }
            skills[idx].environment.cowork.toggle()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
