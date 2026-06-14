# llama-server'i Gemma 4 26B QAT + turbo3 KV ile baslatir.
# Kullanim: .\start-server.ps1 [-Context 65536] [-Ngl 99]
param(
    [int]$Context = 131072,
    [int]$Ngl = 99,
    [int]$Port = 8080
)
$ErrorActionPreference = 'Stop'

# CUDA runtime DLL'leri icin env'i tazele (PATH'e CUDA bin gerekir).
foreach ($scope in 'Machine','User') {
    $vars = [System.Environment]::GetEnvironmentVariables($scope)
    foreach ($k in $vars.Keys) { if ($k -ine 'Path') { Set-Item -Path "Env:$k" -Value $vars[$k] -ErrorAction SilentlyContinue } }
}
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

$root = Split-Path -Parent $PSScriptRoot
$vendor = Join-Path $root 'vendor\llama-cpp-turboquant'
$model = Join-Path $root 'models\gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf'

if (-not (Test-Path $model)) { throw "Model yok: $model - once download-model.ps1 calistirin" }

$exe = Get-ChildItem -Path $vendor -Recurse -Filter 'llama-server.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) { throw "llama-server.exe yok - once build-turboquant.ps1 calistirin" }

Write-Host "Baslatiliyor: $($exe.FullName)" -ForegroundColor Cyan
Write-Host "Model: $model | Context: $Context | Ngl: $Ngl | Port: $Port" -ForegroundColor Cyan

# Not: --cache-type-v turbo3, TheTom/llama-cpp-turboquant fork'una ozgudur; standart llama.cpp'de yoktur.
& $exe.FullName `
    -m $model `
    -ngl $Ngl `
    -fa on `
    --cache-type-k turbo3 `
    --cache-type-v turbo3 `
    -c $Context `
    --host 127.0.0.1 `
    --port $Port `
    --jinja
