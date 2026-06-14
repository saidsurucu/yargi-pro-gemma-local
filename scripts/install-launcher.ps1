# Yargi Pro kontrol panelini (tepsi) baslatan kisayollar: .vbs (sifir flas) + Masaustu/Start-Menu .lnk.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$icon = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"

# .vbs sarmalayici: powershell'i gizli (,0) calistirir -> konsol flasi olmaz.
# Ic-ice tirnak karmasasi yerine $q degiskeni + VBS-escape (-replace) kullanilir.
$q = [char]34
$inner = "powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ${q}$root\scripts\yargi-tray.ps1${q}"
$innerVbs = $inner -replace '"', '""'
$vbsBody = "CreateObject(${q}WScript.Shell${q}).Run ${q}$innerVbs${q}, 0, False"
$vbs = Join-Path $root 'scripts\yargi-tray.vbs'
Set-Content -Path $vbs -Value $vbsBody -Encoding ASCII

$ws = New-Object -ComObject WScript.Shell
$targets = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))
foreach ($dir in $targets) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $lnk = $ws.CreateShortcut((Join-Path $dir 'Yargi Pro.lnk'))
    $lnk.TargetPath = "$env:SystemRoot\System32\wscript.exe"
    $lnk.Arguments = "${q}$vbs${q}"
    $lnk.WorkingDirectory = $root
    if (Test-Path $icon) { $lnk.IconLocation = $icon }
    $lnk.Save()
    Write-Host "kisayol -> $(Join-Path $dir 'Yargi Pro.lnk')" -ForegroundColor Green
}
