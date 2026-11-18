# Build and start the backend, then start the frontend dev server.
# Ctrl+C stops both.  Windows PowerShell equivalent of run.sh.
#
# Usage:  .\run.ps1
$ErrorActionPreference = 'Stop'

$Root     = $PSScriptRoot
$Backend  = Join-Path $Root 'backend'
$Frontend = Join-Path $Root 'frontend'

# --- Backend -----------------------------------------------------------------
# The Visual Studio generator is multi-config, so the exe lands in build\Release\.
cmake -S $Backend -B (Join-Path $Backend 'build')
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
cmake --build (Join-Path $Backend 'build') --config Release --parallel
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

$ServerExe = Join-Path $Backend 'build\Release\lingo_server.exe'
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
