#!/usr/bin/env bash
# Wraps the executable from swift build, plus the icon, into an .app bundle.
# The bundle holds a fixed handful of files, so overwriting in place is enough — no
# need to delete the previous one.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/build/DisplaySnooze.app"
ICONSET="$ROOT/build/AppIcon.iconset"
ICNS="$ROOT/build/AppIcon.icns"
# Set ICON_VARIANT=light to try the alternative color scheme.
ICON_VARIANT="${ICON_VARIANT:-dark}"

swift build -c release --package-path "$ROOT"
BIN="$(swift build -c release --package-path "$ROOT" --show-bin-path)/DisplaySnooze"

# Redraw the icon only when its source changed; rendering costs a few seconds.
if [[ ! -f "$ICNS" || "$ROOT/scripts/make-icon.swift" -nt "$ICNS" ]]; then
	echo "rendering icon ($ICON_VARIANT)..."
	swift "$ROOT/scripts/make-icon.swift" "$ICON_VARIANT" "$ICONSET"
	iconutil --convert icns "$ICONSET" --output "$ICNS"
fi

mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp -f "$BIN" "$APP/Contents/MacOS/DisplaySnooze"
cp -f "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp -f "$ICNS" "$APP/Contents/Resources/AppIcon.icns"

# Ad-hoc signature. Enough for running the app on this machine.
codesign --force --sign - "$APP"

echo "built: $APP"
