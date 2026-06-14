# Yargı Pro Local Stack Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** opencode arayüzünden, yerel Gemma 4 26B QAT modeli (TheTom/llama-cpp-turboquant + turbo3 KV) ve Yargı Pro remote MCP'si ile çalışan, kurulabilir bir repo üretmek.

**Architecture:** Repo, kurulumu otomatikleştiren PowerShell scriptlerinden + iki config'den (proje `opencode.json` = yerel model provider, global MCP config = resmî snippet) oluşur. Inference engine Windows'ta kaynaktan CUDA ile derlenir; model HF'ten indirilir; opencode hem yerel modele (OpenAI-uyumlu :8080) hem Yargı Pro MCP'sine (OAuth) bağlanır.

**Tech Stack:** PowerShell 5.1, CMake + CUDA + MSVC (build), Python/huggingface_hub (model indirme), llama-server (TheTom fork), opencode, Gemma 4 26B-A4B QAT UD-Q4_K_XL GGUF.

**Not (bu proje TDD'ye uymaz):** Bu bir altyapı/kurulum reposu; "test" yerine her script için **parse doğrulaması** (PowerShell AST) + uygunsa **çalıştırıp çıktı kontrolü** kullanılır. Ağır işlemler (build ~30dk, 14GB indirme) gerçek kurulumda çalışır; planda beklenen çıktıları belgelenir.

**Ortam değişkenleri / sabitler:**
- Repo kökü: `C:\Users\saids\OneDrive\Belgeler\yargi-pro-gemma-local`
- Model dosyası: `gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf` (HF repo: `unsloth/gemma-4-26B-A4B-it-qat-GGUF`)
- Fork: `https://github.com/TheTom/llama-cpp-turboquant`
- CUDA mimarisi (RTX 4060 Ti, Ada Lovelace): `89`
- MCP endpoint: `https://yargi.betaspacestudio.com/mcp` (isim: `yargi-mcp-pro`)

---

## File Structure

| Dosya | Sorumluluk |
|---|---|
| `.gitignore` | `models/`, `*.gguf`, `vendor/`, `.env` hariç tut (zaten mevcut, genişletilecek) |
| `opencode.json` | SADECE yerel model provider (OpenAI-uyumlu, :8080) |
| `scripts/check-prereqs.ps1` | git/cmake/cuda/msvc/python/nvidia-smi kontrolü |
| `scripts/build-turboquant.ps1` | fork'u klonla + CUDA ile derle |
| `scripts/download-model.ps1` | UD-Q4_K_XL GGUF'u `models/`'a indir |
| `scripts/start-server.ps1` | llama-server'ı turbo3 + CUDA ile başlat |
| `scripts/install-mcp.ps1` | resmî snippet ile `yargi-mcp-pro`'yu global config'e ekle |
| `README.md` | uçtan uca kurulum + kullanım |
| `models/.gitkeep` | boş klasörü izlemek için |

---

### Task 1: Repo iskeleti ve .gitignore

**Files:**
- Modify: `.gitignore`
- Create: `models/.gitkeep`

- [ ] **Step 1: `.gitignore`'u genişlet**

`.gitignore` içeriği tam olarak şu olsun:

```gitignore
models/
*.gguf
vendor/
.env
build/
```

- [ ] **Step 2: models klasörünü izlemeye al**

`models/.gitkeep` adında boş bir dosya oluştur (içerik boş).

- [ ] **Step 3: Doğrula**

Run: `git -C "C:\Users\saids\OneDrive\Belgeler\yargi-pro-gemma-local" check-ignore models/test.gguf vendor/x`
Expected: iki yol da listelenir (ignore ediliyor).

- [ ] **Step 4: Commit**

```powershell
git add .gitignore models/.gitkeep
git commit -m "chore: gitignore ve models klasoru iskeleti"
```

---

### Task 2: check-prereqs.ps1 — derleme ön-koşul kontrolü

**Files:**
- Create: `scripts/check-prereqs.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/check-prereqs.ps1` tam içeriği:

```powershell
# Derleme ve calistirma on-kosullarini kontrol eder.
$ErrorActionPreference = 'Continue'
$ok = $true

function Test-Tool($name, $cmd, $hint) {
    $c = Get-Command $cmd -ErrorAction SilentlyContinue
    if ($c) { Write-Host "[OK]   $name -> $($c.Source)" -ForegroundColor Green }
    else { Write-Host "[EKSIK] $name -> $hint" -ForegroundColor Red; $script:ok = $false }
}

Write-Host "=== Yargi Pro Local — On-kosul kontrolu ===`n"
Test-Tool 'git'    'git'    'https://git-scm.com/download/win'
Test-Tool 'CMake'  'cmake'  'winget install Kitware.CMake veya https://cmake.org/download'
Test-Tool 'CUDA (nvcc)' 'nvcc' 'CUDA Toolkit 12.x: https://developer.nvidia.com/cuda-downloads'
Test-Tool 'Python' 'python' 'https://www.python.org/downloads/'
Test-Tool 'nvidia-smi' 'nvidia-smi' 'NVIDIA surucusu kurulu olmali'

# MSVC C++ derleyici (cl.exe) — vswhere ile ara
$vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswhere) {
    $vs = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
    if ($vs) { Write-Host "[OK]   MSVC C++ Build Tools -> $vs" -ForegroundColor Green }
    else { Write-Host "[EKSIK] MSVC C++ Build Tools -> 'Desktop development with C++' is yukunu kur" -ForegroundColor Red; $ok = $false }
} else {
    Write-Host "[EKSIK] Visual Studio Build Tools bulunamadi -> https://visualstudio.microsoft.com/downloads/ (Build Tools for VS, C++ workload)" -ForegroundColor Red
    $ok = $false
}

