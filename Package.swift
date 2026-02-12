// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LLMUsage",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "LLMUsage", targets: ["LLMUsage"]),
        .executable(name: "llmusage-cli", targets: ["llmusage-cli"]),
        .executable(name: "llmusage-menubar", targets: ["llmusage-menubar"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0")
    ],
    targets: [
        .target(
            name: "LLMUsage",
            dependencies: [],
            path: "Sources/LLMUsage"
        ),
        .executableTarget(
            name: "llmusage-cli",
            dependencies: [
                "LLMUsage",
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ],
            path: "Sources/llmusage-cli"
        ),
        .executableTarget(
            name: "llmusage-menubar",
            dependencies: ["LLMUsage"],
            path: "Sources/llmusage-menubar",
            exclude: ["Resources/Info.plist"],
            resources: [.copy("Resources/ServiceLogos")]
        ),
        .testTarget(
            name: "LLMUsageTests",
            dependencies: ["LLMUsage"],
            path: "Tests/LLMUsageTests"
        )
    ]
)
