# Yargı Pro — Local Gemma Stack

opencode arayüzünden, **yerel** Gemma 4 26B QAT modeli (TheTom/llama-cpp-turboquant + turbo3 KV) ve **Yargı Pro remote MCP** ile Türk hukuku araştırması.

## ⚡ Tek satır kurulum

**Windows (NVIDIA / CUDA)** — normal PowerShell, UAC'ye **Evet**:

```powershell
irm https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.ps1 | iex
```

**macOS (Apple Silicon / Metal)** — Terminal:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.sh)"
```

Gerisi otomatik: paket yöneticisi (Chocolatey/Homebrew) → CMake → CUDA(Win)/Metal(Mac) → TheTom fork derleme → model (~14 GB) → opencode CLI+desktop → MCP. Bitince Win'de `.\scripts\start-server.ps1`, Mac'te `./scripts/start-server.sh` çalıştır, opencode'u aç.

### Gereksinimler
- **Windows:** NVIDIA kartı (RTX 20xx–50xx) + **sürücü ≥ 570.65** (installer kontrol eder), ~20 GB boş disk.
- **macOS:** Apple Silicon (Metal), ~20 GB boş disk.
- Kurulum **derleme yapmaz** — binary'ler GitHub'dan hazır iner (~15 dk, çoğu model indirme).
- Kurulum sonrası: **"Yargı Pro"** kısayolu (Win masaüstü / Mac Launchpad) → sunucuyu başlatır + opencode'u açar.

### Desteklenen donanım + otomatik model seçimi
Kurulum belleğe göre **modeli otomatik seçer**:

| Donanım | Seçilen model |
|---|---|
| NVIDIA VRAM ≥ 16 GB **veya** Mac RAM ≥ 24 GB | **Gemma 4 26B-A4B** QAT UD-Q4_K_XL (~14.2 GB) |
| Altında | **Gemma 4 12B** QAT UD-Q4_K_XL (~6.7 GB) |

- **Windows:** herhangi bir NVIDIA kartı — derleme GPU mimarisini (`compute_cap`) `nvidia-smi`'den **otomatik** algılar (RTX 30/40/50, vb.).
- **macOS:** Apple Silicon (M-serisi, Metal). ⚠️ Metal'de `turbo3` KV desteklenmezse: `CACHE_K=f16 CACHE_V=f16 ./scripts/start-server.sh`.
- İlk kurulum uzun sürer (derleme + model indirme). `start-server` `models/`'daki gguf'u otomatik bulur.

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

## Hızlı kurulum (tek komut)

Her şeyi (Chocolatey → CMake → CUDA Toolkit → derleme → model indirme → MCP) baştan sona kurar. Normal PowerShell'e yapıştır; UAC çıkınca **Evet** de (kendini yönetici olarak yeniden başlatır):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "C:\Users\saids\OneDrive\Belgeler\yargi-pro-gemma-local\scripts\setup-all.ps1"
```

Bitince sadece `.\scripts\start-server.ps1` çalıştırıp `opencode` aç. CUDA Toolkit ~3 GB + derleme ~20-40 dk + model ~14.2 GB olduğundan ilk kurulum uzun sürer. Adım adım yapmak istersen aşağıdaki manuel akışı kullan.

## Kurulum (manuel, sırayla)

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
- **Varsayılan context = 131072 (128K)**, K+V ikisi de `turbo3`. 16 GB'ye sığar (~15.9 GB) ama **çok dar** — başka GPU uygulaması (LM Studio, Chrome vb.) açıkken OOM olur, önce onları kapat.
- Daha güvenli/küçük: `.\scripts\start-server.ps1 -Context 32768`. VRAM hâlâ sıkışırsa `-Ngl 90` ile birkaç layer'ı CPU'ya taşı.
- Sunucu sağlığı: tarayıcıda `http://127.0.0.1:8080` veya `curl http://127.0.0.1:8080/v1/models`.

## Sorun giderme
- **Derleme hatası:** `.\scripts\check-prereqs.ps1` çıktısındaki eksikleri kur. CUDA + MSVC C++ workload şart.
- **`CudaToolkitDir '' does not exist` (configure hatası):** CUDA env değişkenleri (`CUDA_PATH_V13_x`) o oturumda yok. Scriptler bunu otomatik tazeler; manuel derlerken yeni bir terminal aç.
- **Model yüklenmiyor / VRAM dolu:** 16 GB'de model ~14 GB yer kaplar; **LM Studio, Chrome, oyun launcher'ları gibi GPU kullanan uygulamaları kapat** (VRAM'i paylaşıyorlar). Hâlâ sığmazsa `-Ngl` değerini düşür (örn. 80) veya `-Context`'i küçült.
- **Cevap boş geliyor / sadece düşünüyor:** Gemma 4 "thinking" modu açık; önce akıl yürütür (reasoning), sonra cevap verir. Yeterli çıktı token'ı bırak (opencode.json `output: 8192`). Çok kısa `max_tokens` verirsen düşünme bitmeden limite takılır.
- **İndirme 0 byte'ta takılıyor:** HF dosyayı xethub CDN'ine yönlendiriyor; script zaten `curl.exe` ile indiriyor (resume destekli — tekrar çalıştırırsan kaldığı yerden devam eder).
- **MCP OAuth takılırsa:** opencode'da tekrar dene; gerekirse Windows'ta `%USERPROFILE%\.local\share\opencode\mcp-auth.json` dosyasını sil ve yeniden giriş yap. (Global config: `%USERPROFILE%\.config\opencode\opencode.json`.)
- **Tool-calling zayıfsa:** `--jinja` aktif olduğundan emin ol (start-server.ps1'de var).

## Performans (ölçülen — RTX 4060 Ti 16 GB, 128K context, K+V turbo3, -ngl 99)

| Model | Aktif param | Hız | VRAM | Disk (GGUF) |
|---|---|---|---|---|
| **26B-A4B** QAT UD-Q4_K_XL (MoE) | ~4B | **~72 tok/s** | **~15.9 GB** | 13.3 GiB |
| **12B** QAT UD-Q4_K_XL (dense) | 12B | **~32 tok/s** | **~8.7 GB** | 6.3 GiB |

> İlginç: **26B, 12B'den hızlı** — çünkü 26B-A4B bir **MoE** modeli, üretimde yalnızca ~4B parametre aktif; 12B ise dense (tamamı aktif). Yani 26B hem daha akıllı hem daha hızlı, sadece daha çok VRAM ister.

- 128K bağlam TurboQuant (turbo3 KV) sayesinde 16 GB'ye sığıyor; 26B'de VRAM çok dar (~15.9/16 GB) → **diğer GPU uygulamalarını kapat**. 12B'de bol headroom var (~8.7 GB), 12 GB'lik kartlara da uygun.
- Hem 26B hem 12B doğru Türkçe hukuki cevap üretti; Yargı Pro MCP araç çağrıları (tool-calling) opencode'da çalışıyor.
