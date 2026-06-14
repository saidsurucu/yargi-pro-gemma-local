# Yargı Pro Kontrol Paneli Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Yerel sunucuyu görünür kılan ve başlat/durdur/aç kontrolü veren bir tepsi (Windows) / menü-çubuğu (macOS) uygulaması; bozuk "görünmez launcher"ı değiştirir.

**Architecture:** Kalıcı bir kontrol süreci sunucunun yaşam döngüsünü sahiplenir. Windows: PowerShell `NotifyIcon` (sıfır bağımlılık). macOS: Python `rumps` menü-çubuğu. Kurulum scriptleri paneli + kısayolu kurar; eski `launch.ps1` kaldırılır.

**Tech Stack:** PowerShell 5.1 + .NET WinForms/Drawing (Win); Python 3 + rumps (Mac); curl/TCP sağlık yoklaması.

**Bu proje TDD'ye uymaz:** GUI/altyapı. "Test" = PowerShell AST parse + launch-smoke (süreç çökmüyor) + Python `py_compile` + `bash -n`. Görsel doğrulama (tray ikonu, menü) gerçek kullanıcıda.

**Sabitler:** Repo kökü `C:\Users\saids\OneDrive\Belgeler\yargi-pro-gemma-local`. Sunucu portu 8080. opencode exe: `%LOCALAPPDATA%\Programs\@opencode-aidesktop\OpenCode.exe` (Win) / `open -a OpenCode` (Mac).

---

## File Structure

