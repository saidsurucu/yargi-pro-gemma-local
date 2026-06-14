#!/usr/bin/env bash
# macOS: python3+rumps sagla, menu-cubugu panelini (yargi_tray.py) baslatan /Applications app uret.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/Applications/Yargi Pro.app"

if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

# python3 + rumps
command -v python3 >/dev/null 2>&1 || brew install python
python3 -c "import rumps" >/dev/null 2>&1 || python3 -m pip install --user rumps

PY="$(command -v python3)"
TMP="$(mktemp).applescript"
cat > "$TMP" <<'APPLESCRIPT'
do shell script "__PY__ __ROOT__/scripts/yargi_tray.py > /tmp/yargi-tray.log 2>&1 &"
APPLESCRIPT
sed -i '' "s|__PY__|$PY|; s|__ROOT__|$ROOT|" "$TMP"

rm -rf "$APP"
osacompile -o "$APP" "$TMP"
rm -f "$TMP"
codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "Launcher (menu-cubugu paneli) -> $APP"
