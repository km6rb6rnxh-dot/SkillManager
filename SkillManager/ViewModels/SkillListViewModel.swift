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
        isCheckingUpdates = true

        for i in skills.indices {
            skills[i].updateStatus = .checking
        }

        let results = await updateChecker.checkAll(skills: skills)

        for i in skills.indices {
            if let status = results[skills[i].id] {
                skills[i].updateStatus = status
            }
        }

        isCheckingUpdates = false
    }

    func updateSkill(_ skill: Skill) async {
        guard case .updateAvailable = skill.updateStatus else { return }

        let parts = skill.entry.source.split(separator: "/")
        guard parts.count == 2 else { return }

        do {
            let tree = try await github.fetchTree(
                owner: String(parts[0]),
                repo: String(parts[1]),
                ref: skill.entry.ref
            )

            let candidates = github.findSkillCandidates(in: tree)
            guard let candidate = candidates.first(where: { $0.skillPath == skill.entry.skillPath }) else {
                errorMessage = "Skill not found in remote repository"
                return
            }

            let _ = try await installer.update(
                skillName: skill.id,
                candidate: candidate,
                repoURL: skill.entry.sourceUrl,
                ownerRepo: skill.entry.source,
                ref: skill.entry.ref
            )

            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateAll() async {
        for skill in skillsWithUpdates {
            await updateSkill(skill)
        }
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