| Dosya | Sorumluluk | Durum |
|---|---|---|
| `scripts/yargi-tray.ps1` | Windows tepsi kontrol paneli (NotifyIcon) | YENİ |
| `scripts/yargi_tray.py` | macOS menü-çubuğu kontrol paneli (rumps) | YENİ |
| `scripts/install-launcher.ps1` | Win: .vbs sarmalayıcı + Masaüstü/Start-Menu .lnk → tray | YENİDEN YAZ |
| `scripts/install-launcher.sh` | Mac: python3+rumps sağla + .app (tray'i başlatır) | YENİDEN YAZ |
| `scripts/launch.ps1` | İşlevi panele taşındı | SİL |

---

### Task 1: yargi-tray.ps1 — Windows tepsi kontrol paneli

**Files:** Create: `scripts/yargi-tray.ps1`

- [ ] **Step 1: Scripti yaz**

`scripts/yargi-tray.ps1` tam içeriği:

```powershell
# Yargi Pro kontrol paneli - Windows sistem tepsisi. Sunucu durum + Baslat/Durdur/Ac/Cikis.
$ErrorActionPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$root  = Split-Path -Parent $PSScriptRoot
$ocExe = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"

function Test-Server {
    $c = New-Object System.Net.Sockets.TcpClient
    try {
        $iar = $c.BeginConnect('127.0.0.1', 8080, $null, $null)
        $ok = $iar.AsyncWaitHandle.WaitOne(400)
        $res = ($ok -and $c.Connected)
        $c.Close()
        return $res
    } catch { return $false }
}

function New-DotIcon([System.Drawing.Color]$color) {
    $bmp = New-Object System.Drawing.Bitmap 16,16
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $brush = New-Object System.Drawing.SolidBrush $color
    $g.FillEllipse($brush, 2, 2, 12, 12)
    $g.Dispose()
    return [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
}

$iconGreen = New-DotIcon ([System.Drawing.Color]::LimeGreen)
$iconRed   = New-DotIcon ([System.Drawing.Color]::Firebrick)

$notify = New-Object System.Windows.Forms.NotifyIcon
$notify.Icon = $iconRed
$notify.Text = 'Yargi Pro'
$notify.Visible = $true

$menu = New-Object System.Windows.Forms.ContextMenuStrip
$miDurum = New-Object System.Windows.Forms.ToolStripMenuItem
$miDurum.Text = 'Durum: kontrol ediliyor...'
$miDurum.Enabled = $false
$miBaslat = New-Object System.Windows.Forms.ToolStripMenuItem; $miBaslat.Text = 'Baslat'
$miDurdur = New-Object System.Windows.Forms.ToolStripMenuItem; $miDurdur.Text = 'Durdur'
$miAc     = New-Object System.Windows.Forms.ToolStripMenuItem; $miAc.Text     = "opencode'u Ac"
$miCikis  = New-Object System.Windows.Forms.ToolStripMenuItem; $miCikis.Text  = 'Cikis'
$sep1 = New-Object System.Windows.Forms.ToolStripSeparator
$sep2 = New-Object System.Windows.Forms.ToolStripSeparator
$menu.Items.AddRange(@($miDurum, $sep1, $miBaslat, $miDurdur, $miAc, $sep2, $miCikis))
$notify.ContextMenuStrip = $menu

$appContext = New-Object System.Windows.Forms.ApplicationContext

$miBaslat.Add_Click({
    if (-not (Test-Server)) {
        Start-Process powershell -WindowStyle Hidden -ArgumentList `
          "-NoProfile -ExecutionPolicy Bypass -File `"$root\scripts\start-server.ps1`""
        $notify.ShowBalloonTip(3000, 'Yargi Pro', 'Sunucu baslatiliyor (model yuklenirken biraz bekleyin)...', 'Info')
    }
})
$miDurdur.Add_Click({ Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force })
$miAc.Add_Click({ if (Test-Path $ocExe) { Start-Process $ocExe } else { Start-Process 'opencode' } })
$miCikis.Add_Click({
    Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
    $notify.Visible = $false
    $notify.Dispose()
    $appContext.ExitThread()
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    if (Test-Server) {
        $notify.Icon = $iconGreen; $notify.Text = 'Yargi Pro: calisiyor'
        $miDurum.Text = 'Durum: Sunucu calisiyor'
    } else {
        $notify.Icon = $iconRed; $notify.Text = 'Yargi Pro: kapali'
        $miDurum.Text = 'Durum: Kapali'
    }
})
$timer.Start()

[System.Windows.Forms.Application]::Run($appContext)
```

- [ ] **Step 2: Parse + ASCII**

Run: `$e=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path scripts\yargi-tray.ps1),[ref]$null,[ref]$e)|Out-Null; "$($e.Count) hata"` ve non-ASCII=0.
Expected: `0 hata`, non-ASCII=0.

- [ ] **Step 3: Launch-smoke (çökmüyor mu)**

Run:
```powershell
$p = Start-Process powershell -WindowStyle Hidden -PassThru -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PWD\scripts\yargi-tray.ps1`""
Start-Sleep -Seconds 5
"alive: $(-not $p.HasExited)"
Stop-Process -Id $p.Id -Force
```
Expected: `alive: True` (mesaj döngüsü çalışıyor, başlangıçta çökmedi). Görev çubuğu tepsisinde kırmızı nokta "Yargi Pro" görünür (kullanıcı görsel olarak doğrular).

- [ ] **Step 4: Commit**

```powershell
git add scripts/yargi-tray.ps1
git commit -m "feat: yargi-tray.ps1 Windows tepsi kontrol paneli"
```

---

### Task 2: yargi_tray.py — macOS menü-çubuğu kontrol paneli

**Files:** Create: `scripts/yargi_tray.py`

- [ ] **Step 1: Scripti yaz**

`scripts/yargi_tray.py` tam içeriği:

```python
#!/usr/bin/env python3
# Yargi Pro kontrol paneli - macOS menu bar (rumps).
import os
import socket
import subprocess
import rumps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
START_SH = os.path.join(ROOT, "scripts", "start-server.sh")


def server_up():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(0.4)
    try:
        s.connect(("127.0.0.1", 8080))
        s.close()
        return True
    except Exception:
        return False


class YargiApp(rumps.App):
    def __init__(self):
        super().__init__("Yargi Pro", title="\U0001F534", quit_button=None)
        self.durum = rumps.MenuItem("Durum: kontrol ediliyor...")
        self.menu = [
            self.durum,
            None,
            rumps.MenuItem("Baslat", callback=self.baslat),
            rumps.MenuItem("Durdur", callback=self.durdur),
            rumps.MenuItem("opencode'u Ac", callback=self.ac),
            None,
            rumps.MenuItem("Cikis", callback=self.cikis),
        ]

    @rumps.timer(3)
    def refresh(self, _):
        up = server_up()
        self.title = "\U0001F7E2" if up else "\U0001F534"
        self.durum.title = "Durum: " + ("Sunucu calisiyor" if up else "Kapali")

    def baslat(self, _):
        if not server_up():
            log = open("/tmp/yargi-server.log", "a")
            subprocess.Popen(["bash", START_SH], start_new_session=True,
                             stdout=log, stderr=subprocess.STDOUT)
            rumps.notification("Yargi Pro", "", "Sunucu baslatiliyor (model yuklenirken bekleyin)...")

    def durdur(self, _):
        subprocess.run(["pkill", "-f", "llama-server"])

    def ac(self, _):
        subprocess.run(["open", "-a", "OpenCode"])

    def cikis(self, _):
        subprocess.run(["pkill", "-f", "llama-server"])
        rumps.quit_application()


if __name__ == "__main__":
    YargiApp().run()
```

- [ ] **Step 2: Syntax doğrulaması**

Run: `python -m py_compile scripts/yargi_tray.py && echo "PY OK"`
Expected: `PY OK`. (rumps Windows'ta import edilmez; `py_compile` import etmeden derler.) LF zaten.

- [ ] **Step 3: Commit**

```bash
git add scripts/yargi_tray.py
git commit -m "feat: yargi_tray.py macOS menu-cubugu kontrol paneli (rumps)"
```

---

### Task 3: install-launcher.ps1 — tepsi paneli kısayolu (Win)

**Files:** Modify: `scripts/install-launcher.ps1` (tam yeniden yaz); Delete: `scripts/launch.ps1`

- [ ] **Step 1: install-launcher.ps1'i yeniden yaz**

`scripts/install-launcher.ps1` tam yeni içeriği:

```powershell
# Yargi Pro kontrol panelini (tepsi) baslatan kisayollar: .vbs (sifir flas) + Masaustu/Start-Menu .lnk.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$icon = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"

# .vbs sarmalayici: powershell'i gizli (,0) calistirir -> konsol flasi olmaz.
$vbs = Join-Path $root 'scripts\yargi-tray.vbs'
$vbsBody = "CreateObject(""WScript.Shell"").Run ""powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File """""$root\scripts\yargi-tray.ps1""""""", 0, False"
Set-Content -Path $vbs -Value $vbsBody -Encoding ASCII

$ws = New-Object -ComObject WScript.Shell
$targets = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))
foreach ($dir in $targets) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $lnk = $ws.CreateShortcut((Join-Path $dir 'Yargi Pro.lnk'))
    $lnk.TargetPath = "$env:SystemRoot\System32\wscript.exe"
    $lnk.Arguments = "`"$vbs`""
    $lnk.WorkingDirectory = $root
    if (Test-Path $icon) { $lnk.IconLocation = $icon }
    $lnk.Save()
    Write-Host "kisayol -> $(Join-Path $dir 'Yargi Pro.lnk')" -ForegroundColor Green
}
```

- [ ] **Step 2: launch.ps1'i sil**

Run: `Remove-Item scripts\launch.ps1 -Force`

- [ ] **Step 3: Parse + ASCII + gerçek çalıştır**

Run: parse-check `install-launcher.ps1` (0 hata, non-ASCII=0), sonra
`powershell -NoProfile -ExecutionPolicy Bypass -File scripts\install-launcher.ps1`
Expected: iki `kisayol -> ...` satırı; `scripts\yargi-tray.vbs` oluşur; masaüstünde `Yargi Pro.lnk`.

- [ ] **Step 4: Commit**

```powershell
git add scripts/install-launcher.ps1
git rm scripts/launch.ps1
git commit -m "feat: install-launcher.ps1 tepsi panelini kurar (.vbs+.lnk); launch.ps1 silindi"
```

---

### Task 4: install-launcher.sh — python+rumps + menü-çubuğu .app (Mac)

**Files:** Modify: `scripts/install-launcher.sh` (tam yeniden yaz)

- [ ] **Step 1: install-launcher.sh'i yeniden yaz**

`scripts/install-launcher.sh` tam yeni içeriği:

```bash
#!/usr/bin/env bash
# macOS: python3+rumps sagla, menu-cubugu panelini (yargi_tray.py) baslatan /Applications app uret.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="/Applications/Yargi Pro.app"

if [ -x /opt/homebrew/bin/brew ]; then eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then eval "$(/usr/local/bin/brew shellenv)"; fi

# python3 + rumps
command -v python3 >/dev/null 2>&1 || brew install python
python3 -c "import rumps" >/dev/null 2>&1 || python3 -m pip install --user rumps

PY="$(command -v python3)"
TMP="$(mktemp).applescript"
cat > "$TMP" <<'APPLESCRIPT'
do shell script "__PY__ __ROOT__/scripts/yargi_tray.py > /tmp/yargi-tray.log 2>&1 &"
APPLESCRIPT
sed -i '' "s|__PY__|$PY|; s|__ROOT__|$ROOT|" "$TMP"

rm -rf "$APP"
osacompile -o "$APP" "$TMP"
rm -f "$TMP"
codesign --force --deep --sign - "$APP" 2>/dev/null || true
echo "Launcher (menu-cubugu paneli) -> $APP"
```

- [ ] **Step 2: Syntax doğrulaması**

Run: `bash -n scripts/install-launcher.sh && echo OK`; sonra `tr -d '\r' < scripts/install-launcher.sh > t && mv t scripts/install-launcher.sh`.
Expected: `OK`. (Gerçek `.app` üretimi + brew/pip Mac'te çalışır.)

- [ ] **Step 3: Commit**

```bash
git add scripts/install-launcher.sh
git commit -m "feat: install-launcher.sh menu-cubugu panel app (python+rumps)"
```

---

### Task 5: Entegrasyon doğrulama

**Files:** (yok — doğrulama)

- [ ] **Step 1: launch.ps1 referansı kalmadı mı**

Run: `Select-String -Path scripts\*.ps1,scripts\*.sh,install.ps1,install.sh -Pattern 'launch\.ps1' -ErrorAction SilentlyContinue`
Expected: çıktı yok (setup-all `install-launcher`'ı çağırıyor, `launch.ps1`'i değil).

- [ ] **Step 2: setup-all install-launcher'ı çağırıyor mu**

Run: `Select-String -Path scripts\setup-all.ps1,scripts\setup-all.sh -Pattern 'install-launcher'`
Expected: her iki dosyada `install-launcher` satırı var.

- [ ] **Step 3: Windows uçtan uca (kullanıcı)**

"Yargi Pro" kısayoluna çift tıkla → tepside kırmızı nokta → sağ/sol tık menü → **Baslat** → ~30-60 sn sonra yeşil → **opencode'u Ac** → sohbet. **Durdur**/**Cikis** ile kapat.

---

## Self-Review Notları

- **Spec coverage:** Tepsi/menü-çubuğu (T1/T2), 5 menü öğesi + durum yoklama (T1/T2), gizli başlatma .vbs
  (T3), python+rumps + .app (T4), eski launcher kaldırma (T3 launch.ps1 sil), kalıcı süreç = server ölmez
  (T1 ApplicationContext / T2 start_new_session) — hepsi karşılandı.
- **Placeholder:** Yok — tüm script içerikleri tam.
- **Tutarlılık:** Port 8080, opencode exe yolu, `start-server.ps1`/`.sh`, `llama-server` süreç adı,
  "Yargi Pro" isimleri tüm görevlerde aynı. yargi-tray.ps1 ↔ install-launcher.ps1 (.vbs hedefi) tutarlı.
- **Bilinen kısıt:** Win tray görsel doğrulaması (ikon/menü) ve tüm Mac yolu gerçek kullanıcıda doğrulanır;
  plan parse/syntax/smoke ile sınırlı.
