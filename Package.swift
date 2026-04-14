// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TypingLens",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "TypingLens", targets: ["TypingLens"])
    ],
    targets: [
        .executableTarget(
            name: "TypingLens",
            path: "Sources/TypingLens"
        ),
        .testTarget(
            name: "TypingLensTests",
            dependencies: ["TypingLens"],
            path: "Tests/TypingLensTests"
        )
    ]
)
