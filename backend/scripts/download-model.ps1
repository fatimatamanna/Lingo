# Download a whisper.cpp ggml model into backend/models/.
# PowerShell twin of download-model.sh.
#
# Usage:  .\backend\scripts\download-model.ps1 [model]   (default: base)
# Examples of model names: tiny, base, small, base.en
param([string] $Model = 'base')
$ErrorActionPreference = 'Stop'

$BackendDir   = Split-Path -Parent $PSScriptRoot
$ModelsDir    = Join-Path $BackendDir 'models'
$WhisperModels = Join-Path $BackendDir 'third_party/whisper.cpp/models'
$Target       = Join-Path $ModelsDir "ggml-$Model.bin"

New-Item -ItemType Directory -Force $ModelsDir | Out-Null

# whisper.cpp's scripts accept a target folder as their 2nd argument, so the model
# goes straight into backend/models/ and nothing is written inside the submodule.
if ($env:OS -eq 'Windows_NT') {
    & (Join-Path $WhisperModels 'download-ggml-model.cmd') $Model $ModelsDir
} else {
    bash (Join-Path $WhisperModels 'download-ggml-model.sh') $Model $ModelsDir
}

# The .cmd script reports success even when the download fails, so check the file.
if (-not (Test-Path $Target)) {
    Write-Host "Download failed: $Target was not created." -ForegroundColor Red
    exit 1
}
Write-Host "Model ready: $Target"
