// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OsqueryNLI",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "OsqueryNLI", targets: ["OsqueryNLI"]),
        .executable(name: "OsqueryMCPServer", targets: ["OsqueryMCPServer"]),
        .library(name: "OsqueryNLICore", targets: ["OsqueryNLICore"]),
    ],
    dependencies: [
        // Google Gemini SDK
        .package(url: "https://github.com/google/generative-ai-swift", from: "0.4.0"),
        // MCP (Model Context Protocol) SDK
        .package(url: "https://github.com/modelcontextprotocol/swift-sdk.git", from: "0.7.1"),
        // Swift Testing (Command Line Tools SDK doesn't include it)
        .package(url: "https://github.com/swiftlang/swift-testing.git", from: "0.12.0"),
    ],
    targets: [
        // Shared core library (osquery service, utilities)
        .target(
            name: "OsqueryNLICore",
            dependencies: [],
            path: "Sources/OsqueryNLICore"
        ),
        // Main menu bar app
        .executableTarget(
            name: "OsqueryNLI",
            dependencies: [
                "OsqueryNLICore",
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
            ],
            path: "Sources/OsqueryNLI",
            resources: [
                .copy("../../Resources/ai_tables.ext")
            ]
        ),
        // MCP Server executable
        .executableTarget(
            name: "OsqueryMCPServer",
            dependencies: [
                "OsqueryNLICore",
                .product(name: "MCP", package: "swift-sdk"),
                .product(name: "GoogleGenerativeAI", package: "generative-ai-swift"),
            ],
            path: "Sources/OsqueryMCPServer"
        ),
        .testTarget(
            name: "OsqueryNLICoreTests",
            dependencies: [
                "OsqueryNLICore",
                .product(name: "Testing", package: "swift-testing"),
            ],
            path: "Tests/OsqueryNLICoreTests"
        ),
    ]
)