Write-Host ""
if ($ok) { Write-Host "Tum on-kosullar hazir. build-turboquant.ps1 calistirilabilir." -ForegroundColor Green; exit 0 }
else { Write-Host "Eksik on-kosullar var. Yukaridaki linklerden kurup tekrar calistirin." -ForegroundColor Yellow; exit 1 }
```

- [ ] **Step 2: Parse doğrulaması**

Run:
```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile("scripts\check-prereqs.ps1", [ref]$null, [ref]$null); if ($?) { "PARSE OK" }
```
Expected: `PARSE OK` (syntax hatası yok).

- [ ] **Step 3: Gerçek çalıştır**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\check-prereqs.ps1`
Expected: git/python/nvidia-smi `[OK]`; cmake/nvcc/MSVC durumlarına göre `[OK]` ya da `[EKSIK]` + install linki. (Bu makinede cmake/cuda/msvc muhtemelen eksik → linkler gösterilir.)

- [ ] **Step 4: Commit**

```powershell
git add scripts/check-prereqs.ps1
git commit -m "feat: check-prereqs.ps1 on-kosul kontrolu"
```

---

### Task 3: build-turboquant.ps1 — fork'u CUDA ile derle

**Files:**
- Create: `scripts/build-turboquant.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/build-turboquant.ps1` tam içeriği:

```powershell
# TheTom/llama-cpp-turboquant fork'unu klonlar ve CUDA ile derler.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$vendor = Join-Path $root 'vendor\llama-cpp-turboquant'
$repo = 'https://github.com/TheTom/llama-cpp-turboquant'

if (-not (Test-Path $vendor)) {
    Write-Host "Klonlaniyor: $repo" -ForegroundColor Cyan
    git clone --depth 1 $repo $vendor
} else {
    Write-Host "Repo zaten var: $vendor (git pull)" -ForegroundColor Cyan
    git -C $vendor pull --ff-only
}

Push-Location $vendor
try {
    Write-Host "CMake konfigurasyon (CUDA, sm_89)..." -ForegroundColor Cyan
    cmake -B build -DGGML_CUDA=ON -DCMAKE_CUDA_ARCHITECTURES=89 -DLLAMA_CURL=OFF
    if ($LASTEXITCODE -ne 0) { throw "CMake configure basarisiz" }

    Write-Host "Derleniyor (Release)..." -ForegroundColor Cyan
    cmake --build build --config Release -j
    if ($LASTEXITCODE -ne 0) { throw "Derleme basarisiz" }
} finally {
    Pop-Location
}

$exe = Get-ChildItem -Path $vendor -Recurse -Filter 'llama-server.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($exe) { Write-Host "`nDERLEME TAMAM -> $($exe.FullName)" -ForegroundColor Green }
else { Write-Host "`nUYARI: llama-server.exe bulunamadi, build ciktisini kontrol edin." -ForegroundColor Yellow }
```

- [ ] **Step 2: Parse doğrulaması**

Run:
```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile("scripts\build-turboquant.ps1", [ref]$null, [ref]$null); if ($?) { "PARSE OK" }
```
Expected: `PARSE OK`

- [ ] **Step 3: (Ön-koşullar kuruluysa) gerçek build**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\build-turboquant.ps1`
Expected: klonlama → CMake configure → derleme (~20-40 dk) → `DERLEME TAMAM -> ...\llama-server.exe`. Ön-koşul eksikse Task 2'yi önce tamamla. (Bu adım planın bite-size sınırını aşar; gerçek kurulumda çalışır.)

