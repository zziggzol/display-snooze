#!/usr/bin/env bash
# ビルドしたアプリを /Applications へ入れ、動いているものを新しいものに差し替える。
# 自動起動には .app の置き場所が記録されるため、常用するならここから起動したものを登録する。
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="/Applications/DisplaySnooze.app"

"$ROOT/scripts/build-app.sh"

# 終了時に切り離した画面を戻す処理が走るので、入れ替え前に必ず落としておく。
pkill -x DisplaySnooze 2>/dev/null || true
sleep 1

ditto "$ROOT/build/DisplaySnooze.app" "$DEST"
codesign --force --sign - "$DEST"
open "$DEST"

echo "installed: $DEST"
