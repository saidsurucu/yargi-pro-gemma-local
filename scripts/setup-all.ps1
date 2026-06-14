# Tek komutla tum on-kosullari kurar ve stack'i hazirlar.
# Calistir (normal PowerShell): UAC ile kendini yonetici olarak yeniden baslatir.
$ErrorActionPreference = 'Stop'

# --- 1) Yonetici izni (self-elevate) ---
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $admin) {
    Write-Host "Yonetici izni gerekiyor - UAC ile yeniden baslatiliyor..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$root = Split-Path -Parent $PSScriptRoot
Write-Host "=== Yargi Pro Local - Tam Kurulum ===" -ForegroundColor Cyan
Write-Host "Repo: $root`n"

# Kurulumlardan sonra TUM makine+user env degiskenlerini mevcut surece yukler.
# (CUDA_PATH_V13_x dahil - VS CUDA .targets bunlari okur.)
function Reload-Env {
    foreach ($scope in 'Machine','User') {
        $vars = [System.Environment]::GetEnvironmentVariables($scope)
        foreach ($k in $vars.Keys) {
            if ($k -ieq 'Path') { continue }
            Set-Item -Path "Env:$k" -Value $vars[$k] -ErrorAction SilentlyContinue
        }
    }
    $m = [System.Environment]::GetEnvironmentVariable('Path','Machine')
    $u = [System.Environment]::GetEnvironmentVariable('Path','User')
    $env:Path = "$m;$u"
}

# --- 2) Chocolatey ---
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "[KUR] Chocolatey..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    Reload-Env
} else { Write-Host "[VAR] Chocolatey" -ForegroundColor Green }

# --- 3) Prereqler (yalnizca eksik olanlar) ---
function Ensure-Tool($cmd, $pkg, $extraArgs) {
    if (Get-Command $cmd -ErrorAction SilentlyContinue) { Write-Host "[VAR] $cmd" -ForegroundColor Green; return }
    Write-Host "[KUR] $pkg ..." -ForegroundColor Cyan
    if ($extraArgs) { choco install -y $pkg @extraArgs } else { choco install -y $pkg }
    if ($LASTEXITCODE -ne 0) { throw "$pkg kurulamadi" }
    Reload-Env
}

Ensure-Tool 'git'    'git'        $null
Ensure-Tool 'python' 'python'     $null
Ensure-Tool 'node'   'nodejs-lts' $null
Ensure-Tool 'cmake'  'cmake'      @('--install-arguments=ADD_CMAKE_TO_PATH=System')

# CUDA Toolkit (buyuk ~3GB). nvcc yoksa kur.
if (-not (Get-Command nvcc -ErrorAction SilentlyContinue)) {
    Write-Host "[KUR] CUDA Toolkit (~3GB, biraz surebilir)..." -ForegroundColor Cyan
    choco install -y cuda
    if ($LASTEXITCODE -ne 0) { throw "CUDA Toolkit kurulamadi" }
    Reload-Env
} else { Write-Host "[VAR] nvcc (CUDA Toolkit)" -ForegroundColor Green }

# --- 4) On-kosul dogrulama ---
Write-Host "`n--- On-kosul dogrulama ---" -ForegroundColor Cyan
& "$root\scripts\check-prereqs.ps1"

# --- 5) Build + model + MCP ---
Write-Host "`n--- Inference engine derleniyor (uzun surebilir) ---" -ForegroundColor Cyan
& "$root\scripts\build-turboquant.ps1"

Write-Host "`n--- Model indiriliyor (~14.2 GB) ---" -ForegroundColor Cyan
& "$root\scripts\download-model.ps1"

Write-Host "`n--- Yargi Pro MCP ekleniyor ---" -ForegroundColor Cyan
& "$root\scripts\install-mcp.ps1"

Write-Host "`n=== HER SEY HAZIR ===" -ForegroundColor Green
Write-Host "Sunucuyu baslat: .\scripts\start-server.ps1" -ForegroundColor Green
Write-Host "Sonra yeni terminalde: opencode  (model: Gemma 4 26B QAT)" -ForegroundColor Green
Read-Host "`nBitti. Bu pencereyi kapatmak icin Enter'a basin"
