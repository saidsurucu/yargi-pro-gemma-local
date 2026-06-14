#!/usr/bin/env bash
# macOS: izole venv + rumps, menu-cubugu panelini (yargi_tray.py) baslatan /Applications app uret.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/Applications/Gemma Yargi Pro.app"
VENV="$ROOT/.venv"

if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

# python3 (brew) + izole venv + rumps.
# venv sart: modern brew python "externally-managed" (PEP 668), pip --user engellenir.
command -v python3 >/dev/null 2>&1 || brew install python
[ -d "$VENV" ] || python3 -m venv "$VENV"
"$VENV/bin/python3" -m pip install --quiet --upgrade pip
"$VENV/bin/python3" -m pip install --quiet rumps
PY="$VENV/bin/python3"

TMP="$(mktemp).applescript"
cat > "$TMP" <<'APPLESCRIPT'
do shell script "__PY__ __ROOT__/scripts/yargi_tray.py > /tmp/yargi-tray.log 2>&1 &"
APPLESCRIPT
sed -i '' "s|__PY__|$PY|; s|__ROOT__|$ROOT|" "$TMP"

rm -rf "/Applications/Yargi Pro.app"  # eski ad
rm -rf "$APP"
osacompile -o "$APP" "$TMP"
rm -f "$TMP"
codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "Launcher (menu-cubugu paneli) -> $APP"
