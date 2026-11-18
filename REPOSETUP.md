# Lingo — Repo & Environment Setup (REPOSETUP.md)

Scope of this file: **only** setting up the repository and the development
environment. Do not build app features (profiles, flashcards, audio, Whisper
integration, etc.) — those come later.

Lingo is a CSE 3150 (UConn) team project: a React front end talking to a C++17
backend, run locally on `localhost` (never deployed).

## Machine

- Windows, PowerShell. Repo at `C:\Users\fatim\dev\Lingo` (kept out of OneDrive
  on purpose — never suggest moving it back).
- Node v26 + npm installed. PowerShell execution policy already set to RemoteSigned.
- **C++ toolchain not installed yet.** Help choose and install either
  Visual Studio Build Tools (Desktop development with C++) + CMake, or WSL Ubuntu.
  Give PowerShell commands by default; say clearly when something needs bash.

## Target layout

```
Lingo/
├── .gitattributes          # done: * text=auto, *.sh text eol=lf
├── .gitignore
├── .github/workflows/ci.yml
├── REPOSETUP.md
├── run.sh
├── backend/
│   ├── CMakeLists.txt
│   ├── include/            # (empty for now, keep with .gitkeep)
│   ├── src/main.cpp
│   ├── src/placeholder.cpp # empty, so lingo_core has a source file
│   ├── tests/test_health.cpp
│   ├── scripts/download-model.sh
│   └── third_party/whisper.cpp   # git submodule — done, never edit
└── frontend/               # Vite + React (JS) + ESLint — scaffolded, npm install done
```

## What each setup file must do

- **backend/CMakeLists.txt**: CMake ≥ 3.20, C++17. FetchContent: cpp-httplib
  (`v0.18.1`), nlohmann/json (`v3.11.3` json.tar.xz), GoogleTest (`v1.15.2`,
  `gtest_force_shared_crt ON`). `add_subdirectory(third_party/whisper.cpp)` with
  `WHISPER_BUILD_EXAMPLES` and `WHISPER_BUILD_TESTS` OFF. Static lib `lingo_core`
  from `src/*.cpp` (GLOB CONFIGURE_DEPENDS) excluding `main.cpp`, include dirs
  `include` and `third_party/whisper.cpp/examples`, linking httplib, json, whisper.
  Executables `lingo_server` (main.cpp) and `lingo_tests` (tests/*.cpp +
  `GTest::gtest_main`), `enable_testing()` + `gtest_discover_tests`.
- **backend/src/main.cpp**: cpp-httplib server on `127.0.0.1:8080` with
  `GET /api/health` → `{"ok": true}`.
- **backend/tests/test_health.cpp**: one trivial passing GoogleTest.
- **backend/scripts/download-model.sh**: runs whisper.cpp's
  `models/download-ggml-model.sh` (default `base`) and moves the `.bin` into
  `backend/models/`.
- **run.sh**: configure + build backend, start `./build/lingo_server` from
  `backend/` in the background, then `npm install && npm run dev` in `frontend/`;
  kill the server on exit. Also provide a PowerShell equivalent (`run.ps1`) if the
  Windows toolchain is chosen.
- **.gitignore**: `backend/build/`, `backend/models/`, `backend/data/`,
  `backend/.env`, `frontend/node_modules/`, `frontend/dist/`, `.vscode/`, `.DS_Store`.
- **.github/workflows/ci.yml**: on push/PR, ubuntu-latest, checkout with
  submodules, build backend, run `ctest --output-on-failure`, Node 20,
  `npm ci && npm run build` in `frontend/`.
- **Frontend**: install `tailwindcss @tailwindcss/vite`; `vite.config.js` adds the
  Tailwind plugin and proxies `/api` → `http://localhost:8080`;
  `src/index.css` is just `@import "tailwindcss";`; `src/App.jsx` fetches
  `/api/health` and shows "backend connected" / "backend not running" under a
  "Lingo" heading. Remove the unused `App.css`.

## Setup is done when

1. `cmake -S backend -B backend/build` and `cmake --build backend/build` succeed.
2. `ctest --test-dir backend/build --output-on-failure` passes.
3. With the server running, `npm run dev` in `frontend/` shows
   **"backend connected"** at http://localhost:5173.
4. Everything is committed and pushed; CI is green on GitHub.
5. whisper.cpp's own `whisper-cli` can transcribe `samples/jfk.wav` with the
   `base` model (proves the speech engine builds on this machine).

## Rules

- Never edit anything under `backend/third_party/`.
- Never commit build output, model files, `.env`, or `node_modules/`.
- Don't commit for me — show what changed and let me review and commit.
- Explain each step briefly (I'm a CS student) and always tell me the exact
  command to run to verify it worked.
