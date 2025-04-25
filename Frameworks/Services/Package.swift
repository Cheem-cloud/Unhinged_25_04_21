// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Services",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Services",
            targets: ["Services"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        // Other dependencies go here
    ],
    targets: [
        .target(
            name: "Services",
            dependencies: ["Core"],
            path: "Sources"),
        .testTarget(
            name: "ServicesTests",
            dependencies: ["Services"],
            path: "Tests"),
    ]
) 