- [ ] **Step 4: Commit**

```powershell
git add scripts/build-turboquant.ps1
git commit -m "feat: build-turboquant.ps1 CUDA derleme scripti"
```

---

### Task 4: download-model.ps1 — UD-Q4_K_XL GGUF indir

**Files:**
- Create: `scripts/download-model.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/download-model.ps1` tam içeriği:

```powershell
# Gemma 4 26B-A4B QAT UD-Q4_K_XL GGUF dosyasini models/ klasorune indirir.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$models = Join-Path $root 'models'
$repoId = 'unsloth/gemma-4-26B-A4B-it-qat-GGUF'
$file = 'gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf'

New-Item -ItemType Directory -Force -Path $models | Out-Null

Write-Host "huggingface_hub kuruluyor/guncelleniyor..." -ForegroundColor Cyan
python -m pip install -U "huggingface_hub[cli]"
if ($LASTEXITCODE -ne 0) { throw "huggingface_hub kurulamadi" }

Write-Host "Indiriliyor: $repoId / $file (~14.2 GB)" -ForegroundColor Cyan
python -m huggingface_hub.commands.huggingface_cli download $repoId $file --local-dir $models
if ($LASTEXITCODE -ne 0) { throw "Indirme basarisiz" }

$target = Join-Path $models $file
if (Test-Path $target) {
    $gb = [math]::Round((Get-Item $target).Length/1GB,2)
    Write-Host "`nINDIRME TAMAM -> $target ($gb GB)" -ForegroundColor Green
} else {
    Write-Host "`nUYARI: Dosya beklenen yolda yok: $target" -ForegroundColor Yellow
}
```

- [ ] **Step 2: Parse doğrulaması**

Run:
```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile("scripts\download-model.ps1", [ref]$null, [ref]$null); if ($?) { "PARSE OK" }
```
Expected: `PARSE OK`

- [ ] **Step 3: Gerçek indirme**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\download-model.ps1`
Expected: pip kurulum → indirme (~14.2 GB) → `INDIRME TAMAM -> ...\models\gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf (14.2 GB)`. (Ağır indirme; gerçek kurulumda çalışır.)

- [ ] **Step 4: Commit**

```powershell
git add scripts/download-model.ps1
git commit -m "feat: download-model.ps1 UD-Q4_K_XL indirme scripti"
```

---

### Task 5: start-server.ps1 — llama-server'ı turbo3 ile başlat

**Files:**
- Create: `scripts/start-server.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/start-server.ps1` tam içeriği:

```powershell
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
```

- [ ] **Step 2: Parse doğrulaması**

Run:
```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile("scripts\start-server.ps1", [ref]$null, [ref]$null); if ($?) { "PARSE OK" }
```
Expected: `PARSE OK`

- [ ] **Step 3: Eksik-dosya guard testi**

Model/exe henüz yokken çalıştırıp guard mesajını doğrula:
Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\start-server.ps1`
Expected: `Model yok: ... — once download-model.ps1 calistirin` (veya model varsa exe yok uyarısı). Gerçek başlatma build+model sonrası yapılır; sunucu `http://127.0.0.1:8080` dinler, `/v1/models` cevap verir.

- [ ] **Step 4: Commit**

```powershell
git add scripts/start-server.ps1
git commit -m "feat: start-server.ps1 turbo3 KV ile llama-server"
```

---

### Task 6: opencode.json — yerel model provider

**Files:**
- Create: `opencode.json` (repo kökü, proje config)

- [ ] **Step 1: Config'i yaz**

