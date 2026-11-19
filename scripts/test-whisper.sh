#!/usr/bin/env bash
# Transcribe every recording in test-audio/ with whisper.cpp and compare models.
# PowerShell twin: scripts/test-whisper.ps1 (same behavior and output).
#
# For each file in test-audio/ (e.g. en_1.m4a, hi_2.mp3, zh_1.wav):
#   1. converts it to 16 kHz mono 16-bit WAV with ffmpeg (into test-audio/wav/)
#   2. picks the language from the filename prefix: en_ -> en, hi_ -> hi, zh_ -> zh
#      (anything else -> auto-detect)
#   3. runs whisper-cli once per model and times each run (includes model load time)
# Prints a table and saves it to whisper-results.md in the repo root.
#
# Usage:  scripts/test-whisper.sh [-m base,small] [-t THREADS] [-w path/to/whisper-cli]
#
# Works with the bash 3.2 that ships with macOS (no bash 4+ features).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIO_DIR="$ROOT/test-audio"
WAV_DIR="$AUDIO_DIR/wav"
MODELS_DIR="$ROOT/backend/models"
OUT_FILE="$ROOT/whisper-results.md"

ncpu="$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)"
MODEL_LIST="base,small"
THREADS=$(( ncpu < 8 ? ncpu : 8 ))
WHISPER_CLI=""

while getopts "m:t:w:h" opt; do
  case "$opt" in
    m) MODEL_LIST="$OPTARG" ;;
    t) THREADS="$OPTARG" ;;
    w) WHISPER_CLI="$OPTARG" ;;
    *) sed -n '2,13p' "$0"; exit 1 ;;
  esac
done
IFS=',' read -r -a MODELS <<< "$MODEL_LIST"

die() { printf 'ERROR: %s\n' "$1" >&2; exit 1; }

# --- Locate tools ------------------------------------------------------------
# Make/Ninja builds (macOS/Linux) go to bin/; Visual Studio builds go to bin/Release/.
if [ -z "$WHISPER_CLI" ]; then
  for c in bin/Release/whisper-cli.exe bin/whisper-cli.exe bin/whisper-cli; do
    if [ -f "$ROOT/build-whisper/$c" ]; then WHISPER_CLI="$ROOT/build-whisper/$c"; break; fi
  done
fi
[ -n "$WHISPER_CLI" ] && [ -f "$WHISPER_CLI" ] \
  || die "whisper-cli not found in build-whisper/. Build it first (see README 'Testing whisper.cpp')."

FFMPEG="$(command -v ffmpeg || true)"
if [ -z "$FFMPEG" ] && [ -n "${LOCALAPPDATA:-}" ] && command -v cygpath >/dev/null 2>&1; then
  # Git Bash on Windows: winget's ffmpeg isn't on PATH until a new terminal is opened.
  for c in "$(cygpath -u "$LOCALAPPDATA")"/Microsoft/WinGet/Packages/Gyan.FFmpeg*/*/bin/ffmpeg.exe; do
    if [ -f "$c" ]; then FFMPEG="$c"; break; fi
  done
fi
[ -n "$FFMPEG" ] || die "ffmpeg not found. macOS: brew install ffmpeg / Windows: winget install Gyan.FFmpeg (then open a new terminal)"
FFPROBE="$(command -v ffprobe || true)"
if [ -z "$FFPROBE" ]; then
  for c in "$(dirname "$FFMPEG")/ffprobe" "$(dirname "$FFMPEG")/ffprobe.exe"; do
    if [ -f "$c" ]; then FFPROBE="$c"; break; fi
  done
fi

for m in "${MODELS[@]}"; do
  [ -f "$MODELS_DIR/ggml-$m.bin" ] \
    || die "Model missing: $MODELS_DIR/ggml-$m.bin. Download it with: backend/scripts/download-model.sh $m"
done

# The glob skips dotfiles such as macOS's .DS_Store.
found=0
for f in "$AUDIO_DIR"/*; do [ -f "$f" ] && found=1 && break; done
[ "$found" = 1 ] || die "No recordings in $AUDIO_DIR. Add files named like en_1.m4a, hi_1.mp3, zh_1.m4a."

mkdir -p "$WAV_DIR"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
ROWS="$TMP_DIR/rows.md"
: > "$ROWS"

# --- Transcribe --------------------------------------------------------------
for f in "$AUDIO_DIR"/*; do
  [ -f "$f" ] || continue
  clip="$(basename "$f")"
  name="${clip%.*}"
  prefix="$(printf '%s' "${name%%_*}" | tr '[:upper:]' '[:lower:]')"
  case "$prefix" in
    en|hi|zh) lang="$prefix" ;;
    *) lang="auto"; echo "  note: $clip has no en_/hi_/zh_ prefix; using language auto-detect" ;;
  esac

  # 1. Convert to 16 kHz, mono, 16-bit PCM WAV (what whisper.cpp expects).
  wav="$WAV_DIR/$name.wav"
  if ! "$FFMPEG" -hide_banner -loglevel error -y -i "$f" -ar 16000 -ac 1 -c:a pcm_s16le "$wav" 2>/dev/null \
     || [ ! -f "$wav" ]; then
    echo "  skipping $clip: ffmpeg could not convert it"
    continue
  fi
  duration=""
  if [ -n "$FFPROBE" ]; then
    d="$("$FFPROBE" -v error -show_entries format=duration -of csv=p=0 "$wav" 2>/dev/null | tr -d '\r' || true)"
    [ -n "$d" ] && duration="$(LC_ALL=C printf '%.1f' "$d")"
  fi

  # 2. Run each model and time it (bash's `time` keyword works on bash 3.2).
  for m in "${MODELS[@]}"; do
    echo "Transcribing $clip with $m ($lang)..."
    txt_base="$TMP_DIR/$name-$m"
    rm -f "$txt_base.txt"
    TIMEFORMAT=%R
    set +e
    { time "$WHISPER_CLI" -m "$MODELS_DIR/ggml-$m.bin" -f "$wav" -l "$lang" -t "$THREADS" \
        -nt -np -otxt -of "$txt_base" >/dev/null 2>&1 ; } 2> "$TMP_DIR/time.txt"
    rc=$?
    set -e
    seconds="$(LC_ALL=C printf '%.1f' "$(tail -n 1 "$TMP_DIR/time.txt")")"

    text=""
    if [ -f "$txt_base.txt" ]; then
      text="$(tr -d '\r' < "$txt_base.txt" | tr '\n' ' ' | sed -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ $//')"
    fi
    if [ "$rc" -ne 0 ]; then text="(whisper-cli failed, exit code $rc)"
    elif [ -z "$text" ]; then text="(no speech detected)"; fi

    text="$(printf '%s' "$text" | sed 's/|/\\|/g')"
    printf '| %s | %s | %s | %s | %s | %s |\n' "$clip" "$lang" "$duration" "$m" "$seconds" "$text" >> "$ROWS"
  done
done

# --- Report ------------------------------------------------------------------
cpu="unknown"
if [ "$(uname -s)" = "Darwin" ]; then
  cpu="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown)"
elif [ -r /proc/cpuinfo ]; then
  cpu="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')"
fi

{
  echo '# whisper.cpp test results'
  echo
  echo "Run: $(date '+%Y-%m-%d %H:%M'), CPU: $cpu, $THREADS threads. 'seconds' includes model load time."
  echo
  echo '| clip | lang | audio s | model | seconds | transcript |'
  echo '|---|---|---|---|---|---|'
  cat "$ROWS"
} > "$OUT_FILE"

echo
cat "$OUT_FILE"
echo
echo "Saved $OUT_FILE"
