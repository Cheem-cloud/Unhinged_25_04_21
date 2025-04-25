// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Authentication",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Authentication",
            targets: ["Authentication"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Services"),
        // Other dependencies go here
    ],
    targets: [
        .target(
            name: "Authentication",
            dependencies: ["Core", "Services"],
            path: "Sources"),
        .testTarget(
            name: "AuthenticationTests",
            dependencies: ["Authentication"],
            path: "Tests"),
    ]
) 