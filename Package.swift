// swift-tools-version: 6.1

import CompilerPluginSupport
import Foundation
import PackageDescription

let isRunningInXcode = ProcessInfo.processInfo.environment["__CFBundleIdentifier"] == "com.apple.dt.Xcode"

let package = Package(
    name: "StoredPropertyInit",
    platforms: [.macOS(.v12), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "StoredPropertyInit",
            targets: ["StoredPropertyInit"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.1"),
    ] + (isRunningInXcode ? [
        .package(url: "https://github.com/SimplyDanny/SwiftLintPlugins.git", exact: "0.63.2"),
    ] : []),
    targets: [
        .macro(
            name: "StoredPropertyInitMacros",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax")
            ],
            plugins: isRunningInXcode ? [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ] : []
        ),
        .target(
            name: "StoredPropertyInit",
            dependencies: ["StoredPropertyInitMacros"],
            plugins: isRunningInXcode ? [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ] : []
        ),
        .testTarget(
            name: "StoredPropertyInitTests",
            dependencies: [
                "StoredPropertyInitMacros",
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            plugins: isRunningInXcode ? [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLintPlugins"),
            ] : []
        ),
    ],
    swiftLanguageModes: [.v6]
)
