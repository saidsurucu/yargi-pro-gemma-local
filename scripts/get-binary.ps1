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
