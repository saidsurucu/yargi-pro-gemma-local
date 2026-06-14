#!/usr/bin/env bash
# macOS kurulum on-kontrolleri.
set -uo pipefail
OK=1
ARCH=$(uname -m)
if [ "$ARCH" != "arm64" ]; then
  echo "[UYARI] Apple Silicon (arm64) onerilir; mevcut: $ARCH. Intel'de yavas/best-effort."
fi
RAM_GB=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
echo "[BILGI] Unified RAM: ${RAM_GB} GB (24+ -> 26B, alti -> 12B)"
FREE_GB=$(df -g "$HOME" | awk 'NR==2 {print $4}')
if [ "${FREE_GB:-0}" -lt 20 ]; then
  echo "[HATA] Disk yetersiz (${FREE_GB} GB bos, >=20 GB gerekli)."; OK=0
else
  echo "[OK] Disk: ${FREE_GB} GB bos"
fi
[ "$OK" -eq 1 ] || { echo "On-kontrol basarisiz."; exit 1; }
echo "On-kontroller tamam."
