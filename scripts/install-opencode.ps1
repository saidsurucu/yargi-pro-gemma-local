# opencode CLI + desktop kurar ve global config'e yerel model provider + Yargi Pro MCP ekler.
$ErrorActionPreference = 'Stop'

# --- 1) opencode CLI (npm global) ---
if (Get-Command opencode -ErrorAction SilentlyContinue) {
    Write-Host "[VAR] opencode CLI" -ForegroundColor Green
} else {
    Write-Host "[KUR] opencode CLI (npm)..." -ForegroundColor Cyan
    & npm.cmd install -g opencode-ai
    if ($LASTEXITCODE -ne 0) { throw "opencode CLI kurulamadi (node/npm gerekli)" }
}

# --- 2) opencode desktop (NSIS installer) ---
$ocVer = 'v1.17.6'
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$dtExe = "$env:LOCALAPPDATA\Programs\@opencode-aidesktop\OpenCode.exe"
if (Test-Path $dtExe) {
    Write-Host "[VAR] opencode desktop" -ForegroundColor Green
} else {
    Write-Host "[KUR] opencode desktop ($arch)..." -ForegroundColor Cyan
    $inst = "$env:TEMP\opencode-desktop-win-$arch.exe"
    curl.exe -L --retry 5 -o "$inst" "https://github.com/anomalyco/opencode/releases/download/$ocVer/opencode-desktop-win-$arch.exe"
    if ($LASTEXITCODE -ne 0) { throw "opencode desktop indirilemedi" }
    Start-Process -FilePath $inst -ArgumentList '/S' -Wait
}

# --- 3) global config'e provider + MCP ekle (mevcut ayari bozmadan merge) ---
Write-Host "[CFG] global opencode config (provider + yargi-mcp-pro)..." -ForegroundColor Cyan
$node = @'
const fs=require("fs"),os=require("os"),path=require("path");
const dir=path.join(os.homedir(),".config","opencode"),file=path.join(dir,"opencode.json");
fs.mkdirSync(dir,{recursive:true});
let cfg={};try{cfg=JSON.parse(fs.readFileSync(file,"utf8"))}catch{}
if(typeof cfg!=="object"||cfg===null||Array.isArray(cfg))cfg={};
if(!cfg["$schema"])cfg["$schema"]="https://opencode.ai/config.json";
if(typeof cfg.provider!=="object"||cfg.provider===null)cfg.provider={};
cfg.provider["llamacpp"]={npm:"@ai-sdk/openai-compatible",name:"llama-server (local)",options:{baseURL:"http://127.0.0.1:8080/v1"},models:{"gemma-4-26b-qat":{name:"Gemma 4 26B QAT (turbo3, local)",limit:{context:131072,output:8192}}}};
if(typeof cfg.mcp!=="object"||cfg.mcp===null)cfg.mcp={};
cfg.mcp["yargi-mcp-pro"]={type:"remote",url:"https://yargi.betaspacestudio.com/mcp"};
fs.writeFileSync(file,JSON.stringify(cfg,null,2)+"\n");
console.log("opencode global config yazildi -> "+file);
'@
if (-not (Get-Command node -ErrorAction SilentlyContinue)) { throw "node bulunamadi" }
$node | node -
if ($LASTEXITCODE -ne 0) { throw "global config yazilamadi" }

Write-Host "opencode CLI + desktop kuruldu ve yapilandirildi." -ForegroundColor Green
