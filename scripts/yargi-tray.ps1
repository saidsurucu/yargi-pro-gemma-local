# Gemma Yargi Pro kontrol paneli - Windows sistem tepsisi. Sunucu durum + Baslat/Durdur/Ac/Cikis.
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

function Stop-LlamaServer {
    # Native Windows surecini kapat
    Get-Process llama-server -ErrorAction SilentlyContinue | Stop-Process -Force
    # WSL icinde calisiyorsa onu da kapat (WSL yoksa sessizce gecer)
    Start-Process wsl -ArgumentList '-e','pkill','-f','llama-server' -WindowStyle Hidden -ErrorAction SilentlyContinue
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
$notify.Text = 'Gemma Yargi Pro'
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

# Sol tikta da menu acilsin (sag tik zaten acar): NotifyIcon'un icsel ShowContextMenu'sunu cagir.
$showMenu = $notify.GetType().GetMethod('ShowContextMenu', [System.Reflection.BindingFlags]'Instance,NonPublic')
$notify.Add_MouseClick({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) { $showMenu.Invoke($notify, $null) }
})

$appContext = New-Object System.Windows.Forms.ApplicationContext

$miBaslat.Add_Click({
    if (-not (Test-Server)) {
        Start-Process powershell -WindowStyle Hidden -ArgumentList `
          "-NoProfile -ExecutionPolicy Bypass -File `"$root\scripts\start-server.ps1`""
        $notify.ShowBalloonTip(3000, 'Gemma Yargi Pro', 'Sunucu baslatiliyor (model yuklenirken biraz bekleyin)...', 'Info')
    }
})
$miDurdur.Add_Click({ Stop-LlamaServer })
$miAc.Add_Click({ if (Test-Path $ocExe) { Start-Process $ocExe } else { Start-Process 'opencode' } })
$miCikis.Add_Click({
    Stop-LlamaServer
    $notify.Visible = $false
    $notify.Dispose()
    $appContext.ExitThread()
})

$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 3000
$timer.Add_Tick({
    if (Test-Server) {
        $notify.Icon = $iconGreen; $notify.Text = 'Gemma Yargi Pro: calisiyor'
        $miDurum.Text = 'Durum: Sunucu calisiyor'
    } else {
        $notify.Icon = $iconRed; $notify.Text = 'Gemma Yargi Pro: kapali'
        $miDurum.Text = 'Durum: Kapali'
    }
})
$timer.Start()

[System.Windows.Forms.Application]::Run($appContext)
