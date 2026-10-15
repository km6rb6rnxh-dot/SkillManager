// swift-tools-version:6.2
import PackageDescription

let package = Package(
    name: "SkillManager",
    platforms: [.macOS(.v26)],
    targets: [
        .executableTarget(
            name: "SkillManager",
            path: "SkillManager",
            exclude: ["Resources"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        )
    ]
)
