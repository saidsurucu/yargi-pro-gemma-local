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

# models/ icindeki gguf'u otomatik bul (12B veya 26B - download-model.ps1 secer). Birden fazlaysa en buyugu.
$model = (Get-ChildItem -Path (Join-Path $root 'models') -Filter '*.gguf' -ErrorAction SilentlyContinue | Sort-Object Length -Descending | Select-Object -First 1).FullName
if (-not $model) { throw "models/ icinde .gguf yok - once download-model.ps1 calistirin" }

$exe = Get-ChildItem -Path $vendor -Recurse -Filter 'llama-server.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if (-not $exe) { throw "llama-server.exe yok - once build-turboquant.ps1 calistirin" }

$logDir = Join-Path $root 'logs'
New-Item -ItemType Directory -Force -Path $logDir | Out-Null
$serverLog = Join-Path $logDir 'server.log'

Write-Host "Baslatiliyor: $($exe.FullName)" -ForegroundColor Cyan
Write-Host "Model: $model | Context: $Context | Ngl: $Ngl | Port: $Port" -ForegroundColor Cyan
Write-Host "Log: $serverLog (crash olursa bu dosyayi gonderin)" -ForegroundColor DarkGray

# Not: --cache-type-v turbo3, TheTom/llama-cpp-turboquant fork'una ozgudur; standart llama.cpp'de yoktur.
# Cikti hem konsola hem logs\server.log'a yazilir (tray gizli pencerede baslattigi icin crash sebebi aksi halde kaybolur).
& $exe.FullName `
    -m $model `
    -ngl $Ngl `
    -fa on `
    --cache-type-k turbo3 `
    --cache-type-v turbo3 `
    -c $Context `
    --host 127.0.0.1 `
    --port $Port `
    --jinja 2>&1 | Tee-Object -FilePath $serverLog
