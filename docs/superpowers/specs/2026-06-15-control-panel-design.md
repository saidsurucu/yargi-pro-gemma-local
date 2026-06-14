# Yargı Pro Kontrol Paneli — Tasarım Dokümanı

**Tarih:** 2026-06-15
**Durum:** Onaylandı (brainstorming → spec)
**İlgili:** [2026-06-14-idiot-proof-distribution-design.md] (launcher'ı bu panel değiştirir)

## Amaç

Son kullanıcının (avukat) yerel sunucuyu **görebileceği ve kontrol edebileceği** küçük bir
tepsi/menü-çubuğu uygulaması. Mevcut "görünmez launcher" başarısız: `.app` sunucuyu arka planda
başlatıp kapanınca süreci öldürüyor (AppleScript `do shell script` tuzağı), kullanıcı sunucunun
çalışıp çalışmadığını göremiyor ve durduramıyor.

## Çözüm fikri

**Kalıcı bir kontrol süreci** (tepsi/menü-çubuğu uygulaması) sunucunun yaşam döngüsünü sahiplenir.
Uygulama açık kaldığı sürece başlattığı sunucu da hayatta kalır → "server ölüyor" sorunu kökten çözülür.

## Ortak davranış (her iki platform)

Köşede küçük ikon. Tıklayınca menü:
- **Durum** (tıklanamaz, otomatik yenilenir): `🟢 Sunucu çalışıyor` / `🔴 Kapalı`. İkon rengi de yansıtır.
- **Başlat** — sunucuyu arka planda (gizli) başlatır (`start-server.ps1`/`.sh`).
- **Durdur** — `llama-server` sürecini kapatır.
- **opencode'u Aç** — opencode desktop'ı açar.
- **Çıkış** — sunucuyu durdurur + paneli kapatır (orphan süreç kalmaz).

Durum **3 saniyede bir** `http://127.0.0.1:8080/v1/models` (veya 8080 TCP) yoklanarak güncellenir.

## Bileşenler

### Windows — `scripts/yargi-tray.ps1`
- `Add-Type` ile `System.Windows.Forms` + `System.Drawing`. `NotifyIcon` + `ContextMenuStrip`.
- İkon: çalışırken yeşil, kapalıyken kırmızı dolu daire (`System.Drawing` ile runtime'da çizilir).
- `System.Windows.Forms.Timer` (3000 ms) → 8080 TCP bağlantı denemesi; ikon + Durum metni + tooltip güncellenir.
- **Başlat:** `Start-Process powershell -WindowStyle Hidden -File start-server.ps1`.
- **Durdur:** `Stop-Process -Name llama-server -Force -ErrorAction SilentlyContinue`.
- **opencode Aç:** `%LOCALAPPDATA%\Programs\@opencode-aidesktop\OpenCode.exe` (yoksa `opencode`).
- **Çıkış:** Durdur + `NotifyIcon.Visible=$false` + `[System.Windows.Forms.Application]::Exit()`.
- Mesaj döngüsü: `[System.Windows.Forms.Application]::Run($appContext)` (süreç ayakta + timer çalışır).
- **Sıfır ek bağımlılık.**
- Gizli başlatma: `.lnk` hedefi `powershell.exe -WindowStyle Hidden -File yargi-tray.ps1`. Tam sıfır
  flaş için install bir `.vbs` sarmalayıcı oluşturur (`WScript.Shell.Run ... ,0`), `.lnk` onu hedefler.

### macOS — `scripts/yargi_tray.py`
- Python **`rumps`** menü-çubuğu kütüphanesi (~60 satır). `rumps.App` alt sınıfı.
- App başlığı 🟢/🔴 + menü: Durum, Başlat, Durdur, opencode Aç (Çıkış rumps'ta yerleşik — override edilip
  önce sunucuyu durdurur).
- `@rumps.timer(3)` → 8080 yoklar, başlık + Durum günceller.
- **Başlat:** `subprocess.Popen(["bash", START_SH], start_new_session=True, stdout=..., stderr=...)`
  (start_new_session → panel kapanmadan da yaşar; panel sahibi olduğu için panel açıkken yaşar).
- **Durdur:** `subprocess.run(["pkill","-f","llama-server"])`.
- **opencode Aç:** `subprocess.run(["open","-a","OpenCode"])`.
- **Bağımlılık:** `brew install python` (yoksa) + `pip3 install rumps`. install adımında kurulur.

### Kurulum entegrasyonu — `scripts/install-launcher.{ps1,sh}` (yeniden yazılır)
- **Win:** `yargi-tray.ps1` repo'da; install-launcher `.vbs` sarmalayıcı + Masaüstü/Start-Menu `.lnk`
  oluşturur (eski `launch.ps1` `.lnk`'i yerine). İkon opencode exe'sinden.
- **Mac:** python3+rumps sağlanır; `yargi_tray.py`'yi başlatan bir launcher kurulur — `osacompile`
  ile `/Applications/Yargı Pro.app` (içinde `do shell script "python3 .../yargi_tray.py &"`) **veya**
  `~/Library/LaunchAgents` login-item. İlk sürüm: `.app` (çift tıkla menü-çubuğu açılır).
- **Silinen/değişen:** `scripts/launch.ps1` (tek-tık başlat-ve-aç) kaldırılır; işlevi panele taşınır.

## Veri akışı
Kullanıcı "Yargı Pro" kısayoluna/uygulamasına tıklar → kontrol paneli (tepsi/menü-çubuğu) açılır →
ikon kırmızı (sunucu kapalı) → **Başlat**'a tıklar → sunucu yüklenir (~30-60 sn) → ikon yeşil →
**opencode'u Aç** → sohbet. İşi bitince **Durdur** veya **Çıkış**.

## Hata yönetimi
- Sunucu başlamazsa (model/binary yok): Durum kırmızı kalır; Başlat bilgi balonu gösterir
  ("Sunucu baslatilamadi - kurulum tamamlandi mi?").
- opencode bulunamazsa: bilgi balonu.
- Panel zaten açıkken tekrar başlatılırsa: tek örnek (Win: mutex; Mac: rumps zaten tek örnek / basit pid kontrolü).

## Bağımlılıklar
- Windows: yok (PowerShell + .NET WinForms yerleşik).
- macOS: `python3` (brew) + `rumps` (pip).

## Kapsam dışı (YAGNI)
- Loglar penceresi, ayarlar, model değiştirme, context ayarı (ileride).
- Otomatik başlangıçta (boot) çalışma — ilk sürümde elle açılır.
- Tray ikonunda canlı tok/s / VRAM göstergesi.

## Riskler ve azaltımlar
| Risk | Azaltım |
|---|---|
| Win `.lnk` `-WindowStyle Hidden` kısa flaş | `.vbs` sarmalayıcı (`,0` gizli) ile sıfır flaş |
| Mac rumps app login-item değil, kapanınca sunucu da kapanır | İlk sürümde kabul: panel açık = sunucu açık (kullanıcı paneli açık tutar). İleride LaunchAgent. |
| Python/rumps kurulum hatası (Mac) | install adımı brew+pip; hata olursa setup `step` yakalar + log |
| Sunucu başlatma süresi (model yükleme) kullanıcıyı şaşırtır | Durum "baslatiliyor..." ara durumu gösterir; yeşile dönünce hazır |
