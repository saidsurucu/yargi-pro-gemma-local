# Prefill (prompt isleme) hizini olcer ve farkli KV-cache/batch ayarlarini karsilastirir.
# Amac: yavaslik turbo3 KV'den mi yoksa batch'ten mi geliyor bulmak. DEGISIKLIK YAPMAZ, sadece olcer.
# Kullanim: tray'de "Durdur" -> bu scripti calistir.  Sonuc tablosunu paylas.
$ErrorActionPreference = 'Stop'
$root   = Split-Path -Parent $PSScriptRoot
$model  = (Get-ChildItem -Path (Join-Path $root 'models') -Filter '*.gguf' | Sort-Object Length -Descending | Select-Object -First 1).FullName
$exe    = (Get-ChildItem -Path (Join-Path $root 'vendor\llama-cpp-turboquant') -Recurse -Filter 'llama-server.exe' | Select-Object -First 1).FullName
$port   = 8099
$ctx    = 4096
$logDir = Join-Path $root 'logs'; New-Item -ItemType Directory -Force -Path $logDir | Out-Null

if (-not $model) { throw "model bulunamadi" }
if (-not $exe)   { throw "llama-server.exe bulunamadi" }

Write-Host "Model: $model" -ForegroundColor Cyan
Write-Host "Exe  : $exe`n" -ForegroundColor Cyan

# Calisan sunucuyu kapat (VRAM bos olsun ki benchmark modeli yukleyebilsin).
Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Seconds 2

# Sabit ~1200 token'lik prompt (her config icin ayni -> adil karsilastirma).
$prompt = ("Turk hukuku, yargi kararlari ve mevzuat hakkinda detayli bir analiz metni yaziyoruz. " * 120)

# Test edilecek konfigurasyonlar
$configs = @(
    @{ name = 'turbo3 (mevcut varsayilan)'; extra = @('--cache-type-k','turbo3','--cache-type-v','turbo3') }
    @{ name = 'f16 KV';                      extra = @('--cache-type-k','f16','--cache-type-v','f16') }
    @{ name = 'turbo3 + buyuk batch (ub2048)'; extra = @('--cache-type-k','turbo3','--cache-type-v','turbo3','-b','2048','-ub','2048') }
)

function Wait-Ready($port, $timeoutSec) {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    while ($sw.Elapsed.TotalSeconds -lt $timeoutSec) {
        try {
            $h = Invoke-RestMethod -Uri "http://127.0.0.1:$port/health" -TimeoutSec 3
            if ($h.status -eq 'ok') { return $true }
        } catch {}
        Start-Sleep -Milliseconds 800
    }
    return $false
}

function Measure-Prefill($port, $prompt) {
    $body = @{ prompt = $prompt; n_predict = 32; temperature = 0; cache_prompt = $false } | ConvertTo-Json
    # 1. istek: isinma (atilir). 2. istek: olcum.
    $null = Invoke-RestMethod -Uri "http://127.0.0.1:$port/completion" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 300
    $r = Invoke-RestMethod -Uri "http://127.0.0.1:$port/completion" -Method Post -Body $body -ContentType 'application/json' -TimeoutSec 300
    return $r.timings
}

$results = @()
foreach ($cfg in $configs) {
    Write-Host "=== $($cfg.name) ===" -ForegroundColor Yellow
    $errLog = Join-Path $logDir ("bench-" + ($cfg.name -replace '[^a-zA-Z0-9]','_') + ".log")
    $argList = @('-m',$model,'-ngl','99','-fa','on','-c',$ctx,'--host','127.0.0.1','--port',$port,'--no-warmup') + $cfg.extra
    $p = Start-Process -FilePath $exe -ArgumentList $argList -PassThru -NoNewWindow `
            -RedirectStandardOutput $errLog -RedirectStandardError "$errLog.err"
    try {
        if (-not (Wait-Ready $port 180)) { Write-Host "  [HATA] sunucu hazir olmadi (bkz $errLog.err)" -ForegroundColor Red; continue }
        $t = Measure-Prefill $port $prompt
        $pp = [math]::Round($t.prompt_per_second,1)
        $tg = [math]::Round($t.predicted_per_second,1)
        Write-Host ("  prompt tokens={0}  PREFILL={1} tok/s  GENERATION={2} tok/s" -f $t.prompt_n,$pp,$tg) -ForegroundColor Green
        $results += [pscustomobject]@{ Config=$cfg.name; PromptTokens=$t.prompt_n; Prefill_tps=$pp; Gen_tps=$tg }
    } finally {
        Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 2
    }
}

Write-Host "`n===== SONUC =====" -ForegroundColor Cyan
$results | Format-Table -AutoSize
Write-Host "`nBu tabloyu paylas. (Prefill turbo3'te dusuk, f16'da yuksekse -> suclu turbo3 KV / Blackwell cekirdekleri.)" -ForegroundColor Cyan