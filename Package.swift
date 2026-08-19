// swift-tools-version: 6.0
// Package definition for DisplaySnooze: the minimum needed to produce an executable
// with swift build alone, no Xcode involved.
// scripts/build-app.sh then wraps that executable into an .app bundle.

import PackageDescription

let package = Package(
    name: "DisplaySnooze",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "DisplaySnooze",
            path: "Sources/DisplaySnooze"
        )
    ]
)
