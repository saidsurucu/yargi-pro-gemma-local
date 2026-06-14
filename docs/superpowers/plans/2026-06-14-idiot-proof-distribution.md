# Idiot-Proof Dağıtım Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Son kullanıcının tek satırla, derleme yapmadan, hatadan kurtulabilir şekilde kurabileceği bir dağıtım: binary'ler GitHub Actions'ta bir kez derlenir, release'e konur, installer indirir; kurulum sonrası tek-tık launcher.

**Architecture:** İki katman — (1) CI: `.github/workflows/build.yml` üç job (Win-CUDA, Mac-arm64, Mac-x64) `scripts/ci-build-*` çağırıp prebuilt zip'leri `binaries-v1` release'ine yükler. (2) Installer: prebuilt'i indirir (derleme yok), ön-kontrol + log + tek-tık launcher kurar.

**Tech Stack:** GitHub Actions (Jimver/cuda-toolkit, CUDA 12.8), CMake/MSVC (yalnız CI), Metal (Mac CI), PowerShell 5.1, bash, curl, opencode, GGUF.

**Bu proje TDD'ye uymaz:** Altyapı scriptleri. "Test" = PowerShell AST parse / `bash -n` syntax check / YAML geçerlilik + (CI için) workflow'u çalıştırıp release asset'lerini doğrulama. Ağır doğrulamalar (CI build, temiz-makine kurulum) gerçek ortamda yapılır; planda beklenen çıktı belgelenir.

**Sabitler:**
- Repo: `C:\Users\saids\OneDrive\Belgeler\yargi-pro-gemma-local` | GitHub: `saidsurucu/yargi-pro-gemma-local`
- Fork: `https://github.com/TheTom/llama-cpp-turboquant`
- Binary release tag: **`binaries-v1`**
- CUDA: **12.8**, arch: `75-real;86-real;89-real;120-real;120-virtual` (RTX 20xx/30xx/40xx/50xx)
- Min NVIDIA sürücü: **570.65** | Mac DMG/binary: ad-hoc imza şart
- Asset adları: `llama-turboquant-win-cuda.zip`, `-mac-arm64.zip`, `-mac-x64.zip`

---

## File Structure

| Dosya | Sorumluluk | Durum |
|---|---|---|
| `scripts/ci-build-win.ps1` | CI: fork klonla, CUDA 12.8 multi-arch derle, DLL'leri topla, zip | YENİ |
| `scripts/ci-build-mac.sh` | CI: fork klonla, Metal derle, ad-hoc imzala, zip | YENİ |
| `.github/workflows/build.yml` | 3 job + release; ci-build-* çağırır | YENİ |
| `scripts/preflight.ps1` | Win ön-kontrol: GPU, sürücü ≥570.65, disk | YENİ |
| `scripts/preflight.sh` | Mac ön-kontrol: arm64, RAM, disk | YENİ |
| `scripts/get-binary.ps1` | Release'ten win zip indir+aç | YENİ |
| `scripts/get-binary.sh` | Release'ten mac zip indir+aç + xattr + codesign | YENİ |
| `scripts/launch.ps1` | Sunucu kapalıysa başlat + opencode aç (Win) | YENİ |
| `scripts/install-launcher.ps1` | Masaüstü+Start Menu `.lnk` (gizli) | YENİ |
| `scripts/install-launcher.sh` | `/Applications/Yargı Pro.app` üret | YENİ |
| `scripts/setup-all.ps1` | build yerine get-binary; preflight+launcher; CUDA/MSVC kurulumu kaldır | DEĞİŞİR |
| `scripts/setup-all.sh` | aynı (Mac) | DEĞİŞİR |
| `install.ps1` / `install.sh` | try/catch + log sarmalı | DEĞİŞİR |
| `README.md` | gereksinimler (sürücü ≥570.65), akış | DEĞİŞİR |
| `scripts/build-turboquant.ps1`, `build-llamacpp.sh` | repo'da kalır (legacy/dev); installer çağırmaz | KORUNUR |

---

