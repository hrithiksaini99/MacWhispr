#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mkdir -p "$ROOT/.build/checks"
swiftc -parse-as-library \
  "$ROOT/Sources/MacWhispr/ModelManager.swift" \
  "$ROOT/Sources/MacWhispr/Models/HotKeyShortcut.swift" \
  "$ROOT/Sources/MacWhispr/Transcriber.swift" \
  "$ROOT/script/RuntimeChecks.swift" -framework AppKit -framework Carbon -o "$ROOT/.build/checks/runtime-checks"
"$ROOT/.build/checks/runtime-checks"
