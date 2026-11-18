#!/usr/bin/env bash
# Build and start the backend, then start the frontend dev server.
# Ctrl+C stops both.  (Linux/macOS/WSL. On Windows PowerShell use run.ps1.)
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Backend -----------------------------------------------------------------
cd "$ROOT/backend"
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release --parallel

./build/lingo_server &
SERVER_PID=$!

cleanup() {
  echo "Stopping backend (pid $SERVER_PID)..."
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- Frontend ----------------------------------------------------------------
cd "$ROOT/frontend"
npm install
npm run dev
