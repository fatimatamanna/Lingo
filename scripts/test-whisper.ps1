<#
.SYNOPSIS
  Transcribe every recording in test-audio/ with whisper.cpp and compare models.
  bash twin: scripts/test-whisper.sh (same behavior and output).

.DESCRIPTION
  For each file in test-audio/ (e.g. en_1.m4a, hi_2.mp3, zh_1.wav):
    1. converts it to 16 kHz mono 16-bit WAV with ffmpeg (into test-audio/wav/)
    2. picks the language from the filename prefix: en_ -> en, hi_ -> hi, zh_ -> zh
       (anything else -> auto-detect)
    3. runs whisper-cli once per model and times each run (includes model load time)
  Prints a table and saves it to whisper-results.md in the repo root.

  Prerequisites (see README "Testing whisper.cpp"):
    - whisper-cli built in build-whisper/
    - models in backend/models/ (ggml-base.bin, ggml-small.bin)
    - ffmpeg installed

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File scripts\test-whisper.ps1
.EXAMPLE
  .\scripts\test-whisper.ps1 -Models base,small,medium -Threads 8
#>
param(
    [string[]] $Models = @('base', 'small'),
    [int] $Threads = [Math]::Min(8, [Environment]::ProcessorCount),
    [string] $WhisperCli = ''
)

$Root      = Split-Path -Parent $PSScriptRoot
$AudioDir  = Join-Path $Root 'test-audio'
$WavDir    = Join-Path $AudioDir 'wav'
$ModelsDir = Join-Path $Root 'backend/models'
$OutFile   = Join-Path $Root 'whisper-results.md'
$TmpDir    = Join-Path ([IO.Path]::GetTempPath()) 'lingo-whisper-test'

# Show Devanagari / Chinese correctly in the console.
[Console]::OutputEncoding = [Text.Encoding]::UTF8

function Stop-WithError([string] $msg) {
    Write-Host "ERROR: $msg" -ForegroundColor Red
    exit 1
}

# --- Locate tools ------------------------------------------------------------
# Visual Studio builds go to bin/Release/; Make/Ninja builds (macOS/Linux) go to bin/.
if (-not $WhisperCli) {
    $WhisperCli = @('bin/Release/whisper-cli.exe', 'bin/whisper-cli.exe', 'bin/whisper-cli') |
        ForEach-Object { Join-Path (Join-Path $Root 'build-whisper') $_ } |
        Where-Object { Test-Path $_ -PathType Leaf } | Select-Object -First 1
}
if (-not $WhisperCli -or -not (Test-Path $WhisperCli)) {
    Stop-WithError "whisper-cli not found in build-whisper/. Build it first (see README 'Testing whisper.cpp')."
}

$Ffmpeg = (Get-Command ffmpeg -ErrorAction SilentlyContinue).Source
if (-not $Ffmpeg -and $env:LOCALAPPDATA) {
    # winget adds ffmpeg to PATH, but terminals opened before the install don't see it yet.
    $Ffmpeg = Get-ChildItem "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Gyan.FFmpeg*\*\bin\ffmpeg.exe" -ErrorAction SilentlyContinue |
              Select-Object -First 1 -ExpandProperty FullName
}
if (-not $Ffmpeg) { Stop-WithError "ffmpeg not found. Windows: winget install Gyan.FFmpeg / macOS: brew install ffmpeg (then open a new terminal)" }
$Ffprobe = (Get-Command ffprobe -ErrorAction SilentlyContinue).Source
if (-not $Ffprobe) {
    $Ffprobe = @('ffprobe.exe', 'ffprobe') | ForEach-Object { Join-Path (Split-Path $Ffmpeg) $_ } |
               Where-Object { Test-Path $_ } | Select-Object -First 1
}

foreach ($m in $Models) {
    $mp = Join-Path $ModelsDir "ggml-$m.bin"
    if (-not (Test-Path $mp)) { Stop-WithError "Model missing: $mp. Download it with: .\backend\scripts\download-model.ps1 $m" }
}

