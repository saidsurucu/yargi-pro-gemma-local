# TheTom/llama-cpp-turboquant fork'unu klonlar ve CUDA ile derler.
$ErrorActionPreference = 'Stop'

# Makine+user env'ini tazele (CUDA_PATH, CUDA_PATH_V13_x, PATH) - VS CUDA .targets bunlari ister.
foreach ($scope in 'Machine','User') {
    $vars = [System.Environment]::GetEnvironmentVariables($scope)
    foreach ($k in $vars.Keys) { if ($k -ine 'Path') { Set-Item -Path "Env:$k" -Value $vars[$k] -ErrorAction SilentlyContinue } }
}
$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

$root = Split-Path -Parent $PSScriptRoot
$vendor = Join-Path $root 'vendor\llama-cpp-turboquant'
$repo = 'https://github.com/TheTom/llama-cpp-turboquant'

if (-not (Test-Path $vendor)) {
    Write-Host "Klonlaniyor: $repo" -ForegroundColor Cyan
    git clone --depth 1 $repo $vendor
    if ($LASTEXITCODE -ne 0) { throw "git clone basarisiz" }
} else {
    Write-Host "Repo zaten var: $vendor (git pull)" -ForegroundColor Cyan
    git -C $vendor pull --ff-only
    if ($LASTEXITCODE -ne 0) { throw "git pull basarisiz - repo durumunu kontrol edin" }
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
