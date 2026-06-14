# Yargı Pro — Yerel Gemma Stack

opencode arayüzü üzerinden, **bilgisayarınızda yerel olarak çalışan** Gemma 4 QAT modeli (TheTom/llama-cpp-turboquant + turbo3 KV) ve **Yargı Pro remote MCP** ile Türk hukuku araştırması.

> 👩‍⚖️ **Avukat veya teknik olmayan bir kullanıcı mısınız?** Bu sayfa geliştiriciler içindir. Adım adım, jargonsuz kurulum için lütfen **➡️ [KURULUM-REHBERI.md](KURULUM-REHBERI.md)** dosyasına geçin.
>
> ⬇️ Aşağısı mimari, CI, derleme ve performans gibi teknik ayrıntıları içerir.

## ⚡ Tek satır kurulum

**Windows (NVIDIA / CUDA)** — normal PowerShell açıp aşağıdaki satırı yapıştırın, UAC penceresine **Evet** deyin:

```powershell
irm https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.ps1 | iex
```

**macOS (Apple Silicon / Metal)** — Terminal'e yapıştırın:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/saidsurucu/yargi-pro-gemma-local/main/install.sh)"
```

Kurulum **derleme yapmaz.** Sırasıyla: ön-kontrol → opencode (CLI + masaüstü) → **GitHub'dan hazır binary indirme** → belleğe göre model indirme → MCP yapılandırması → tek-tık kontrol paneli kurulumu. Toplam ~15 dakika (çoğu zaman model indirmedir).

## Gereksinimler

- **Windows:** NVIDIA ekran kartı (RTX 20xx–50xx) + **sürücü ≥ 570.65** (kurulum kontrol eder), ~20 GB boş disk.
- **macOS:** Apple Silicon (M-serisi, Metal), ~20 GB boş disk.

Binary'ler tüm kartları kapsayan tek bir çoklu-mimari (sm_75/86/89/120) derlemedir; **kullanıcı makinesinde CUDA Toolkit / MSVC / derleme gerekmez.**

## Kontrol paneli (sistem tepsisi / menü çubuğu)

Kurulumdan sonra **"Gemma Yargı Pro"** kısayolu oluşur (Windows masaüstü ve Başlat menüsü / macOS Launchpad). Çift tıklayınca köşede küçük bir ikon belirir (Windows'ta görev çubuğu tepsisi, macOS'te menü çubuğu). İkona **sol veya sağ tıklayarak** menüye ulaşırsınız:

| Menü | İşlev |
|---|---|
| **Durum** | 🟢 Sunucu çalışıyor / 🔴 Kapalı (ikon rengi de değişir) |
| **Başlat** | Yerel sunucuyu arka planda başlatır (model yüklenir, ~30–60 sn) |
| **Durdur** | Sunucuyu kapatır |
| **opencode'u Aç** | opencode masaüstü uygulamasını açar |
| **Çıkış** | Sunucuyu durdurur ve paneli kapatır |

**Kullanım akışı:** İkona tıklayın → **Başlat** → ikon yeşile dönünce → **opencode'u Aç**.

### opencode içinde

1. **Yeni proje/sohbet:** sol üstteki **+** işareti veya **Ctrl/Cmd + O**.
2. **Model:** alttaki menüden **Gemma 4 QAT** (`gemma-4-qat`) seçin.
3. **Yargı Pro girişi (MCP):** sağ üstteki **durum** butonu → **MCP** sekmesi → **yargi-mcp-pro** → **giriş yap**. Tarayıcıda **WorkOS OAuth** açılır; giriş yapıp opencode'a dönün (yalnızca ilk sefer).
4. Artık Yargı Pro MCP ile yerel Gemma 4 modelini kullanarak sohbet edebilirsiniz.

## Otomatik model seçimi

Kurulum, belleğe göre modeli otomatik seçer:

| Donanım | Seçilen model |
|---|---|
| NVIDIA VRAM ≥ 16 GB **veya** Mac RAM ≥ 24 GB | **Gemma 4 26B-A4B** QAT UD-Q4_K_XL (~14.2 GB) |
| Bunun altında | **Gemma 4 12B** QAT UD-Q4_K_XL (~6.7 GB) |

> ⚠️ **12B daha yavaş üretir — bu normaldir, arıza değildir.** 12B *dense* (tüm parametreler aktif); 26B ise *MoE* (üretimde yalnızca ~4B parametre aktif) olduğundan 26B hem daha akıllı hem daha hızlıdır (ölçüm: 26B ~72 tok/s, 12B ~32 tok/s). Ayrıca **ilk soru her zaman en yavaşıdır** (soğuk önbellek + uzun bağlam okuması); sonraki sorular hızlanır.

## Performans (ölçülen — RTX 4060 Ti 16 GB / Apple M1 Pro)

| Model | Aktif param | Hız | Bellek | Disk |
|---|---|---|---|---|
| **26B-A4B** (MoE) | ~4B | ~72 tok/s | ~15.9 GB VRAM | 13.3 GiB |
| **12B** (dense) | 12B | ~32 tok/s | ~8.7 GB VRAM | 6.3 GiB |

- Varsayılan bağlam **128K (131072)**, K+V `turbo3`. TurboQuant sayesinde 128K bağlam 16 GB'ye sığar.
- `turbo3` KV macOS/Metal'de de **çalışır** (M1 Pro üzerinde doğrulanmıştır).
- 26B'de VRAM çok dardır (~15.9/16 GB); başka GPU uygulamalarını (LM Studio, ağır tarayıcı sekmeleri vb.) kapatın. 12B'de bol pay vardır, 12 GB'lik kartlara da uygundur.

## Mimari

| Katman | Seçim |
|---|---|
| Arayüz | opencode (CLI + masaüstü) |
| Çıkarım motoru | TheTom/llama-cpp-turboquant — **GitHub Actions'ta CI ile derlenir**, kullanıcı hazır indirir |
| Model | unsloth `gemma-4-{26B-A4B,12B}-it-qat-GGUF : UD-Q4_K_XL` |
| KV cache | `--cache-type-k turbo3 --cache-type-v turbo3` |
| MCP | `yargi-mcp-pro` → https://yargi.betaspacestudio.com/mcp (OAuth) |

**Akış:** GitHub Actions (`.github/workflows/build.yml`) üç işte (Windows CUDA, macOS arm64/x64) binary'leri derleyip `binaries-v1` release'ine yükler. Kullanıcı installer'ı bu release'ten indirir; kontrol paneli sunucuyu yönetir.

## Sorun giderme

- **Kontrol paneli yeşil ama "Durdur" işe yaramıyor (Windows):** Sunucuyu WSL içinde çalıştırmış olabilirsiniz. Windows'ta **PowerShell tek-satır kurulumunu** kullanın (native, GPU'yu kullanır). Panelin "Durdur"u artık WSL'deki sunucuyu da kapatır.
- **Cevap boş geliyor / yalnızca düşünüyor:** Gemma 4'ün "thinking" modu açıktır; önce akıl yürütür, sonra cevabı yazar. İlk istek uzun sürebilir, sabırla bekleyin.
- **VRAM dolu / model yüklenmiyor:** GPU kullanan diğer uygulamaları kapatın. Hâlâ sığmazsa `.\scripts\start-server.ps1 -Context 32768` veya `-Ngl 90` deneyin.
- **macOS'te "killed" / binary açılmıyor:** Kurulum bunu otomatik halleder (karantina temizliği + ad-hoc imza + `@loader_path` rpath). Sorun sürerse kurulumu tekrar çalıştırın.
- **MCP OAuth takılırsa:** opencode'da tekrar deneyin; gerekirse `~/.local/share/opencode/mcp-auth.json` dosyasını silip yeniden giriş yapın.
- **Sürücü uyarısı (Windows):** NVIDIA sürücünüz 570.65'ten eskiyse güncelleyin (GeForce Experience).

## Geliştirici: kaynaktan derleme (opsiyonel)

Son kullanıcı bunu yapmaz; binary'ler CI'da derlenir. Yalnızca geliştirme için. Gerekir: git, CMake, CUDA Toolkit 12.x + Visual Studio C++ Build Tools (Windows) ya da Xcode CLT (macOS), Node.js.

```powershell
.\scripts\build-turboquant.ps1   # Windows: kaynaktan CUDA derleme (GPU mimarisi otomatik algılanır)
.\scripts\download-model.ps1
.\scripts\start-server.ps1
```

CI binary'lerini yeniden üretmek için GitHub'da **build-binaries** workflow'unu çalıştırın → `binaries-v1` release'i güncellenir.

---

Tasarım ve uygulama planları: `docs/superpowers/specs/` ve `docs/superpowers/plans/`.
