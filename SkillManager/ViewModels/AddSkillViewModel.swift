import Foundation

@MainActor @Observable
class AddSkillViewModel {
    var repoInput: String = ""
    var state: AddSkillState = .idle
    var repoInfo: GitHubRepo?
    var candidates: [SkillCandidate] = []
    var selectedCandidateIDs: Set<String> = []
    var installProgress: String = ""
    var error: String?

    private let github: GitHubService
    private let installer: SkillInstaller

    enum AddSkillState: Equatable {
        case idle
        case fetching
        case selectingSkills
        case installing
        case completed(count: Int)
        case error(String)

        static func == (lhs: AddSkillState, rhs: AddSkillState) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.fetching, .fetching),
                 (.selectingSkills, .selectingSkills), (.installing, .installing):
                return true
            case (.completed(let a), .completed(let b)):
                return a == b
            case (.error(let a), .error(let b)):
                return a == b
            default:
                return false
            }
        }
    }

    init() {
        self.github = GitHubService()
        self.installer = SkillInstaller()
    }

    func fetch() async {
        guard let (owner, repo) = GitHubService.parseRepoIdentifier(repoInput) else {
            state = .error("Invalid repository format. Use owner/repo or a GitHub URL.")
            return
        }

        state = .fetching

        do {
            repoInfo = try await github.fetchRepo(owner: owner, repo: repo)
            let tree = try await github.fetchTree(
                owner: owner,
                repo: repo,
                ref: repoInfo?.defaultBranch
            )
            candidates = github.findSkillCandidates(in: tree)

            if candidates.isEmpty {
                state = .error("No skills found in this repository.")
                return
            }

            if candidates.count == 1 {
                selectedCandidateIDs = Set(candidates.map(\.id))
            }

            state = .selectingSkills
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func installSelected() async {
        guard let repoInfo, !selectedCandidateIDs.isEmpty else { return }

        state = .installing
        var installedCount = 0

        let ownerRepo = repoInfo.fullName
        let repoURL = "https://github.com/\(ownerRepo).git"

        let toInstall = candidates.filter { selectedCandidateIDs.contains($0.id) }

        for candidate in toInstall {
            installProgress = "Installing \(candidate.name)..."

            do {
                let _ = try await installer.install(
                    candidate: candidate,
                    repoURL: repoURL,
                    ownerRepo: ownerRepo
                )
                installedCount += 1
            } catch {
                self.error = "Failed to install \(candidate.name): \(error.localizedDescription)"
            }
        }

        state = .completed(count: installedCount)
    }

    func reset() {
        repoInput = ""
        state = .idle
        repoInfo = nil
        candidates = []
        selectedCandidateIDs = []
        installProgress = ""
        error = nil
    }
}
