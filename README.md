# Yargı Pro — Local Gemma Stack

opencode arayüzünden, **yerel** Gemma 4 26B QAT modeli (TheTom/llama-cpp-turboquant + turbo3 KV) ve **Yargı Pro remote MCP** ile Türk hukuku araştırması.

## ⚡ Tek satır kurulum (Windows)

Normal PowerShell'e yapıştır, UAC'ye **Evet** de — gerisi otomatik (Chocolatey, CMake, CUDA, derleme, model, opencode CLI+desktop, MCP):

```powershell
irm https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.ps1 | iex
```

cmd/bash içinden çalıştırmak için:

```bash
powershell -NoProfile -ExecutionPolicy Bypass -Command "irm https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.ps1 | iex"
```

> İlk kurulum uzun sürer: CUDA Toolkit ~3 GB + derleme ~20-40 dk + model ~14 GB. Bitince `.\scripts\start-server.ps1` çalıştır, opencode'u aç.

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

## Performans (RTX 4060 Ti 16 GB, ölçülen)
- ~72 token/s üretim, **128K context** (K+V turbo3, -ngl 99), VRAM ~15.9/16 GB stabil. TurboQuant sayesinde 128K bağlam 16 GB'ye sığıyor; ama diğer GPU uygulamaları kapalı olmalı.
