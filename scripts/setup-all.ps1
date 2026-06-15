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
Step "Visual C++ Runtime (vcredist)" {
    # llama-server.exe MSVC ile derlenir; temiz makinede vcruntime140/msvcp140 yoksa exe yuklenemez.
    choco install vcredist140 -y --no-progress
    if ($LASTEXITCODE -ne 0 -and $LASTEXITCODE -ne 3010) { throw "vcredist kurulamadi (exit $LASTEXITCODE)" }
}
Step "opencode (CLI + desktop + config)" { & "$root\scripts\install-opencode.ps1" }
Step "Prebuilt binary indirme" { & "$root\scripts\get-binary.ps1" }
Step "Model indirme" { & "$root\scripts\download-model.ps1" }
Step "Tek-tik launcher" { & "$root\scripts\install-launcher.ps1" }

Stop-Transcript | Out-Null
Write-Host "`n=== HER SEY HAZIR ===" -ForegroundColor Green
Write-Host "Masaustundeki 'Yargi Pro' kisayoluna cift tikla." -ForegroundColor Green
Read-Host "`nBitti. Kapatmak icin Enter"
