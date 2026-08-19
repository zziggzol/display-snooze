// swift-tools-version: 6.0
// DisplaySnooze のパッケージ定義。Xcode を使わず swift build だけで実行ファイルを作る最小構成。
// 出来た実行ファイルは scripts/build-app.sh が .app バンドルへ詰め直す。

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
