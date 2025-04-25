// swift-tools-version: 5.7
import PackageDescription

let package = Package(
    name: "Unhinged",
    platforms: [
        .iOS(.v16),
        .macOS(.v13)
    ],
    products: [
        .library(name: "Core", targets: ["Core"]),
        .library(name: "Services", targets: ["Services"]),
        .library(name: "Calendar", targets: ["Calendar"]),
        .library(name: "Authentication", targets: ["Authentication"]),
        .library(name: "UI", targets: ["UI"]),
        .library(name: "Utilities", targets: ["Utilities"]),
        .library(name: "Features", targets: ["Features"]),
        .library(name: "App", targets: ["App"])
    ],
    dependencies: [
        // External dependencies go here
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "10.15.0"),
        .package(url: "https://github.com/google/GoogleSignIn-iOS.git", from: "7.0.0"),
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.10.0")
    ],
    targets: [
        // Core Module
        .target(
            name: "Core",
            dependencies: [],
            path: "Frameworks/Core/Sources"),
        
        // Utilities Module
        .target(
            name: "Utilities",
            dependencies: [
                "Core",
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk")
            ],
            path: "Utilities"),
        
        // Services Module
        .target(
            name: "Services",
            dependencies: [
                "Core",
                "Utilities",
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestoreSwift", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseStorage", package: "firebase-ios-sdk"),
                .product(name: "FirebaseAnalytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseRemoteConfig", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCrashlytics", package: "firebase-ios-sdk"),
                .product(name: "FirebaseMessaging", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFunctions", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "Frameworks/Services/Sources"),
        
        // Calendar Module
        .target(
            name: "Calendar",
            dependencies: [
                "Core",
                "Services",
                "Utilities"
            ],
            path: "Frameworks/Calendar/Sources"),
        
        // Authentication Module
        .target(
            name: "Authentication",
            dependencies: [
                "Core",
                "Services",
                "Utilities",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "GoogleSignIn", package: "GoogleSignIn-iOS")
            ],
            path: "Frameworks/Authentication/Sources"),
        
        // UI Module
        .target(
            name: "UI",
            dependencies: [
                "Core",
                "Utilities",
                .product(name: "Kingfisher", package: "Kingfisher")
            ],
            path: "Frameworks/UI/Sources"),
        
        // Features Module
        .target(
            name: "Features",
            dependencies: [
                "Core",
                "Services",
                "UI",
                "Calendar",
                "Authentication",
                "Utilities"
            ],
            path: "Features"),
        
        // Main App
        .target(
            name: "App",
            dependencies: [
                "Core",
                "Services",
                "UI",
                "Calendar",
                "Authentication",
                "Features",
                "Utilities"
            ],
            path: "App")
    ]
) 