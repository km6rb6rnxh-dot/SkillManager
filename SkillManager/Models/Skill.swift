import Foundation

enum UpdateStatus: Equatable {
    case unknown
    case checking
    case upToDate
    case updateAvailable(latestTreeSHA: String)
    case error(String)
}

struct SkillEnvironment: Equatable {
    var code: Bool = false
    var cowork: Bool = false

    var label: String {
        switch (code, cowork) {
        case (true, true): return "Code + Cowork"
        case (true, false): return "Code"
        case (false, true): return "Cowork"
        case (false, false): return "—"
        }
    }
}

struct Skill: Identifiable, Equatable {
    let id: String
    let entry: SkillEntry
    var metadata: SkillMetadata?
    var updateStatus: UpdateStatus = .unknown
    var environment: SkillEnvironment = SkillEnvironment()

    var ownerRepo: String { entry.source }

    var repoURL: URL? {
        URL(string: entry.sourceUrl.replacingOccurrences(of: ".git", with: ""))
    }

    var installDate: Date? {
        ISO8601DateFormatter().date(from: entry.installedAt)
    }

    var updateDate: Date? {
        ISO8601DateFormatter().date(from: entry.updatedAt)
    }

    static func == (lhs: Skill, rhs: Skill) -> Bool {
        lhs.id == rhs.id && lhs.entry == rhs.entry && lhs.updateStatus == rhs.updateStatus && lhs.environment == rhs.environment
    }
}
