# Masaustu + Start Menu'ye "Yargi Pro" kisayolu (gizli pencere -> launch.ps1).
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$ps   = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$args = "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$root\scripts\launch.ps1`""
$icon = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"
$ws = New-Object -ComObject WScript.Shell
$targets = @([Environment]::GetFolderPath('Desktop'), (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'))
foreach ($dir in $targets) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    $lnk = $ws.CreateShortcut((Join-Path $dir 'Yargi Pro.lnk'))
    $lnk.TargetPath = $ps
    $lnk.Arguments = $args
    $lnk.WorkingDirectory = $root
    if (Test-Path $icon) { $lnk.IconLocation = $icon }
    $lnk.Save()
    Write-Host "kisayol -> $(Join-Path $dir 'Yargi Pro.lnk')" -ForegroundColor Green
}
