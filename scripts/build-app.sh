#!/usr/bin/env bash
# swift build で作った実行ファイルとアイコンを .app バンドルに詰め直す。Xcode 無しで動かすための最小手順。
# 中身は決まった数個のファイルだけなので、古いバンドルは消さず上書きで足りる。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/DisplaySnooze.app"
ICONSET="$ROOT/build/AppIcon.iconset"
ICNS="$ROOT/build/AppIcon.icns"
# 配色を試したいときは ICON_VARIANT=light で切り替えられる。
ICON_VARIANT="${ICON_VARIANT:-dark}"

swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/DisplaySnooze"

# アイコンはデザインを変えたときだけ描き直す。毎回だと数秒かかるため。
if [[ ! -f "$ICNS" || "$ROOT/scripts/make-icon.swift" -nt "$ICNS" ]]; then
	echo "rendering icon ($ICON_VARIANT)..."
	swift "$ROOT/scripts/make-icon.swift" "$ICON_VARIANT" "$ICONSET"
	iconutil --convert icns "$ICONSET" --output "$ICNS"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f "$BIN" "$APP/Contents/MacOS/DisplaySnooze"
cp -f "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp -f "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

# ad-hoc 署名。手元で動かすだけなのでこれで足りる。
codesign --force --sign - "$APP"

echo "built: $APP"