## FAZ 1 — CI Build & İlk Release (en büyük riski önce çözer)

### Task 1: ci-build-win.ps1 — CUDA multi-arch derleme + DLL paketleme

**Files:** Create: `scripts/ci-build-win.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/ci-build-win.ps1` tam içeriği:

```powershell
# CI (GitHub Actions windows-latest): TheTom fork'unu CUDA 12.8 multi-arch derler,
# llama-server.exe + ggml DLL'leri + CUDA redist DLL'leri toplayip zip yapar.
# Onkosul: CUDA Toolkit kurulu (Jimver action), CUDA_PATH set.
$ErrorActionPreference = 'Stop'
$repo  = 'https://github.com/TheTom/llama-cpp-turboquant'
$src   = Join-Path $PWD 'tq-src'
$stage = Join-Path $PWD 'tq-win-cuda'

Write-Host "CUDA_PATH=$env:CUDA_PATH"
git clone --depth 1 $repo $src
if ($LASTEXITCODE -ne 0) { throw "clone basarisiz" }

cmake -S $src -B "$src/build" -DGGML_CUDA=ON `
  "-DCMAKE_CUDA_ARCHITECTURES=75-real;86-real;89-real;120-real;120-virtual" `
  -DLLAMA_CURL=OFF
if ($LASTEXITCODE -ne 0) { throw "configure basarisiz" }
cmake --build "$src/build" --config Release -j
if ($LASTEXITCODE -ne 0) { throw "build basarisiz" }

New-Item -ItemType Directory -Force -Path $stage | Out-Null
# llama-server.exe + build'in urettigi tum DLL'ler (ggml*, llama*)
$bin = "$src/build/bin/Release"
Get-ChildItem $bin -Recurse -Include 'llama-server.exe','*.dll' | Copy-Item -Destination $stage -Force
# CUDA redist DLL'leri (toolkit olmadan calismasi icin sart)
$cudaBin = Join-Path $env:CUDA_PATH 'bin'
foreach ($pat in 'cudart64_*.dll','cublas64_*.dll','cublasLt64_*.dll') {
  Get-ChildItem $cudaBin -Filter $pat -ErrorAction SilentlyContinue | Copy-Item -Destination $stage -Force
}
if (-not (Test-Path (Join-Path $stage 'llama-server.exe'))) { throw "llama-server.exe stage'de yok" }
Write-Host "Paketlenen dosyalar:"; Get-ChildItem $stage | ForEach-Object { Write-Host "  $($_.Name)" }
Compress-Archive -Path "$stage/*" -DestinationPath (Join-Path $PWD 'llama-turboquant-win-cuda.zip') -Force
Write-Host "ZIP -> llama-turboquant-win-cuda.zip"
```

- [ ] **Step 2: Parse doğrulaması**

Run: `$null=[System.Management.Automation.Language.Parser]::ParseFile("scripts\ci-build-win.ps1",[ref]$null,[ref]$null); if($?){"PARSE OK"}`
Expected: `PARSE OK`

- [ ] **Step 3: Commit**

```powershell
git add scripts/ci-build-win.ps1
git commit -m "feat(ci): ci-build-win.ps1 CUDA 12.8 multi-arch derleme + DLL paketleme"
```

---

### Task 2: ci-build-mac.sh — Metal derleme + ad-hoc imza

**Files:** Create: `scripts/ci-build-mac.sh`

- [ ] **Step 1: Scripti yaz**

`scripts/ci-build-mac.sh` tam içeriği:

