#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
ARCH="${MACWHISPR_ARCH:-arm64}"
ENGINE="${WHISPER_BINARY:-$ROOT/.build/vendor/whisper-$ARCH/bin/whisper-cli}"
IDENTITY="${MACWHISPR_SIGNING_IDENTITY:--}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Info.plist)"
OUT="$ROOT/dist/release"
APP="$OUT/MacWhispr.app"
NAME="MacWhispr-$VERSION-$ARCH"
[[ "$ARCH" == arm64 ]] || { echo 'This release workflow currently validates Apple Silicon only.' >&2; exit 1; }
[[ -x "$ENGINE" ]] || "$ROOT/script/build_speech_engine.sh"
[[ -f Assets/AppIcon.icns ]] || { echo 'Missing Assets/AppIcon.icns. Run script/build_brand.sh.' >&2; exit 1; }
# Reject helpers that need Homebrew or a newer OS, rather than silently shipping them.
python3 - "$ENGINE" <<'PY'
import re, subprocess, sys
engine=sys.argv[1]
deps=subprocess.check_output(['otool','-L',engine],text=True).splitlines()[1:]
for line in deps:
    path=line.strip().split(' (')[0]
    if not path.startswith(('/usr/lib/','/System/Library/')):
        raise SystemExit('Non-system engine dependency: '+path+'. Use build_speech_engine.sh.')
load=subprocess.check_output(['otool','-l',engine],text=True)
versions=re.findall(r'\bminos\s+(\d+(?:\.\d+)*)',load)
if not versions or any(tuple(map(int,v.split('.'))) > (13,0,0) for v in versions):
    raise SystemExit('Engine minimum macOS must be 13.0 or earlier.')
PY
swift build -c release
BIN="$(swift build -c release --show-bin-path)/MacWhispr"
# Only this generated app bundle is recreated; unrelated dist content is preserved.
rm -rf "$APP"
mkdir -p "$APP/Contents/"{MacOS,Resources,Helpers}
cp "$BIN" "$APP/Contents/MacOS/MacWhispr"
cp Info.plist "$APP/Contents/Info.plist"
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp "$ENGINE" "$APP/Contents/Helpers/whisper-cli"
cp -R docs/licenses "$APP/Contents/Resources/Licenses"
cp docs/THIRD_PARTY_NOTICES.md "$APP/Contents/Resources/"
chmod +x "$APP/Contents/MacOS/MacWhispr" "$APP/Contents/Helpers/whisper-cli"
SIGN=(--force --sign "$IDENTITY" --options runtime)
if [[ "$IDENTITY" != '-' ]]; then SIGN+=(--timestamp); fi
codesign "${SIGN[@]}" "$APP/Contents/Helpers/whisper-cli"
codesign "${SIGN[@]}" --entitlements docs/Release.entitlements "$APP"
codesign --verify --deep --strict "$APP"
plutil -lint "$APP/Contents/Info.plist"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME.zip"
if [[ -n "${MACWHISPR_NOTARY_PROFILE:-}" ]]; then
  [[ "$IDENTITY" != '-' ]] || { echo 'Notarization requires a Developer ID identity.' >&2; exit 1; }
  xcrun notarytool submit "$OUT/$NAME.zip" --keychain-profile "$MACWHISPR_NOTARY_PROFILE" --wait
  xcrun stapler staple "$APP"
  xcrun stapler validate "$APP"
  spctl --assess --type execute --verbose "$APP"
  ditto -c -k --sequesterRsrc --keepParent "$APP" "$OUT/$NAME.zip"
fi
hdiutil create -volname "MacWhispr" -srcfolder "$APP" -ov -format UDZO "$OUT/$NAME.dmg"
(cd "$OUT" && shasum -a 256 "$NAME.zip" > "$NAME.sha256")
(cd "$OUT" && shasum -a 256 "$NAME.dmg" > "${NAME}_dmg.sha256")
if [[ "$IDENTITY" == '-' ]]; then
  printf '\nOPEN SOURCE BUILD: ad hoc signed, not notarized. Users may need to right-click to open to bypass Gatekeeper.\n'
else
  printf '\nDeveloper ID package created. Notarization: %s\n' "${MACWHISPR_NOTARY_PROFILE:-not submitted}"
fi
printf 'Archive: %s\n' "$OUT/$NAME.zip"
printf 'Disk Image: %s\n' "$OUT/$NAME.dmg"