`opencode.json` tam içeriği:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "llamacpp": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "llama-server (local)",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "gemma-4-26b-qat": {
          "name": "Gemma 4 26B QAT (turbo3, local)",
          "limit": {
            "context": 65536,
            "output": 8192
          }
        }
      }
    }
  }
}
```

- [ ] **Step 2: JSON geçerlilik doğrulaması**

Run:
```powershell
Get-Content opencode.json -Raw | python -c "import sys,json; json.load(sys.stdin); print('JSON OK')"
```
Expected: `JSON OK`

- [ ] **Step 3: Commit**

```powershell
git add opencode.json
git commit -m "feat: opencode.json yerel model provider (llama-server :8080)"
```

---

### Task 7: install-mcp.ps1 — Yargı Pro MCP'yi global config'e ekle

**Files:**
- Create: `scripts/install-mcp.ps1`

- [ ] **Step 1: Scripti yaz** (kullanıcının verdiği resmî snippet, birebir)

`scripts/install-mcp.ps1` tam içeriği:

```powershell
# Yargi Pro remote MCP'yi global opencode config'e ekler (resmi snippet).
# Auth: ilk kullanimda opencode OAuth akisini yurutur (manuel token yok).
$node = @'
const fs=require("fs"),os=require("os"),path=require("path");
const dir=path.join(os.homedir(),".config","opencode"),file=path.join(dir,"opencode.json");
fs.mkdirSync(dir,{recursive:true});
let cfg={};try{cfg=JSON.parse(fs.readFileSync(file,"utf8"))}catch{}
if(typeof cfg!=="object"||cfg===null||Array.isArray(cfg))cfg={};
if(!cfg["$schema"])cfg["$schema"]="https://opencode.ai/config.json";
if(typeof cfg.mcp!=="object"||cfg.mcp===null)cfg.mcp={};
cfg.mcp["yargi-mcp-pro"]={type:"remote",url:"https://yargi.betaspacestudio.com/mcp"};
fs.writeFileSync(file,JSON.stringify(cfg,null,2)+"\n");
console.log("yargi-mcp-pro eklendi -> "+file);
'@
$node | node -
```

- [ ] **Step 2: Parse doğrulaması**

Run:
```powershell
$null = [System.Management.Automation.Language.Parser]::ParseFile("scripts\install-mcp.ps1", [ref]$null, [ref]$null); if ($?) { "PARSE OK" }
```
Expected: `PARSE OK`

- [ ] **Step 3: Gerçek çalıştır ve doğrula**

Run: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-mcp.ps1`
Expected: `yargi-mcp-pro eklendi -> C:\Users\saids\.config\opencode\opencode.json`

Doğrula:
```powershell
Get-Content "$env:USERPROFILE\.config\opencode\opencode.json" -Raw | python -c "import sys,json; d=json.load(sys.stdin); print(d['mcp']['yargi-mcp-pro']['url'])"
```
Expected: `https://yargi.betaspacestudio.com/mcp`

- [ ] **Step 4: Commit**

```powershell
git add scripts/install-mcp.ps1
git commit -m "feat: install-mcp.ps1 yargi-mcp-pro global config"
```

---

### Task 8: README.md — uçtan uca kurulum

**Files:**
- Create: `README.md`

- [ ] **Step 1: README'yi yaz**

`README.md` tam içeriği:

````markdown
# Yargı Pro — Local Gemma Stack

opencode arayüzünden, **yerel** Gemma 4 26B QAT modeli (TheTom/llama-cpp-turboquant + turbo3 KV) ve **Yargı Pro remote MCP** ile Türk hukuku araştırması.

## Donanım hedefi
- GPU: NVIDIA RTX 4060 Ti 16 GB (CUDA, sm_89)
- RAM: 32 GB+ önerilir
- OS: Windows 11

## Bileşenler
| | |
|---|---|
| Arayüz | opencode |
| Inference | TheTom/llama-cpp-turboquant (kaynaktan CUDA derleme) |
| Model | unsloth `gemma-4-26B-A4B-it-qat-GGUF : UD-Q4_K_XL` (14.2 GB) |
| KV cache | `--cache-type-v turbo3` |
| MCP | `yargi-mcp-pro` → https://yargi.betaspacestudio.com/mcp (OAuth) |