```bash
#!/usr/bin/env bash
# CI (GitHub Actions macos): TheTom fork'unu Metal ile derler, ad-hoc imzalar, zip yapar.
# Kullanim: ci-build-mac.sh <arch>  (arm64 | x64)
set -euo pipefail
ARCH="${1:-arm64}"
REPO="https://github.com/TheTom/llama-cpp-turboquant"
SRC="$PWD/tq-src"; STAGE="$PWD/tq-mac"

git clone --depth 1 "$REPO" "$SRC"
cmake -S "$SRC" -B "$SRC/build" -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON -DLLAMA_CURL=OFF
cmake --build "$SRC/build" --config Release -j

mkdir -p "$STAGE"
cp "$SRC"/build/bin/llama-server "$STAGE"/ 2>/dev/null || cp "$SRC"/build/bin/* "$STAGE"/
find "$SRC/build" -name '*.dylib' -exec cp {} "$STAGE"/ \; 2>/dev/null || true
# ad-hoc imza (Apple Silicon imzasiz binary calistirmaz)
find "$STAGE" -type f \( -perm -u+x -o -name '*.dylib' \) -exec codesign --force --sign - {} \; 2>/dev/null || true
test -f "$STAGE/llama-server" || { echo "llama-server stage'de yok"; exit 1; }
( cd "$STAGE" && zip -r "$PWD/../llama-turboquant-mac-$ARCH.zip" . )
echo "ZIP -> llama-turboquant-mac-$ARCH.zip"
```

- [ ] **Step 2: Syntax doğrulaması**

Run: `bash -n scripts/ci-build-mac.sh && echo "OK"`
Expected: `OK`

- [ ] **Step 3: LF + commit**

```bash
tr -d '\r' < scripts/ci-build-mac.sh > t && mv t scripts/ci-build-mac.sh
git add scripts/ci-build-mac.sh
git commit -m "feat(ci): ci-build-mac.sh Metal derleme + ad-hoc imza"
```

---

### Task 3: build.yml — 3 job + release

**Files:** Create: `.github/workflows/build.yml`

- [ ] **Step 1: Workflow'u yaz**

`.github/workflows/build.yml` tam içeriği:

```yaml
name: build-binaries
on:
  workflow_dispatch:

permissions:
  contents: write

jobs:
  win-cuda:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install CUDA 12.8
        uses: Jimver/cuda-toolkit@v0.2.21
        with:
          cuda: '12.8.0'
          method: network
          sub-packages: '["nvcc","cudart","cublas","cublas_dev","visual_studio_integration"]'
      - name: Build
        shell: pwsh
        run: ./scripts/ci-build-win.ps1
      - uses: actions/upload-artifact@v4
        with:
          name: win-cuda
          path: llama-turboquant-win-cuda.zip

  mac-arm64:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/ci-build-mac.sh arm64
      - uses: actions/upload-artifact@v4
        with:
          name: mac-arm64
          path: llama-turboquant-mac-arm64.zip

  mac-x64:
    runs-on: macos-13
    steps:
      - uses: actions/checkout@v4
      - run: bash scripts/ci-build-mac.sh x64
      - uses: actions/upload-artifact@v4
        with:
          name: mac-x64
          path: llama-turboquant-mac-x64.zip

  release:
    needs: [win-cuda, mac-arm64, mac-x64]
    runs-on: ubuntu-latest
    steps:
      - uses: actions/download-artifact@v4
        with:
          path: dist
      - name: Publish release
        uses: softprops/action-gh-release@v2
        with:
          tag_name: binaries-v1
          name: Prebuilt binaries (binaries-v1)
          files: dist/**/*.zip
```

- [ ] **Step 2: YAML geçerlilik**

Run: `python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/build.yml',encoding='utf-8')); print('YAML OK')"`
Expected: `YAML OK`

- [ ] **Step 3: Commit + push**

```powershell
git add .github/workflows/build.yml
git commit -m "feat(ci): build.yml - 3 job (win-cuda/mac) -> binaries-v1 release"
git push origin main
```

---

### Task 4: Workflow'u çalıştır ve release'i doğrula (gerçek CI)

**Files:** (yok — doğrulama)

- [ ] **Step 1: Workflow'u tetikle**

Run: `gh workflow run build-binaries --repo saidsurucu/yargi-pro-gemma-local`
Expected: "Created workflow_dispatch event".

- [ ] **Step 2: Çalışmayı izle**

