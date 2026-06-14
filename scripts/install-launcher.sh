#!/usr/bin/env bash
# /Applications/Yargi Pro.app uretir. osacompile ile AppleScript app -> LaunchServices kabul eder
# (elle yapilmis .app bundle -1712 hatasi veriyordu). Cift tik: sunucu kapaliysa baslat + opencode ac.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/Applications/Yargi Pro.app"

TMP="$(mktemp).applescript"
# Quoted heredoc: icerik birebir; __ROOT__ placeholder'i sonra degistirilir.
cat > "$TMP" <<'APPLESCRIPT'
do shell script "ROOT='__ROOT__'; /usr/bin/curl -s http://127.0.0.1:8080/v1/models >/dev/null 2>&1 || ( /usr/bin/nohup /bin/bash \"$ROOT/scripts/start-server.sh\" > /tmp/yargi-server.log 2>&1 & ); /usr/bin/open -a OpenCode"
APPLESCRIPT
sed -i '' "s|__ROOT__|$ROOT|" "$TMP"

rm -rf "$APP"
osacompile -o "$APP" "$TMP"
rm -f "$TMP"
# ad-hoc imza (gelecekteki Gatekeeper sikiligi icin garanti)
codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "Launcher -> $APP"
