# CI (GitHub Actions windows-latest): TheTom fork'unu CUDA 12.8 multi-arch derler,
# llama-server.exe + ggml DLL'leri + CUDA redist DLL'leri toplayip zip yapar.
# Onkosul: CUDA Toolkit kurulu (Jimver action), CUDA_PATH set.
$ErrorActionPreference = 'Stop'
$repo  = 'https://github.com/TheTom/llama-cpp-turboquant'
$src   = Join-Path $PWD 'tq-src'
$stage = Join-Path $PWD 'tq-win-cuda'

Write-Host "CUDA_PATH=$env:CUDA_PATH"
git clone --depth 1 $repo $src
if ($LASTEXITCODE -ne 0) { throw "clone basarisiz" }

# Ninja generator: nvcc'yi dogrudan kullanir, VS CUDA entegrasyonuna (No CUDA toolset) takilmaz.
# Onkosul: msvc-dev-cmd ile cl.exe ortamda + Ninja PATH'te.
cmake -S $src -B "$src/build" -G Ninja -DCMAKE_BUILD_TYPE=Release -DGGML_CUDA=ON `
  "-DCMAKE_CUDA_ARCHITECTURES=75-real;86-real;89-real;120-real;120-virtual" `
  -DLLAMA_CURL=OFF
if ($LASTEXITCODE -ne 0) { throw "configure basarisiz" }
cmake --build "$src/build" -j
if ($LASTEXITCODE -ne 0) { throw "build basarisiz" }

New-Item -ItemType Directory -Force -Path $stage | Out-Null
# llama-server.exe + build'in urettigi tum DLL'ler (ggml*, llama*). Ninja: bin/ (Release alt-klasor yok).
$bin = "$src/build/bin"
Get-ChildItem $bin -Recurse -Include 'llama-server.exe','*.dll' | Copy-Item -Destination $stage -Force
# CUDA redist DLL'leri (toolkit olmadan calismasi icin sart)
$cudaBin = Join-Path $env:CUDA_PATH 'bin'
foreach ($pat in 'cudart64_*.dll','cublas64_*.dll','cublasLt64_*.dll') {
  Get-ChildItem $cudaBin -Filter $pat -ErrorAction SilentlyContinue | Copy-Item -Destination $stage -Force
}
# VC++ runtime DLL'leri (exe MSVC ile derlenir; temiz makinede yoksa yuklenemez)
foreach ($d in 'vcruntime140.dll','vcruntime140_1.dll','msvcp140.dll','concrt140.dll') {
  $vcSrc = Join-Path $env:SystemRoot "System32\$d"
  if (Test-Path $vcSrc) { Copy-Item $vcSrc -Destination $stage -Force }
}
if (-not (Test-Path (Join-Path $stage 'llama-server.exe'))) { throw "llama-server.exe stage'de yok" }
Write-Host "Paketlenen dosyalar:"; Get-ChildItem $stage | ForEach-Object { Write-Host "  $($_.Name)" }
Compress-Archive -Path "$stage/*" -DestinationPath (Join-Path $PWD 'llama-turboquant-win-cuda.zip') -Force
Write-Host "ZIP -> llama-turboquant-win-cuda.zip"
