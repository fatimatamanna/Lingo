#!/usr/bin/env bash
# Download a whisper.cpp ggml model into backend/models/.
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

echo "Model ready: $MODELS_DIR/ggml-$MODEL.bin"
