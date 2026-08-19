#!/usr/bin/env bash
# swift build で作った実行ファイルを .app バンドルに詰め直す。Xcode が無くても動くようにするための最小手順。
# 中身は実行ファイルと Info.plist の2つだけなので、古いバンドルは消さず上書きで足りる。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/DisplaySnooze.app"

swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/DisplaySnooze"

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f "$BIN" "$APP/Contents/MacOS/DisplaySnooze"
cp -f "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"

# ad-hoc 署名。手元で動かすだけなのでこれで足りる。
codesign --force --sign - "$APP"

echo "built: $APP"
