#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="1.9.4"
HASH="57e280cee375ab02425b806ad5146b99f6eb9357e3c2b31357c8a6af2e2e44ae"
VENDOR="$ROOT/.build/vendor"
ARCH="${MACWHISPR_ARCH:-arm64}"
SOURCE="$VENDOR/whisper.cpp-$VERSION"
BUILD="$VENDOR/whisper-$ARCH"
command -v cmake >/dev/null || { echo 'CMake is required: brew install cmake' >&2; exit 1; }
mkdir -p "$VENDOR"
if [[ ! -f "$VENDOR/whisper-v$VERSION.tar.gz" ]]; then
  curl -fL --retry 2 "https://github.com/ggml-org/whisper.cpp/archive/refs/tags/v$VERSION.tar.gz" -o "$VENDOR/whisper-v$VERSION.tar.gz"
fi
printf '%s  %s\n' "$HASH" "$VENDOR/whisper-v$VERSION.tar.gz" | shasum -a 256 -c -
[[ -d "$SOURCE" ]] || tar -xzf "$VENDOR/whisper-v$VERSION.tar.gz" -C "$VENDOR"
cmake -S "$SOURCE" -B "$BUILD" -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_OSX_DEPLOYMENT_TARGET=13.0 -DCMAKE_OSX_ARCHITECTURES="$ARCH" \
  -DBUILD_SHARED_LIBS=OFF -DGGML_BACKEND_DL=OFF -DGGML_NATIVE=OFF \
  -DGGML_OPENMP=OFF -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON \
  -DGGML_BLAS=ON -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_EXAMPLES=ON
cmake --build "$BUILD" --config Release --target whisper-cli -j "${MACWHISPR_BUILD_JOBS:-6}"
printf '\nBundled engine: %s\n' "$BUILD/bin/whisper-cli"
