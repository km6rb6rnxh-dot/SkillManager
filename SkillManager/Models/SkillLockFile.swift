import Foundation

struct SkillEntry: Codable, Equatable {
    var source: String
    var sourceType: String
    var sourceUrl: String
    var skillPath: String
    var skillFolderHash: String
    var installedAt: String
    var updatedAt: String
    var ref: String?
    var pluginName: String?
}
