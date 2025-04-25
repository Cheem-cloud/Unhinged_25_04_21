// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "UI",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "UI",
            targets: ["UI"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        // Other dependencies go here
    ],
    targets: [
        .target(
            name: "UI",
            dependencies: ["Core"],
            path: "Sources"),
        .testTarget(
            name: "UITests",
            dependencies: ["UI"],
            path: "Tests"),
    ]
) 