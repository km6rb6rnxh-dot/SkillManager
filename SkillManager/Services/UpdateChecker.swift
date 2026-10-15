import Foundation

actor UpdateChecker {
    private let github: GitHubService

    init(github: GitHubService = GitHubService()) {
        self.github = github
    }

    func checkAll(skills: [Skill]) async -> [String: UpdateStatus] {
        var grouped: [String: [Skill]] = [:]
        for skill in skills {
            let key = "\(skill.entry.source)|\(skill.entry.ref ?? "")"
            grouped[key, default: []].append(skill)
        }

        var results: [String: UpdateStatus] = [:]

        await withTaskGroup(of: [(String, UpdateStatus)].self) { group in
            for (_, skillsInGroup) in grouped {
                group.addTask {
                    await self.checkGroup(skillsInGroup)
                }
            }

            for await groupResults in group {
                for (name, status) in groupResults {
                    results[name] = status
                }
            }
        }

        return results
    }

    private func checkGroup(_ skills: [Skill]) async -> [(String, UpdateStatus)] {
        guard let first = skills.first else { return [] }

        let ownerRepo = first.entry.source
        let parts = ownerRepo.split(separator: "/")
        guard parts.count == 2 else {
            return skills.map { ($0.id, .error("Invalid source: \(ownerRepo)")) }
        }

        let owner = String(parts[0])
        let repo = String(parts[1])

        do {
            let tree = try await github.fetchTree(owner: owner, repo: repo, ref: first.entry.ref)

            return skills.map { skill in
                guard let remoteHash = github.getSkillFolderHash(from: tree, skillPath: skill.entry.skillPath) else {
                    return (skill.id, UpdateStatus.error("Skill not found in remote repo"))
                }

                if remoteHash == skill.entry.skillFolderHash {
                    return (skill.id, UpdateStatus.upToDate)
                } else {
                    return (skill.id, UpdateStatus.updateAvailable(latestTreeSHA: remoteHash))
                }
            }
        } catch {
            return skills.map { ($0.id, UpdateStatus.error(error.localizedDescription)) }
        }
    }
}
