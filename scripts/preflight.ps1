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
    $drv = ((& nvidia-smi --query-gpu=driver_version --format=csv,noheader) | Select-Object -First 1).Trim()
    $global:LASTEXITCODE = 0  # nvidia-smi'nin Select-Object -First ile erken kesilmesinden kalan exit kodunu sifirla
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
exit 0  # basari yolunda exit kodunu kesinlestir (caller $LASTEXITCODE'a bakiyor)
