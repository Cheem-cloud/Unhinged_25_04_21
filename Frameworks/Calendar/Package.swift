// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Calendar",
    platforms: [
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "Calendar",
            targets: ["Calendar"]),
    ],
    dependencies: [
        .package(path: "../Core"),
        .package(path: "../Services"),
        // Other dependencies go here
    ],
    targets: [
        .target(
            name: "Calendar",
            dependencies: ["Core", "Services"],
            path: "Sources"),
        .testTarget(
            name: "CalendarTests",
            dependencies: ["Calendar"],
            path: "Tests"),
    ]
) 