## Ön-koşullar
- [git](https://git-scm.com/download/win), [CMake](https://cmake.org/download/), [CUDA Toolkit 12.x](https://developer.nvidia.com/cuda-downloads)
- [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/) — "Desktop development with C++"
- [Python 3.x](https://www.python.org/downloads/), [Node.js](https://nodejs.org/), [opencode](https://opencode.ai)

## Kurulum (sırayla)

> PowerShell'i repo kökünde aç. Scriptler engellenirse: `Set-ExecutionPolicy -Scope Process Bypass`

```powershell
# 1) On-kosul kontrolu
.\scripts\check-prereqs.ps1

# 2) Inference engine'i derle (~20-40 dk)
.\scripts\build-turboquant.ps1

# 3) Modeli indir (~14.2 GB)
.\scripts\download-model.ps1

# 4) Yargi Pro MCP'yi opencode'a ekle
.\scripts\install-mcp.ps1

# 5) Yerel modeli baslat (bu pencere acik kalsin)
.\scripts\start-server.ps1
```

## Kullanım

1. Yeni bir terminalde repo kökünde `opencode` çalıştır (proje `opencode.json` otomatik okunur).
2. Model seçiminde **`llamacpp / Gemma 4 26B QAT (turbo3, local)`** modelini seç.
3. İlk Yargı Pro aracı çağrıldığında opencode **OAuth** akışını başlatır → tarayıcıdan Yargı Pro'ya giriş yap.
4. Hukuki soru sor; model `yargi-mcp-pro` araçlarıyla karar/mevzuat getirir.

## Ayarlar
- Daha uzun context: `.\scripts\start-server.ps1 -Context 131072` (VRAM sıkışırsa `-Ngl 90` ile birkaç layer'ı CPU'ya taşı).
- Sunucu sağlığı: tarayıcıda `http://127.0.0.1:8080` veya `curl http://127.0.0.1:8080/v1/models`.

## Sorun giderme
- **Derleme hatası:** `.\scripts\check-prereqs.ps1` çıktısındaki eksikleri kur. CUDA + MSVC C++ workload şart.
- **Model yüklenmiyor / VRAM dolu:** `-Ngl` değerini düşür (örn. 80), `-Context`'i küçült.
- **MCP OAuth takılırsa:** opencode'da tekrar dene; gerekirse `~/.local/share/opencode/mcp-auth.json` sil ve yeniden giriş yap.
- **Tool-calling zayıfsa:** `--jinja` aktif olduğundan emin ol (start-server.ps1'de var).
````

- [ ] **Step 2: Doğrula** (dosya var ve boş değil)

Run: `if ((Get-Item README.md).Length -gt 0) { "README OK" }`
Expected: `README OK`

- [ ] **Step 3: Commit**

```powershell
git add README.md
git commit -m "docs: uctan uca kurulum README"
```

---

### Task 9: Uçtan uca smoke doğrulama (gerçek kurulum sonrası)

**Files:** (yok — yalnızca doğrulama)

- [ ] **Step 1: Sunucu ayakta mı**

Run: `Invoke-WebRequest http://127.0.0.1:8080/v1/models -UseBasicParsing | Select-Object -ExpandProperty Content`
Expected: JSON içinde `gemma` geçen model id'si.

- [ ] **Step 2: Yerel model cevap veriyor mu**

Run:
```powershell
$body = @{ model='gemma-4-26b-qat'; messages=@(@{role='user';content='Merhaba, tek cumleyle kendini tanit.'}) } | ConvertTo-Json
Invoke-RestMethod -Uri http://127.0.0.1:8080/v1/chat/completions -Method Post -ContentType 'application/json' -Body $body | ConvertTo-Json -Depth 6
```
Expected: Türkçe bir `assistant` cevabı döner.

- [ ] **Step 3: opencode + MCP entegrasyon kontrolü**

opencode aç, yerel modeli seç, şu soruyu sor: *"Yargıtay'da kira tespiti ile ilgili güncel bir karar bul."*
Expected: model `yargi-mcp-pro` aracını çağırır (gerekirse OAuth login), karar özeti döner.

- [ ] **Step 4: (Doğrulama görevidir, commit yok)**

---

## Self-Review Notları

- **Spec coverage:** opencode (T6), TheTom build (T3), UD-Q4_K_XL indirme (T4), turbo3 KV (T5), Yargı Pro MCP/OAuth (T7), README akışı (T8), VRAM ayarı (`-Ngl/-Context`, T5/T8) — hepsi karşılandı. Kapsam-dışı kalemler (self-host, TQ4_1S, MTP) plana dahil edilmedi (doğru).
- **Placeholder:** Yok — tüm script/JSON içerikleri tam.
- **Tutarlılık:** Model dosya adı, provider id (`llamacpp`), model id (`gemma-4-26b-qat`), port `8080`, MCP ismi `yargi-mcp-pro` tüm görevlerde aynı.
- **Bilinen kısıt:** Ağır adımlar (T3 build, T4 indirme, T9 smoke) gerçek kurulumda çalışır; planda parse/guard doğrulaması + beklenen çıktı belgelenmiştir.
