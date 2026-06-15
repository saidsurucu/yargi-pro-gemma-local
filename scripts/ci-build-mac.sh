#!/usr/bin/env bash
# CI (GitHub Actions macos): TheTom fork'unu Metal ile derler, ad-hoc imzalar, zip yapar.
# Kullanim: ci-build-mac.sh <arch>  (arm64 | x64)
set -euo pipefail
ARCH="${1:-arm64}"
REPO="https://github.com/TheTom/llama-cpp-turboquant"
SRC="$PWD/tq-src"; STAGE="$PWD/tq-mac"

git clone --depth 1 "$REPO" "$SRC"
cmake -S "$SRC" -B "$SRC/build" -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DLLAMA_CURL=OFF -DCMAKE_DISABLE_FIND_PACKAGE_OpenSSL=ON
cmake --build "$SRC/build" --config Release -j

mkdir -p "$STAGE"
cp "$SRC"/build/bin/llama-server "$STAGE"/ 2>/dev/null || cp "$SRC"/build/bin/* "$STAGE"/
find "$SRC/build" -name '*.dylib' -exec cp {} "$STAGE"/ \; 2>/dev/null || true
# rpath: binary CI build yolunu @rpath olarak gomer; @loader_path ekle ki tasinabilir olsun
# (kullanici makinesinde yanindaki dylib'leri kendi klasoründe bulsun).
for f in "$STAGE"/llama-server "$STAGE"/*.dylib; do
  [ -f "$f" ] && install_name_tool -add_rpath @loader_path "$f" 2>/dev/null || true
done
# ad-hoc imza (install_name_tool imzayi bozar -> EN SON; Apple Silicon imzasiz binary calistirmaz)
find "$STAGE" -type f \( -perm -u+x -o -name '*.dylib' \) -exec codesign --force --sign - {} \; 2>/dev/null || true
test -f "$STAGE/llama-server" || { echo "llama-server stage'de yok"; exit 1; }
( cd "$STAGE" && zip -r "$PWD/../llama-turboquant-mac-$ARCH.zip" . )
echo "ZIP -> llama-turboquant-mac-$ARCH.zip"
