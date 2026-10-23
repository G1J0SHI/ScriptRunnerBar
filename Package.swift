// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ScriptRunnerBar",
    platforms: [.macOS(.v15)],
    products: [
        .executable(
            name: "ScriptRunnerBar",
            targets: ["ScriptRunnerBar"]
        ),
        .library(
            name: "ScriptRunnerBarCore",
            targets: ["ScriptRunnerBarCore"]
        ),
    ],
    targets: [
        .target(name: "ScriptRunnerBarCore"),
        .executableTarget(
            name: "ScriptRunnerBar",
            dependencies: ["ScriptRunnerBarCore"]
        ),
        .testTarget(
            name: "ScriptRunnerBarCoreTests",
            dependencies: ["ScriptRunnerBarCore"]
        ),
    ]
)
