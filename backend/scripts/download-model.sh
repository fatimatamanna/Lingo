#!/usr/bin/env bash
# Download a whisper.cpp ggml model into backend/models/.
# bash twin of download-model.ps1.
#
# Usage:  bash backend/scripts/download-model.sh [model]   (default: base)
# Examples of model names: tiny, base, small, base.en
set -euo pipefail

MODEL="${1:-base}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(dirname "$SCRIPT_DIR")"
WHISPER_DOWNLOADER="$BACKEND_DIR/third_party/whisper.cpp/models/download-ggml-model.sh"
MODELS_DIR="$BACKEND_DIR/models"

mkdir -p "$MODELS_DIR"

# whisper.cpp's script accepts a target folder as its 2nd argument, so the model
# goes straight into backend/models/ and nothing is written inside the submodule.
bash "$WHISPER_DOWNLOADER" "$MODEL" "$MODELS_DIR"

if [ ! -f "$MODELS_DIR/ggml-$MODEL.bin" ]; then
  echo "Download failed: $MODELS_DIR/ggml-$MODEL.bin was not created." >&2
  exit 1
fi
echo "Model ready: $MODELS_DIR/ggml-$MODEL.bin"
