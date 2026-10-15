import Foundation
import SwiftUI

@MainActor @Observable
class FindSkillViewModel {
    var searchQuery = ""
    var state: FindState = .idle
    var results: [SkillSearchResult] = []
    var installingSkillID: String?
    var installSuccess: String?
    var errorMessage: String?

    // Install confirmation
    var pendingInstall: SkillSearchResult?
    var installToCode = true
    var installToCowork = true

    private nonisolated static let excludedFiles: Set<String> = [
        "LICENSE.md", "LICENSE", "CONTRIBUTING.md", "CHANGELOG.md",
        "CODE_OF_CONDUCT.md", "SECURITY.md", ".github"
    ]

    enum FindState {
        case idle
        case searching
        case results
        case noResults
    }

    private let installer: SkillInstaller

    init() {
        self.installer = SkillInstaller()
    }

    private func makeGitHub() -> GitHubService {
        let token = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken)
        return GitHubService(token: token)
    }

    var hasToken: Bool {
        let token = UserDefaults.standard.string(forKey: Constants.UserDefaultsKeys.githubToken)
        return token != nil && !(token?.isEmpty ?? true)
    }

    // MARK: - Search

    func search() async {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }

        state = .searching
        errorMessage = nil
        installSuccess = nil

        let github = makeGitHub()

        do {
            var allResults: [SkillSearchResult] = []

            // Code Search for actual skills (if token available)
            if hasToken {
                if let response = try? await github.searchSkills(query: query) {
                    let skillResults = response.items.prefix(15).compactMap { buildQuickResult(from: $0) }
                    allResults.append(contentsOf: skillResults)
                }
            }

            // Repo Search (finds by name, works without token)
            let repos = try await github.searchRepositories(query: query)
            let repoResults = await analyzeRepos(Array(repos.prefix(12)), github: github)

            // Merge, deduplicate, sort by stars
            let existingIDs = Set(allResults.map(\.id))
            for result in repoResults where !existingIDs.contains(result.id) {
                allResults.append(result)
            }

            results = allResults.sorted { $0.stars > $1.stars }
            state = results.isEmpty ? .noResults : .results
        } catch {
            errorMessage = error.localizedDescription
            state = .idle
        }
    }

    private nonisolated func buildQuickResult(from item: GitHubCodeSearchItem) -> SkillSearchResult? {
        let folderPath: String
        if item.path == "SKILL.md" {
            folderPath = ""
        } else if item.path.hasSuffix("/SKILL.md") {
            folderPath = String(item.path.dropLast("/SKILL.md".count))
        } else {
            return nil
        }

        let skillName: String
        if folderPath.isEmpty {
            let parts = item.repository.fullName.split(separator: "/")
            skillName = parts.count == 2 ? String(parts[1]) : folderPath
        } else if let lastSlash = folderPath.lastIndex(of: "/") {
            skillName = String(folderPath[folderPath.index(after: lastSlash)...])
        } else {
            skillName = folderPath
        }

        return SkillSearchResult(
            id: "\(item.repository.fullName)/\(folderPath)",
            skillName: skillName,
            skillDescription: item.repository.description ?? "",
            repoFullName: item.repository.fullName,
            stars: item.repository.stargazersCount ?? 0,
            skillPath: item.path,
            folderPath: folderPath,
            repoType: .skill
        )
    }

    // MARK: - Repo Analysis

    private func analyzeRepos(_ repos: [GitHubRepo], github: GitHubService) async -> [SkillSearchResult] {
        await withTaskGroup(of: [SkillSearchResult].self, returning: [SkillSearchResult].self) { group in
            for repo in repos {
                group.addTask {
                    await self.analyzeRepo(repo, github: github)
                }
            }
            var all: [SkillSearchResult] = []
            for await batch in group {
                all.append(contentsOf: batch)
            }
            return all
        }
    }

    private nonisolated func analyzeRepo(_ repo: GitHubRepo, github: GitHubService) async -> [SkillSearchResult] {
        let parts = repo.fullName.split(separator: "/")
        guard parts.count == 2 else { return [] }
        let owner = String(parts[0])
        let repoName = String(parts[1])

        guard let tree = try? await github.fetchTree(owner: owner, repo: repoName, ref: repo.defaultBranch) else {
            return []
        }

        let candidates = github.findSkillCandidates(in: tree)

        if !candidates.isEmpty {
            // It's a skill repo
            return candidates.prefix(3).map { candidate in
                SkillSearchResult(
                    id: "\(repo.fullName)/\(candidate.folderPath)",
                    skillName: candidate.name,
                    skillDescription: repo.description ?? "",
                    repoFullName: repo.fullName,
                    stars: repo.stargazersCount,
                    skillPath: candidate.skillPath,
                    folderPath: candidate.folderPath,
                    repoType: .skill
                )
            }
        }

        // No SKILL.md -- check for useful .md content files
        let mdFiles = tree.tree.filter { entry in
            entry.type == "blob"
            && entry.path.hasSuffix(".md")
            && !entry.path.contains("/")
            && !Self.excludedFiles.contains(entry.path)
        }.map(\.path)

        guard !mdFiles.isEmpty else { return [] }

        let name = repoName
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")

        return [SkillSearchResult(
            id: "\(repo.fullName)/",
            skillName: name,
            skillDescription: repo.description ?? "",
            repoFullName: repo.fullName,
            stars: repo.stargazersCount,
            skillPath: "",
            folderPath: "",
            repoType: .resource,
            contentFiles: mdFiles
        )]
    }

    // MARK: - Install

    func requestInstall(_ result: SkillSearchResult) {
        pendingInstall = result
        installToCode = true
        installToCowork = true
    }

    func cancelInstall() {
        pendingInstall = nil
    }

    func confirmInstall() async {
        guard let result = pendingInstall else { return }
        pendingInstall = nil

        installingSkillID = result.id
        installSuccess = nil
        errorMessage = nil

        let repoURL = "https://github.com/\(result.repoFullName).git"

        do {
            switch result.repoType {
            case .skill:
                try await installSkill(result, repoURL: repoURL)
            case .resource:
                try await installResource(result, repoURL: repoURL)
            }

            installSuccess = result.skillName
            results.removeAll { $0.id == result.id }
        } catch {
            errorMessage = error.localizedDescription
        }

        installingSkillID = nil
    }

    private func installSkill(_ result: SkillSearchResult, repoURL: String) async throws {
        let parts = result.repoFullName.split(separator: "/")
        guard parts.count == 2 else { throw SkillManagerError.invalidRepoIdentifier(result.repoFullName) }

        let github = makeGitHub()
        let tree = try await github.fetchTree(owner: String(parts[0]), repo: String(parts[1]))
        let candidates = github.findSkillCandidates(in: tree)

        guard let candidate = candidates.first(where: { $0.skillPath == result.skillPath }) else {
            throw SkillManagerError.skillNotFoundInRepo(result.skillName)
        }

        let _ = try await installer.install(
            candidate: candidate,
            repoURL: repoURL,
            ownerRepo: result.repoFullName
        )

        // Adjust environments after install
        if !installToCode {
            try await installer.removeSymlink(for: candidate.name)
        }
        if !installToCowork {
            let cowork = CoworkRegistry()
            try? await cowork.unregisterSkill(name: candidate.name)
        }
    }

    private func installResource(_ result: SkillSearchResult, repoURL: String) async throws {
        let skillName = result.repoFullName.split(separator: "/").last
            .map(String.init) ?? result.skillName

        let _ = try await installer.installResource(
            repoURL: repoURL,
            ownerRepo: result.repoFullName,
            skillName: skillName,
            description: result.skillDescription,
            contentFiles: result.contentFiles,
            toCode: installToCode,
            toCowork: installToCowork
        )
    }
}
