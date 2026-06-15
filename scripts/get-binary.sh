#!/usr/bin/env bash
# Release'ten Mac Metal prebuilt'i indir, ac, KARANTINA temizle + AD-HOC imzala.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REL="binaries-v1"
case "$(uname -m)" in arm64) A=arm64;; *) A=x64;; esac
DEST="$ROOT/vendor/llama-cpp-turboquant/build/bin"
EXE="$DEST/llama-server"

if [ -f "$EXE" ]; then echo "[VAR] llama-server"; exit 0; fi
mkdir -p "$DEST"
ZIP="${TMPDIR:-/tmp}/llama-turboquant-mac-$A.zip"  # sabit yol: yarim kalirsa -C - ile devam eder
URL="https://github.com/saidsurucu/yargi-pro-gemma-local/releases/download/$REL/llama-turboquant-mac-$A.zip"
echo "Prebuilt indiriliyor ($A)..."
# -C - : kaldigi yerden devam; --retry-all-errors : connection reset gibi hatalarda da tekrar dene.
# curl 33 = HTTP range error (416): dosya zaten tam inmis, hata sayma.
curl -L -C - --retry 8 --retry-delay 5 --retry-all-errors -o "$ZIP" "$URL" \
  || { c=$?; [ "$c" -eq 33 ] || { echo "binary indirilemedi (curl $c)"; exit 1; }; }
unzip -o "$ZIP" -d "$DEST"
[ -f "$EXE" ] || { echo "binary acilmadi: $EXE"; exit 1; }
# KRITIK 1: karantina temizle
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
# KRITIK 2: rpath. Binary CI build yolunu (@rpath) gomuyor; @loader_path ekle ki
# yanindaki dylib'leri (libllama-common.dylib vb.) kendi klasoründe bulsun.
for f in "$DEST"/llama-server "$DEST"/*.dylib; do
  [ -f "$f" ] && install_name_tool -add_rpath @loader_path "$f" 2>/dev/null || true
done
# KRITIK 3: ad-hoc imza (install_name_tool imzayi bozar -> EN SON imzala; arm64 sart)
find "$DEST" -type f \( -name 'llama-*' -o -name '*.dylib' \) -exec codesign --force --sign - {} \; 2>/dev/null || true
chmod +x "$EXE"
echo "Binary hazir -> $EXE"
