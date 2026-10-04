#!/usr/bin/env bash
set -euo pipefail
MODEL="$HOME/Library/Application Support/MacWhispr/models/ggml-base.en.bin"
WHISPER="${MACWHISPR_WHISPER:-/opt/homebrew/bin/whisper-cli}"
[[ -x "$WHISPER" ]] || { echo "whisper-cli unavailable" >&2; exit 1; }
[[ -s "$MODEL" ]] || { echo "Base model unavailable" >&2; exit 1; }
TEMP="$(mktemp -d)"
trap 'rm -rf "$TEMP"' EXIT
say -o "$TEMP/sample.aiff" 'MacWhispr is working correctly. This is a local transcription test.'
afconvert -f WAVE -d LEI16@16000 -c 1 "$TEMP/sample.aiff" "$TEMP/sample.wav"
OUTPUT="$($WHISPER -m "$MODEL" -f "$TEMP/sample.wav" -nt -np 2>"$TEMP/whisper.log")"
echo "$OUTPUT"
echo "$OUTPUT" | tr '[:upper:]' '[:lower:]' | grep -q 'local transcription test'
