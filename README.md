# Lingo

CSE 3150 (UConn) team project: a React front end talking to a C++17 backend,
run locally on `localhost`.

- **Frontend:** Vite + React + Tailwind CSS (`frontend/`), dev server on http://localhost:5173
- **Backend:** C++17 + CMake (`backend/`), HTTP server on http://127.0.0.1:8080
- **Libraries:** cpp-httplib, nlohmann/json, GoogleTest (downloaded by CMake),
  whisper.cpp for speech-to-text (git submodule in `backend/third_party/`)

## Prerequisites

- Git, CMake ≥ 3.20, Node.js ≥ 20
- A C++17 compiler:
  - **Windows:** Visual Studio Build Tools with "Desktop development with C++"
  - **macOS:** Xcode Command Line Tools (`xcode-select --install`)
  - **Linux:** `g++` (`sudo apt install build-essential cmake`)

## Getting started

```bash
git clone --recursive https://github.com/fatimatamanna/Lingo.git
cd Lingo
```

Already cloned without `--recursive`? Run `git submodule update --init --recursive`.

Then start everything (builds the backend, starts it, then starts the frontend; Ctrl+C stops both):

| Windows (PowerShell) | macOS / Linux |
|---|---|
| `.\run.ps1` | `./run.sh` |

Open http://localhost:5173. It should say **backend connected**.
The first run compiles whisper.cpp and takes a few minutes.

## Common commands

```bash
# Build the backend
cmake -S backend -B backend/build
cmake --build backend/build

# Run the backend tests
ctest --test-dir backend/build --output-on-failure            # macOS / Linux
ctest --test-dir backend/build -C Debug --output-on-failure   # Windows (Visual Studio needs -C)

# Frontend only
cd frontend
npm install
npm run dev

# Download a Whisper model into backend/models/ (default: base; use Git Bash on Windows)
bash backend/scripts/download-model.sh
```

## Project layout

```
Lingo/
├── run.sh / run.ps1           # start backend + frontend
├── .github/workflows/ci.yml   # CI: builds and tests on every push
├── backend/
│   ├── CMakeLists.txt
│   ├── include/               # headers
│   ├── src/                   # main.cpp = server; everything else builds into lingo_core
│   ├── tests/                 # GoogleTest tests (tests/*.cpp are picked up automatically)
│   ├── scripts/download-model.sh
│   └── third_party/whisper.cpp   # git submodule
└── frontend/                  # Vite + React app; /api requests are proxied to the backend
```

## Rules

- Don't edit anything under `backend/third_party/`.
- Don't commit build output, model files, `.env`, or `node_modules/` (`.gitignore` already covers these).
- CI must be green before merging.