Run: `gh run watch --repo saidsurucu/yargi-pro-gemma-local`
Expected: 4 job da `completed success`. (Win-CUDA build ~20-40 dk.) Başarısızsa job loglarını
`gh run view --log-failed` ile incele; en olası: CUDA kurulum sub-package eksik veya cmake CUDA
bulamadı (→ `visual_studio_integration` sub-package'ın yüklendiğini doğrula).

- [ ] **Step 3: Release asset'lerini doğrula**

Run: `gh release view binaries-v1 --repo saidsurucu/yargi-pro-gemma-local --json assets --jq '.assets[].name'`
Expected: `llama-turboquant-win-cuda.zip`, `llama-turboquant-mac-arm64.zip`, `llama-turboquant-mac-x64.zip`.

- [ ] **Step 4: Win binary smoke (bu makinede)**

```powershell
$tmp = "$env:TEMP\tqtest"; Remove-Item $tmp -Recurse -Force -EA SilentlyContinue; New-Item -ItemType Directory $tmp | Out-Null
curl.exe -L -o "$tmp\b.zip" "https://github.com/saidsurucu/yargi-pro-gemma-local/releases/download/binaries-v1/llama-turboquant-win-cuda.zip"
Expand-Archive "$tmp\b.zip" "$tmp\b" -Force
& "$tmp\b\llama-server.exe" --version
```
Expected: sürüm satırı yazar (DLL'ler yanında olduğu için açılır). Açılmazsa eksik DLL var →
Task 1'deki redist DLL listesine ekle (örn. `cublasLt`).

---

## FAZ 2 — Ön-kontroller

### Task 5: preflight.ps1 — Windows ön-kontrol

**Files:** Create: `scripts/preflight.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/preflight.ps1` tam içeriği:

```powershell
# Windows kurulum on-kontrolleri. Basarisizsa exit 1 + anlasilir mesaj.
$ErrorActionPreference = 'Continue'
$ok = $true
$root = Split-Path -Parent $PSScriptRoot

# 1) NVIDIA GPU + surucu
$smi = Get-Command nvidia-smi -ErrorAction SilentlyContinue
if (-not $smi) {
    Write-Host "[HATA] NVIDIA ekran karti/surucusu bulunamadi. Bu uygulama NVIDIA GPU gerektirir." -ForegroundColor Red
    $ok = $false
} else {
    $drv = (& nvidia-smi --query-gpu=driver_version --format=csv,noheader | Select-Object -First 1).Trim()
    $drvNum = [version](($drv -split '\.')[0..1] -join '.')
    if ($drvNum -lt [version]'570.65') {
        Write-Host "[HATA] NVIDIA surucusu cok eski ($drv). En az 570.65 gerekli. Guncelle: https://www.nvidia.com/Download/index.aspx" -ForegroundColor Red
        $ok = $false
    } else { Write-Host "[OK] NVIDIA surucu $drv" -ForegroundColor Green }
}

# 2) Disk alani (>= 20 GB)
$drive = (Get-Item $root).PSDrive
$freeGB = [math]::Round((Get-PSDrive $drive.Name).Free/1GB,1)
if ($freeGB -lt 20) {
    Write-Host "[HATA] Disk alani yetersiz ($freeGB GB bos, >=20 GB gerekli)." -ForegroundColor Red
    $ok = $false
} else { Write-Host "[OK] Disk: $freeGB GB bos" -ForegroundColor Green }

if (-not $ok) { Write-Host "`nOn-kontrol basarisiz. Yukaridaki sorunlari cozun." -ForegroundColor Yellow; exit 1 }
Write-Host "On-kontroller tamam." -ForegroundColor Green
```

- [ ] **Step 2: Parse + çalıştır (bu makine geçmeli)**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\preflight.ps1`
Expected: `[OK] NVIDIA surucu 595.x`, `[OK] Disk`, `On-kontroller tamam.` (exit 0). Bu makinede sürücü 595 > 570.65.

- [ ] **Step 3: Commit**

```powershell
git add scripts/preflight.ps1
git commit -m "feat: preflight.ps1 (NVIDIA GPU/surucu>=570.65, disk)"
```

---

### Task 6: preflight.sh — macOS ön-kontrol

**Files:** Create: `scripts/preflight.sh`

- [ ] **Step 1: Scripti yaz**

`scripts/preflight.sh` tam içeriği:

```bash
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
```

- [ ] **Step 2: Syntax + LF**

Run: `bash -n scripts/preflight.sh && echo OK`
Expected: `OK`. Sonra `tr -d '\r' < scripts/preflight.sh > t && mv t scripts/preflight.sh`.

- [ ] **Step 3: Commit**

```bash
git add scripts/preflight.sh
git commit -m "feat: preflight.sh (arm64/RAM/disk on-kontrol)"
```

---

## FAZ 3 — Prebuilt indirme (derleme yerine)

### Task 7: get-binary.ps1 — Windows prebuilt indir+aç

**Files:** Create: `scripts/get-binary.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/get-binary.ps1` tam içeriği:

```powershell
# Release'ten Windows CUDA prebuilt binary'sini indirip vendor altina acar.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$rel  = 'binaries-v1'
$url  = "https://github.com/saidsurucu/yargi-pro-gemma-local/releases/download/$rel/llama-turboquant-win-cuda.zip"
$dest = Join-Path $root 'vendor\llama-cpp-turboquant\build\bin\Release'
$exe  = Join-Path $dest 'llama-server.exe'

if (Test-Path $exe) { Write-Host "[VAR] llama-server.exe" -ForegroundColor Green; return }
New-Item -ItemType Directory -Force -Path $dest | Out-Null
$zip = Join-Path $env:TEMP 'llama-turboquant-win-cuda.zip'
Write-Host "Prebuilt indiriliyor..." -ForegroundColor Cyan
curl.exe -L --retry 5 -o "$zip" "$url"
if ($LASTEXITCODE -ne 0) { throw "binary indirilemedi" }
Expand-Archive -Path $zip -DestinationPath $dest -Force
if (-not (Test-Path $exe)) { throw "binary acilmadi/eksik: $exe" }
Write-Host "Binary hazir -> $exe" -ForegroundColor Green
```

- [ ] **Step 2: Parse**

Run: `$null=[System.Management.Automation.Language.Parser]::ParseFile("scripts\get-binary.ps1",[ref]$null,[ref]$null); if($?){"PARSE OK"}`
Expected: `PARSE OK`. (Gerçek indirme Task 4 release'i sonrası çalışır; start-server.ps1'in
mevcut auto-find'ı `build\bin\Release\llama-server.exe`'yi bulur.)

- [ ] **Step 3: Commit**

```powershell
git add scripts/get-binary.ps1
git commit -m "feat: get-binary.ps1 (prebuilt win binary indir+ac)"
```

---

### Task 8: get-binary.sh — macOS prebuilt indir + xattr + ad-hoc imza

**Files:** Create: `scripts/get-binary.sh`

- [ ] **Step 1: Scripti yaz**

`scripts/get-binary.sh` tam içeriği:

```bash
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
ZIP="$(mktemp -d)/b.zip"
URL="https://github.com/saidsurucu/yargi-pro-gemma-local/releases/download/$REL/llama-turboquant-mac-$A.zip"
echo "Prebuilt indiriliyor ($A)..."
curl -L --retry 5 -o "$ZIP" "$URL"
unzip -o "$ZIP" -d "$DEST"
[ -f "$EXE" ] || { echo "binary acilmadi: $EXE"; exit 1; }
# KRITIK: karantina temizle + arm64 icin ad-hoc imza (yoksa calismaz)
xattr -dr com.apple.quarantine "$DEST" 2>/dev/null || true
find "$DEST" -type f \( -name 'llama-*' -o -name '*.dylib' \) -exec codesign --force --sign - {} \; 2>/dev/null || true
chmod +x "$EXE"
echo "Binary hazir -> $EXE"
```

- [ ] **Step 2: Syntax + LF**

Run: `bash -n scripts/get-binary.sh && echo OK`; sonra `tr -d '\r'`.
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/get-binary.sh
git commit -m "feat: get-binary.sh (mac prebuilt + xattr + ad-hoc codesign)"
```

---

## FAZ 4 — Tek-tık launcher

### Task 9: launch.ps1 — sunucu başlat + opencode aç (Win)

**Files:** Create: `scripts/launch.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/launch.ps1` tam içeriği:

```powershell
# Tek-tik launcher: sunucu kapaliysa baslat (gizli), hazir olunca opencode desktop ac.
$ErrorActionPreference = 'SilentlyContinue'
$root = Split-Path -Parent $PSScriptRoot

function Test-Server { try { Invoke-RestMethod http://127.0.0.1:8080/v1/models -TimeoutSec 3 | Out-Null; return $true } catch { return $false } }

if (-not (Test-Server)) {
    Start-Process powershell -WindowStyle Hidden -ArgumentList `
      "-NoProfile -ExecutionPolicy Bypass -File `"$root\scripts\start-server.ps1`""
    for ($i=0; $i -lt 120; $i++) { if (Test-Server) { break }; Start-Sleep -Seconds 2 }
}

$oc = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"
if (Test-Path $oc) { Start-Process $oc } else { Start-Process opencode }
```

- [ ] **Step 2: Parse**

Run: `$null=[System.Management.Automation.Language.Parser]::ParseFile("scripts\launch.ps1",[ref]$null,[ref]$null); if($?){"PARSE OK"}`
Expected: `PARSE OK`

- [ ] **Step 3: Commit**

```powershell
git add scripts/launch.ps1
git commit -m "feat: launch.ps1 tek-tik (sunucu+opencode)"
```

---

### Task 10: install-launcher.ps1 — Masaüstü + Start Menu kısayolu

**Files:** Create: `scripts/install-launcher.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/install-launcher.ps1` tam içeriği:

```powershell
# Masaustu + Start Menu'ye "Yargi Pro" kisayolu (gizli pencere -> launch.ps1).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$ps   = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$args = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$root\scripts\launch.ps1`""
$icon = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"
$ws = New-Object -ComObject WScript.Shell
$targets = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))
foreach ($dir in $targets) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $lnk = $ws.CreateShortcut((Join-Path $dir 'Yargi Pro.lnk'))
    $lnk.TargetPath = $ps
    $lnk.Arguments = $args
    $lnk.WorkingDirectory = $root
    if (Test-Path $icon) { $lnk.IconLocation = $icon }
    $lnk.Save()
    Write-Host "kisayol -> $(Join-Path $dir 'Yargi Pro.lnk')" -ForegroundColor Green
}
```

- [ ] **Step 2: Parse + gerçek çalıştır (kısayol oluşur)**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-launcher.ps1`
Expected: iki `kisayol -> ...` satırı; masaüstünde `Yargi Pro.lnk` görünür.

- [ ] **Step 3: Commit**

```powershell
git add scripts/install-launcher.ps1
git commit -m "feat: install-launcher.ps1 (.lnk masaustu+start menu)"
```

---

### Task 11: install-launcher.sh — /Applications/Yargı Pro.app üret

**Files:** Create: `scripts/install-launcher.sh`

- [ ] **Step 1: Scripti yaz**

`scripts/install-launcher.sh` tam içeriği:

```bash
#!/usr/bin/env bash
# /Applications/Yargi Pro.app uretir (Launchpad'de cift tik). Lokal uretildigi icin karantinasiz.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/Applications/Yargi Pro.app"
mkdir -p "$APP/Contents/MacOS"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>Yargi Pro</string>
  <key>CFBundleExecutable</key><string>launch</string>
  <key>CFBundleIdentifier</key><string>com.yargipro.launcher</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

cat > "$APP/Contents/MacOS/launch" <<LAUNCH
#!/bin/bash
ROOT="$ROOT"
if ! curl -s http://127.0.0.1:8080/v1/models >/dev/null 2>&1; then
  nohup bash "\$ROOT/scripts/start-server.sh" >/tmp/yargi-server.log 2>&1 &
  for i in \$(seq 1 120); do curl -s http://127.0.0.1:8080/v1/models >/dev/null 2>&1 && break; sleep 2; done
fi
open -a OpenCode
LAUNCH
chmod +x "$APP/Contents/MacOS/launch"
echo "Launcher -> $APP"
```

- [ ] **Step 2: Syntax + LF**

Run: `bash -n scripts/install-launcher.sh && echo OK`; sonra `tr -d '\r'`.
Expected: `OK`. (Gerçek `.app` üretimi Mac'te çalışır.)

- [ ] **Step 3: Commit**

```bash
git add scripts/install-launcher.sh
git commit -m "feat: install-launcher.sh (/Applications/Yargi Pro.app)"
```

---

## FAZ 5 — Installer'lara bağla

### Task 12: setup-all.ps1 — build yerine get-binary + preflight + launcher

**Files:** Modify: `scripts/setup-all.ps1` (tam yeniden yaz)

- [ ] **Step 1: setup-all.ps1'i yeniden yaz**

`scripts/setup-all.ps1` tam yeni içeriği:

```powershell
# Tek komutla idiot-proof kurulum (Windows): on-kontrol -> opencode -> prebuilt binary ->
# model -> config -> tek-tik launcher. DERLEME YOK.
$ErrorActionPreference = 'Stop'

# Self-elevate
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $admin) {
    Write-Host "Yonetici izni gerekiyor - UAC ile yeniden baslatiliyor..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$root = Split-Path -Parent $PSScriptRoot
$log  = Join-Path $root 'install.log'
function Step($name, $block) {
    Write-Host "`n--- $name ---" -ForegroundColor Cyan
    try { & $block } catch {
        ("[HATA] $name : $($_.Exception.Message)") | Tee-Object -FilePath $log -Append | Out-Host
        Write-Host "`nKURULUM DURDU. Su dosyayi gonderin: $log" -ForegroundColor Red
        Read-Host "Kapatmak icin Enter"; exit 1
    }
}

Start-Transcript -Path $log -Append | Out-Null

Step "On-kontroller" { & "$root\scripts\preflight.ps1"; if ($LASTEXITCODE -ne 0) { throw "on-kontrol basarisiz" } }
Step "opencode (CLI + desktop + config)" { & "$root\scripts\install-opencode.ps1" }
Step "Prebuilt binary indirme" { & "$root\scripts\get-binary.ps1" }
Step "Model indirme" { & "$root\scripts\download-model.ps1" }
Step "Tek-tik launcher" { & "$root\scripts\install-launcher.ps1" }

Stop-Transcript | Out-Null
Write-Host "`n=== HER SEY HAZIR ===" -ForegroundColor Green
Write-Host "Masaustundeki 'Yargi Pro' kisayoluna cift tikla." -ForegroundColor Green
Read-Host "`nBitti. Kapatmak icin Enter"
```

- [ ] **Step 2: Parse + ASCII**

Run: `$null=[System.Management.Automation.Language.Parser]::ParseFile("scripts\setup-all.ps1",[ref]$null,[ref]$null); if($?){"PARSE OK"}` ve non-ASCII=0 kontrolü.
Expected: `PARSE OK`, non-ASCII=0.

- [ ] **Step 3: Commit**

```powershell
git add scripts/setup-all.ps1
git commit -m "refactor: setup-all.ps1 idiot-proof (preflight/get-binary/launcher, derleme yok)"
```

---

### Task 13: setup-all.sh — Mac karşılığı

**Files:** Modify: `scripts/setup-all.sh` (tam yeniden yaz)

- [ ] **Step 1: setup-all.sh'i yeniden yaz**

`scripts/setup-all.sh` tam yeni içeriği:

```bash
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
```

- [ ] **Step 2: Syntax + LF**

Run: `bash -n scripts/setup-all.sh && echo OK`; sonra `tr -d '\r'`.
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add scripts/setup-all.sh
git commit -m "refactor: setup-all.sh idiot-proof (mac, derleme yok)"
```

---

### Task 14: install.ps1 / install.sh — log + temiz hata

**Files:** Modify: `install.ps1`, `install.sh`

- [ ] **Step 1: install.ps1'in son satırını sağlamlaştır**

`install.ps1` içinde `& (Join-Path $Dest 'scripts\setup-all.ps1')` satırını şununla değiştir:

```powershell
try {
    & (Join-Path $Dest 'scripts\setup-all.ps1')
} catch {
    Write-Host "[HATA] Kurulum basarisiz: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Log: $Dest\install.log" -ForegroundColor Yellow
    Read-Host "Kapatmak icin Enter"
}
```

- [ ] **Step 2: install.sh son satırını sağlamlaştır**

`install.sh` içinde `bash "$DEST/scripts/setup-all.sh"` satırını şununla değiştir:

```bash
if ! bash "$DEST/scripts/setup-all.sh"; then
  echo "[HATA] Kurulum basarisiz. Log: $DEST/install.log"
  read -r -p "Kapatmak icin Enter" _
fi
```

- [ ] **Step 3: Parse/syntax + commit**

Run: PS parse `install.ps1` + `bash -n install.sh`; `tr -d '\r' install.sh`.
```powershell
git add install.ps1 install.sh
git commit -m "feat: installer bootstrap'larina hata yakalama + log"
```

---

### Task 15: README — gereksinimler + akış güncelle

**Files:** Modify: `README.md`

- [ ] **Step 1: "Hızlı kurulum" altındaki donanım/akış notunu güncelle**

`README.md`'de `### Desteklenen donanım + otomatik model seçimi` bölümünün hemen üstüne ekle:

```markdown
### Gereksinimler
- **Windows:** NVIDIA kartı (RTX 20xx–50xx) + **sürücü ≥ 570.65** (installer kontrol eder), ~20 GB boş disk.
- **macOS:** Apple Silicon (Metal), ~20 GB boş disk.
- Kurulum **derleme yapmaz** — binary'ler GitHub'dan hazır iner (~15 dk, çoğu model indirme).
- Kurulum sonrası: **"Yargı Pro"** kısayolu (Win masaüstü / Mac Launchpad) → sunucuyu başlatır + opencode'u açar.
```

- [ ] **Step 2: Doğrula + commit**

Run: `(Get-Item README.md).Length -gt 0`
```powershell
git add README.md
git commit -m "docs: gereksinimler (surucu>=570.65) + tek-tik launcher akisi"
git push origin main
```

---

## Self-Review Notları

- **Spec coverage:** CI build (T1-4), prechecks (T5-6), prebuilt indirme (T7-8), launcher Win/Mac
  (T9-11), installer wiring + log/hata (T12-14), xattr+ad-hoc codesign (T8 + ci-build-mac T2),
  README/gereksinimler (T15) — hepsi karşılandı. CUDA 12.8 + arch listesi (T1/T3), sürücü 570.65
  (T5), DLL paketleme (T1) spec ile birebir.
- **Placeholder:** Yok — tüm script/YAML içerikleri tam.
- **Tutarlılık:** Asset adları (`llama-turboquant-{win-cuda,mac-arm64,mac-x64}.zip`), tag `binaries-v1`,
  binary yolu (`vendor/.../build/bin[/Release]/llama-server[.exe]`), port 8080, model id `gemma-4-qat`
  tüm görevlerde aynı. start-server'ın mevcut auto-find'ı get-binary'nin açtığı yolu bulur.
- **Bilinen kısıt:** En büyük risk T4'te (CI'da TheTom fork'unun CUDA 12.8 multi-arch derlenmesi) gerçek
  ortamda doğrulanır; başarısızlıkta DLL/sub-package ayarı T1/T3'te düzeltilir. Mac yolu Windows'tan
  test edilemez (CI mac job + Mac kurulum gerçek ortamda).
- **Sıra önemli:** FAZ 1 (release) önce; FAZ 3 (get-binary) FAZ 1 release'ine bağlı.
