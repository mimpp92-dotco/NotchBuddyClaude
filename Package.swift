// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "ClaudeNotchBuddy",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "ClaudeNotchBuddy",
            path: "Sources/ClaudeNotchBuddy",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
