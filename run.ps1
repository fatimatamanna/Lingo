# Build and start the backend, then start the frontend dev server.
# Ctrl+C stops both.  Windows PowerShell (also works in PowerShell 7 on macOS/Linux).
# bash twin: run.sh
#
# Usage:  .\run.ps1
$ErrorActionPreference = 'Stop'

$Root     = $PSScriptRoot
$Backend  = Join-Path $Root 'backend'
$Frontend = Join-Path $Root 'frontend'
$Build    = Join-Path $Backend 'build'

if (-not (Test-Path (Join-Path $Backend 'third_party/whisper.cpp/CMakeLists.txt'))) {
    Write-Host 'whisper.cpp submodule is missing. Run: git submodule update --init --recursive' -ForegroundColor Red
    exit 1
}

# --- Backend -----------------------------------------------------------------
cmake -S $Backend -B $Build -DCMAKE_BUILD_TYPE=Release
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cmake --build $Build --config Release --parallel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

# Visual Studio and Xcode put the binary in build/Release/; Make/Ninja put it in build/.
$ServerExe = @(
    'Release/lingo_server.exe', 'lingo_server.exe',
    'Release/lingo_server',     'lingo_server'
) | ForEach-Object { Join-Path $Build $_ } | Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
if (-not $ServerExe) {
    Write-Host "Built, but couldn't find lingo_server under $Build" -ForegroundColor Red
    exit 1
}

$Server = Start-Process -FilePath $ServerExe -WorkingDirectory $Backend -NoNewWindow -PassThru

# --- Frontend ----------------------------------------------------------------
Push-Location $Frontend
try {
    npm install
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    npm run dev
}
finally {
    # Runs on normal exit, on errors, and on Ctrl+C.
    Pop-Location
    if ($Server -and -not $Server.HasExited) {
        Write-Host "Stopping backend (pid $($Server.Id))..."
        Stop-Process -Id $Server.Id -Force -ErrorAction SilentlyContinue
    }
}
