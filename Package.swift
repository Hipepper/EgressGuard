// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "EgressGuard",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "EgressGuard", targets: ["EgressGuard"])
    ],
    targets: [
        .executableTarget(
            name: "EgressGuard",
            path: "Sources/EgressGuard"
        ),
        .testTarget(
            name: "EgressGuardTests",
            dependencies: ["EgressGuard"],
            path: "Tests/EgressGuardTests"
        )
    ]
)
