// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Features",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Features",
            targets: ["Features"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Services"),
        .package(path: "../UI"),
        .package(path: "../Calendar"),
        .package(path: "../Authentication"),
        // Other dependencies go here
    ],
    targets: [
        .target(
            name: "Features",
            dependencies: ["Core", "Services", "UI", "Calendar", "Authentication"],
            path: "Sources"),
        .testTarget(
            name: "FeaturesTests",
            dependencies: ["Features"],
            path: "Tests"),
    ]
) 