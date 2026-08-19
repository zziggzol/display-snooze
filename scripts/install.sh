#!/usr/bin/env bash
# Puts the built app in /Applications and swaps out any copy already running.
# Login item registration records the bundle path, so the copy you actually use day to
# day should be the one you register.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="/Applications/DisplaySnooze.app"

"$ROOT/scripts/build-app.sh"

# Quitting restores any detached display, so always stop the old copy before replacing it.
pkill -x DisplaySnooze 2>/dev/null || true
sleep 1

ditto "$ROOT/build/DisplaySnooze.app" "$DEST"
codesign --force --sign - "$DEST"
open "$DEST"

echo "installed: $DEST"
