// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypingLens",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TypingLens", targets: ["TypingLens"]),
        .executable(name: "TypingLensControl", targets: ["TypingLensControl"])
    ],
    targets: [
        .executableTarget(
            name: "TypingLens",
            path: "Sources/TypingLens",
            resources: [
                .process("Resources")
            ]
        ),
        .executableTarget(
            name: "TypingLensControl",
            path: "Sources/TypingLensControl"
        ),
        .testTarget(
            name: "TypingLensTests",
            dependencies: ["TypingLens"],
            path: "Tests/TypingLensTests"
        )
    ]
)
