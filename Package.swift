// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ShelfD",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "ShelfDCore", path: "Sources/ShelfDCore"),
        .executableTarget(
            name: "ShelfD",
            dependencies: ["ShelfDCore"],
            path: "Sources/ShelfD"
        ),
        .testTarget(
            name: "ShelfDTests",
            dependencies: ["ShelfDCore"],
            path: "Tests/ShelfDTests"
        ),
    ],
    swiftLanguageModes: [.v5]
)
