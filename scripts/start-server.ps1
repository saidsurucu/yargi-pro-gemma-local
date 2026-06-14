# llama-server'i Gemma 4 26B QAT + turbo3 KV ile baslatir.
# Kullanim: .\start-server.ps1 [-Context 65536] [-Ngl 99]
param(
    [int]$Context = 65536,
    [int]$Ngl = 99,
    [int]$Port = 8080
)
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$vendor = Join-Path $root 'vendor\llama-cpp-turboquant'
$model = Join-Path $root 'models\gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf'

if (-not (Test-Path $model)) { throw "Model yok: $model — once download-model.ps1 calistirin" }

$exe = Get-ChildItem -Path $vendor -Recurse -Filter 'llama-server.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) { throw "llama-server.exe yok — once build-turboquant.ps1 calistirin" }

Write-Host "Baslatiliyor: $($exe.FullName)" -ForegroundColor Cyan
Write-Host "Model: $model | Context: $Context | Ngl: $Ngl | Port: $Port" -ForegroundColor Cyan

& $exe.FullName `
    -m $model `
    -ngl $Ngl `
    -fa on `
    --cache-type-k q8_0 `
    --cache-type-v turbo3 `
    -c $Context `
    --host 127.0.0.1 `
    --port $Port `
    --jinja
