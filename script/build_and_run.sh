#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
APP="MacWhispr"
BUNDLE="$ROOT/dist/$APP.app"
pkill -x "$APP" >/dev/null 2>&1 || true
swift build
BIN="$(swift build --show-bin-path)/$APP"
mkdir -p "$BUNDLE/Contents/MacOS"
cp "$BIN" "$BUNDLE/Contents/MacOS/$APP"
cp "$ROOT/Info.plist" "$BUNDLE/Contents/Info.plist"
chmod +x "$BUNDLE/Contents/MacOS/$APP"
codesign --force --sign - "$BUNDLE" >/dev/null
case "$MODE" in
  run) open -n "$BUNDLE" ;;
  --verify) open -n "$BUNDLE"; sleep 2; pgrep -x "$APP" >/dev/null ;;
  --debug) lldb -- "$BUNDLE/Contents/MacOS/$APP" ;;
  --logs) open -n "$BUNDLE"; /usr/bin/log stream --info --style compact --predicate "process == \"$APP\"" ;;
  --telemetry) open -n "$BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "dev.macwhispr.app"' ;;
  *) echo "usage: $0 [run|--verify|--debug|--logs|--telemetry]" >&2; exit 2 ;;
esac
