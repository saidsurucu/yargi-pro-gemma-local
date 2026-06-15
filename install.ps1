# Yargi Pro Local - tek satir uzaktan kurulum bootstrap.
# Kullanim (normal PowerShell):
#   irm https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.ps1 | iex
$ErrorActionPreference = 'Stop'
# Bu surec icin script calistirmayi ac (Restricted politikada & ile .ps1 cagrilari engelleniyor).
Set-ExecutionPolicy -Scope Process Bypass -Force -ErrorAction SilentlyContinue

# === Dagitim ayarlari (kendi repo'na gore degistir) ===
$RepoUrl    = 'https://github.com/saidsurucu/yargi-pro-gemma-local.git'
$InstallUrl = 'https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.ps1'
$Dest       = Join-Path $env:USERPROFILE 'yargi-pro-gemma-local'

Write-Host "=== Yargi Pro Local - Kurulum ===" -ForegroundColor Cyan

# --- Yonetici izni (UAC ile elevated shell'de kendini yeniden cek) ---
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
if (-not $admin) {
    Write-Host "Yonetici izni gerekiyor - UAC ile yeniden baslatiliyor..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"irm $InstallUrl | iex`""
    return
}

# --- Chocolatey (git icin gerekli) ---
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "[KUR] Chocolatey..." -ForegroundColor Cyan
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
}

# --- git ---
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[KUR] git..." -ForegroundColor Cyan
    choco install -y git
    if ($LASTEXITCODE -ne 0) { throw "git kurulamadi" }
    $env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')
}

# --- Repo'yu klonla / guncelle ---
if (Test-Path (Join-Path $Dest '.git')) {
    Write-Host "[GIT] Repo guncelleniyor: $Dest" -ForegroundColor Cyan
    git -C $Dest pull --ff-only
} else {
    Write-Host "[GIT] Klonlaniyor: $RepoUrl -> $Dest" -ForegroundColor Cyan
    git clone $RepoUrl $Dest
    if ($LASTEXITCODE -ne 0) { throw "git clone basarisiz" }
}

# --- Tam kurulumu calistir (choco/cmake/cuda/build/model/opencode/mcp) ---
Write-Host "[RUN] setup-all.ps1 calistiriliyor..." -ForegroundColor Cyan
& (Join-Path $Dest 'scripts\setup-all.ps1')
if ($LASTEXITCODE -ne 0) {
    Write-Host "[HATA] Kurulum tamamlanamadi. Log: $Dest\install.log" -ForegroundColor Red
}
