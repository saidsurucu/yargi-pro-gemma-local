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
# -C - : yarim kalan indirmeden devam (743 MB'i her seferinde bastan indirme).
# --retry-all-errors : 'connection reset' (curl 56) gibi hatalarda da tekrar dene.
curl.exe -L -C - --retry 8 --retry-delay 5 --retry-all-errors -o "$zip" "$url"
$code = $LASTEXITCODE
# 33 = HTTP range error (416): dosya zaten tam inmis; hata degil, ace gec.
if ($code -ne 0 -and $code -ne 33) { throw "binary indirilemedi (curl exit $code)" }
Expand-Archive -Path $zip -DestinationPath $dest -Force
if (-not (Test-Path $exe)) { throw "binary acilmadi/eksik: $exe" }
Write-Host "Binary hazir -> $exe" -ForegroundColor Green