# Skip dotfiles such as macOS's .DS_Store.
$inputs = @(Get-ChildItem $AudioDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '.*' } | Sort-Object Name)
if ($inputs.Count -eq 0) { Stop-WithError "No recordings in $AudioDir. Add files named like en_1.m4a, hi_1.mp3, zh_1.m4a." }

New-Item -ItemType Directory -Force $WavDir, $TmpDir | Out-Null

# --- Transcribe --------------------------------------------------------------
$rows = @()
foreach ($f in $inputs) {
    $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    $prefix = ($name -split '_')[0].ToLower()
    $lang = switch ($prefix) { 'en' { 'en' } 'hi' { 'hi' } 'zh' { 'zh' } default { 'auto' } }
    if ($lang -eq 'auto') { Write-Host "  note: $($f.Name) has no en_/hi_/zh_ prefix; using language auto-detect" -ForegroundColor Yellow }

    # 1. Convert to 16 kHz, mono, 16-bit PCM WAV (what whisper.cpp expects).
    $wav = Join-Path $WavDir "$name.wav"
    & $Ffmpeg -hide_banner -loglevel error -y -i $f.FullName -ar 16000 -ac 1 -c:a pcm_s16le $wav 2>$null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $wav)) {
        Write-Host "  skipping $($f.Name): ffmpeg could not convert it" -ForegroundColor Yellow
        continue
    }
    $duration = ''
    if ($Ffprobe) {
        $d = & $Ffprobe -v error -show_entries format=duration -of csv=p=0 $wav 2>$null
        if ($d) { $duration = ([double]::Parse($d, [Globalization.CultureInfo]::InvariantCulture)).ToString('0.0', [Globalization.CultureInfo]::InvariantCulture) }
    }

    # 2. Run each model and time it.
    foreach ($m in $Models) {
        Write-Host "Transcribing $($f.Name) with $m ($lang)..."
        $txtBase = Join-Path $TmpDir "$name-$m"
        Remove-Item "$txtBase.txt" -ErrorAction SilentlyContinue
        $elapsed = Measure-Command {
            & $WhisperCli -m (Join-Path $ModelsDir "ggml-$m.bin") -f $wav -l $lang -t $Threads -nt -np -otxt -of $txtBase 2>$null | Out-Null
        }
        $exit = $LASTEXITCODE

        # Read the UTF-8 text file rather than console output, so non-Latin scripts survive.
        $text = ''
        if (Test-Path "$txtBase.txt") {
            $text = ((Get-Content "$txtBase.txt" -Encoding UTF8) -join ' ').Trim() -replace '\s+', ' '
        }
        if ($exit -ne 0) { $text = "(whisper-cli failed, exit code $exit)" }
        elseif (-not $text) { $text = '(no speech detected)' }

        $rows += [pscustomobject]@{
            clip       = $f.Name
            lang       = $lang
            'audio s'  = $duration
            model      = $m
            seconds    = $elapsed.TotalSeconds.ToString('0.0', [Globalization.CultureInfo]::InvariantCulture)
            transcript = $text
        }
    }
}

# --- Report ------------------------------------------------------------------
$rows | Format-Table -Wrap -AutoSize

$cpu = 'unknown'
try { $cpu = (Get-CimInstance Win32_Processor -ErrorAction Stop | Select-Object -First 1).Name.Trim() }
catch { try { $cpu = (& sysctl -n machdep.cpu.brand_string 2>$null) } catch {} }

$md = @(
    '# whisper.cpp test results',
    '',
    "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm'), CPU: $cpu, $Threads threads. 'seconds' includes model load time.",
    '',
    '| clip | lang | audio s | model | seconds | transcript |',
    '|---|---|---|---|---|---|'
)
foreach ($r in $rows) {
    $t = $r.transcript -replace '\|', '\|'
    $md += "| $($r.clip) | $($r.lang) | $($r.'audio s') | $($r.model) | $($r.seconds) | $t |"
}
[IO.File]::WriteAllText($OutFile, ($md -join "`n") + "`n", (New-Object Text.UTF8Encoding $false))
Write-Host "Saved $OutFile" -ForegroundColor Green
