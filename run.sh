#!/usr/bin/env bash
# Build and start the backend, then start the frontend dev server.
# Ctrl+C stops both.  macOS / Linux / Git Bash.  Windows PowerShell twin: run.ps1
#
# Usage:  ./run.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND="$ROOT/backend"
FRONTEND="$ROOT/frontend"

if [ ! -f "$BACKEND/third_party/whisper.cpp/CMakeLists.txt" ]; then
  echo "whisper.cpp submodule is missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

# --- Backend -----------------------------------------------------------------
cmake -S "$BACKEND" -B "$BACKEND/build" -DCMAKE_BUILD_TYPE=Release
cmake --build "$BACKEND/build" --config Release --parallel

# Make/Ninja put the binary in build/; Visual Studio and Xcode put it in build/Release/.
SERVER_EXE=""
for candidate in \
    "$BACKEND/build/lingo_server" \
    "$BACKEND/build/Release/lingo_server" \
    "$BACKEND/build/lingo_server.exe" \
    "$BACKEND/build/Release/lingo_server.exe"; do
  if [ -f "$candidate" ]; then SERVER_EXE="$candidate"; break; fi
done
if [ -z "$SERVER_EXE" ]; then
  echo "Built, but couldn't find lingo_server under $BACKEND/build" >&2
  exit 1
fi

cd "$BACKEND"
"$SERVER_EXE" &
SERVER_PID=$!

cleanup() {
  echo "Stopping backend (pid $SERVER_PID)..."
  kill "$SERVER_PID" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# --- Frontend ----------------------------------------------------------------
cd "$FRONTEND"
npm install
npm run dev
