import Foundation

struct GitHubRepo: Codable {
    let fullName: String
    let description: String?
    let htmlUrl: String
    let defaultBranch: String
    let stargazersCount: Int
    let pushedAt: String?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case description
        case htmlUrl = "html_url"
        case defaultBranch = "default_branch"
        case stargazersCount = "stargazers_count"
        case pushedAt = "pushed_at"
    }
}

struct GitHubTreeResponse: Codable {
    let sha: String
    let tree: [GitHubTreeEntry]
    let truncated: Bool?
}

struct GitHubTreeEntry: Codable {
    let path: String
    let mode: String?
    let type: String
    let sha: String
    let size: Int?
}

struct SkillCandidate: Identifiable, Hashable {
    var id: String { folderPath }
    let name: String
    let skillPath: String
    let folderPath: String
    let treeSHA: String
}

struct GitHubCodeSearchResponse: Codable {
    let totalCount: Int
    let items: [GitHubCodeSearchItem]

    enum CodingKeys: String, CodingKey {
        case totalCount = "total_count"
        case items
    }
}

struct GitHubCodeSearchItem: Codable {
    let name: String
    let path: String
    let sha: String
    let htmlUrl: String
    let repository: GitHubSearchRepository

    enum CodingKeys: String, CodingKey {
        case name, path, sha
        case htmlUrl = "html_url"
        case repository
    }
}

struct GitHubSearchRepository: Codable {
    let fullName: String
    let htmlUrl: String
    let description: String?
    let stargazersCount: Int?

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case htmlUrl = "html_url"
        case description
        case stargazersCount = "stargazers_count"
    }
}

enum RepoType: String {
    case skill
    case resource
}

struct SkillSearchResult: Identifiable {
    let id: String
    let skillName: String
    let skillDescription: String
    let repoFullName: String
    let stars: Int
    let skillPath: String
    let folderPath: String
    let repoType: RepoType
    var contentFiles: [String] = []
}
