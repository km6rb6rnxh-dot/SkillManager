import Foundation

actor GitHubService {
    private let session: URLSession
    private let baseURL = Constants.gitHubAPIBase
    private var token: String?

    init(session: URLSession = .shared, token: String? = nil) {
        self.session = session
        self.token = token
    }

    func setToken(_ token: String?) {
        self.token = token
    }

    private func makeRequest(path: String) -> URLRequest {
        var request = URLRequest(url: URL(string: "\(baseURL)\(path)")!)
        request.setValue(Constants.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        if let token, !token.isEmpty {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    func fetchRepo(owner: String, repo: String) async throws -> GitHubRepo {
        let request = makeRequest(path: "/repos/\(owner)/\(repo)")
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try JSONDecoder().decode(GitHubRepo.self, from: data)
    }

    func fetchTree(owner: String, repo: String, ref: String? = nil) async throws -> GitHubTreeResponse {
        let branch = ref ?? "HEAD"
        let request = makeRequest(path: "/repos/\(owner)/\(repo)/git/trees/\(branch)?recursive=1")
        let (data, response) = try await session.data(for: request)

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404, branch == "HEAD" {
            let mainRequest = makeRequest(path: "/repos/\(owner)/\(repo)/git/trees/main?recursive=1")
            let (mainData, mainResponse) = try await session.data(for: mainRequest)

            if let mainHttp = mainResponse as? HTTPURLResponse, mainHttp.statusCode == 404 {
                let masterRequest = makeRequest(path: "/repos/\(owner)/\(repo)/git/trees/master?recursive=1")
                let (masterData, masterResponse) = try await session.data(for: masterRequest)
                try checkResponse(masterResponse, data: masterData)
                return try JSONDecoder().decode(GitHubTreeResponse.self, from: masterData)
            }

            try checkResponse(mainResponse, data: mainData)
            return try JSONDecoder().decode(GitHubTreeResponse.self, from: mainData)
        }

        try checkResponse(response, data: data)
        return try JSONDecoder().decode(GitHubTreeResponse.self, from: data)
    }

    nonisolated func findSkillCandidates(in tree: GitHubTreeResponse) -> [SkillCandidate] {
        let skillMDs = tree.tree.filter { entry in
            entry.type == "blob" && entry.path.hasSuffix("SKILL.md")
        }

        var candidates: [SkillCandidate] = []

        for skillMD in skillMDs {
            let folderPath: String
            if skillMD.path == "SKILL.md" {
                folderPath = ""
            } else {
                folderPath = String(skillMD.path.dropLast("/SKILL.md".count))
            }

            let name: String
            if folderPath.isEmpty {
                name = "root"
            } else if let lastSlash = folderPath.lastIndex(of: "/") {
                name = String(folderPath[folderPath.index(after: lastSlash)...])
            } else {
                name = folderPath
            }

            let treeSHA: String
            if folderPath.isEmpty {
                treeSHA = tree.sha
            } else if let treeEntry = tree.tree.first(where: { $0.path == folderPath && $0.type == "tree" }) {
                treeSHA = treeEntry.sha
            } else {
                continue
            }

            candidates.append(SkillCandidate(
                name: name,
                skillPath: skillMD.path,
                folderPath: folderPath,
                treeSHA: treeSHA
            ))
        }

        let priorityPrefixes = ["skills/", ".agents/skills/", ".claude/skills/"]
        return candidates.sorted { a, b in
            let aOrder = priorityPrefixes.firstIndex(where: { a.folderPath.hasPrefix($0) }) ?? priorityPrefixes.count
            let bOrder = priorityPrefixes.firstIndex(where: { b.folderPath.hasPrefix($0) }) ?? priorityPrefixes.count
            if aOrder != bOrder { return aOrder < bOrder }
            return a.name < b.name
        }
    }

    nonisolated func getSkillFolderHash(from tree: GitHubTreeResponse, skillPath: String) -> String? {
        let folderPath: String
        if skillPath == "SKILL.md" {
            return tree.sha
        } else if skillPath.hasSuffix("/SKILL.md") {
            folderPath = String(skillPath.dropLast("/SKILL.md".count))
        } else {
            let components = skillPath.split(separator: "/")
            if components.count >= 2 {
                folderPath = components.dropLast().joined(separator: "/")
            } else {
                return nil
            }
        }

        return tree.tree.first(where: { $0.path == folderPath && $0.type == "tree" })?.sha
    }

    func searchSkills(query: String) async throws -> GitHubCodeSearchResponse {
        let searchTerms = "filename:SKILL.md \(query)"
        guard let encoded = searchTerms.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw SkillManagerError.apiError(statusCode: 0, message: "Invalid search query")
        }
        let request = makeRequest(path: "/search/code?q=\(encoded)")
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return try JSONDecoder().decode(GitHubCodeSearchResponse.self, from: data)
    }

    func searchRepositories(query: String) async throws -> [GitHubRepo] {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            throw SkillManagerError.apiError(statusCode: 0, message: "Invalid search query")
        }
        let request = makeRequest(path: "/search/repositories?q=\(encoded)&per_page=30")
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)

        struct RepoSearchResponse: Codable {
            let totalCount: Int
            let items: [GitHubRepo]

            enum CodingKeys: String, CodingKey {
                case totalCount = "total_count"
                case items
            }
        }

        return try JSONDecoder().decode(RepoSearchResponse.self, from: data).items
    }

    func fetchFileContent(owner: String, repo: String, path: String) async throws -> String {
        var request = makeRequest(path: "/repos/\(owner)/\(repo)/contents/\(path)")
        request.setValue("application/vnd.github.raw+json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        try checkResponse(response, data: data)
        return String(data: data, encoding: .utf8) ?? ""
    }

    nonisolated static func parseRepoIdentifier(_ input: String) -> (owner: String, repo: String)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.contains("github.com") {
            let cleaned = trimmed
                .replacingOccurrences(of: "https://", with: "")
                .replacingOccurrences(of: "http://", with: "")
                .replacingOccurrences(of: "github.com/", with: "")
                .replacingOccurrences(of: ".git", with: "")
            let parts = cleaned.split(separator: "/").map(String.init)
            guard parts.count >= 2 else { return nil }
            return (parts[0], parts[1])
        }

        let parts = trimmed.split(separator: "/").map(String.init)
        guard parts.count == 2,
              !parts[0].isEmpty,
              !parts[1].isEmpty else { return nil }
        return (parts[0], parts[1])
    }

    private func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }

        switch http.statusCode {
        case 200..<300:
            return
        case 403:
            let resetHeader = http.value(forHTTPHeaderField: "X-RateLimit-Reset")
            let resetDate = resetHeader.flatMap { Double($0) }.map { Date(timeIntervalSince1970: $0) }
            throw SkillManagerError.rateLimited(resetDate: resetDate)
        case 404:
            throw SkillManagerError.repoNotFound("Resource not found")
        default:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SkillManagerError.apiError(statusCode: http.statusCode, message: message)
        }
    }
}
