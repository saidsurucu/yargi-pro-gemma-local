#!/usr/bin/env bash
# Idiot-proof kurulum (macOS): on-kontrol -> brew(git/node) -> opencode -> prebuilt -> model ->
# config -> launcher (.app). DERLEME YOK.
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG="$ROOT/install.log"
if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

step() {
  echo "" | tee -a "$LOG"; echo "--- $1 ---" | tee -a "$LOG"
  shift
  if ! "$@" 2>&1 | tee -a "$LOG"; then
    echo "KURULUM DURDU. Su dosyayi gonderin: $LOG"; read -r -p "Kapatmak icin Enter" _; exit 1
  fi
}

step "On-kontroller" bash "$ROOT/scripts/preflight.sh"
for pkg in git node; do command -v "$pkg" >/dev/null 2>&1 || brew install "$pkg"; done
step "opencode (CLI + desktop + config)" bash "$ROOT/scripts/install-opencode.sh"
step "Prebuilt binary indirme" bash "$ROOT/scripts/get-binary.sh"
step "Model indirme" bash "$ROOT/scripts/download-model.sh"
step "Launcher (.app)" bash "$ROOT/scripts/install-launcher.sh"

echo "" ; echo "=== HER SEY HAZIR ==="
echo "Launchpad'de 'Yargi Pro' uygulamasini ac."
