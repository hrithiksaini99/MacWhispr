#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
swift "$ROOT/script/render_brand.swift" "$ROOT"
ICONSET="$ROOT/.build/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  double=$((size * 2))
  sips -z "$double" "$double" "$ROOT/Assets/AppIcon.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$ROOT/Assets/AppIcon.icns"
sips -z 64 64 "$ROOT/Assets/AppIcon.png" --out "$ROOT/site/assets/brand/favicon.png" >/dev/null
sips -z 180 180 "$ROOT/Assets/AppIcon.png" --out "$ROOT/site/assets/brand/apple-touch-icon.png" >/dev/null
