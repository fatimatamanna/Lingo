# Lingo

CSE 3150 (UConn) team project: a React front end talking to a C++17 backend,
run locally on `localhost`.

- **Frontend:** Vite + React + Tailwind CSS (`frontend/`), dev server on http://localhost:5173
- **Backend:** C++17 + CMake (`backend/`), HTTP server on http://127.0.0.1:8080
- **Libraries:** cpp-httplib, nlohmann/json, GoogleTest (downloaded by CMake),
  whisper.cpp for speech-to-text (git submodule in `backend/third_party/`)

## Setup

> **Don't put the repo in OneDrive or iCloud Drive.** Sync clients lock and re-upload files
> while CMake is writing them (random build failures), upload gigabytes of build output and
> models, and iCloud can evict files to the cloud. On Windows, `Documents` and `Desktop` are
> often inside OneDrive; on macOS, `Desktop` and `Documents` are often synced to iCloud.
> Use a plain folder such as `C:\Users\<you>\dev\` or `~/dev/`.

### Windows (PowerShell)

1. Install the tools (or use the installers from each project's website):

   ```powershell
   winget install Git.Git Kitware.CMake OpenJS.NodeJS.LTS Gyan.FFmpeg
   winget install Microsoft.VisualStudio.2022.BuildTools --override "--wait --passive --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
   ```

   The second line installs Visual Studio Build Tools with "Desktop development with C++"
   (MSVC). Newer Build Tools versions work too. **Open a new terminal afterwards** so the
   tools are on `PATH`.

2. Clone (into a folder outside OneDrive) and download the default Whisper model:

   ```powershell
   cd $HOME\dev
   git clone --recursive https://github.com/fatimatamanna/Lingo.git
   cd Lingo
   .\backend\scripts\download-model.ps1
   ```

3. Start everything:

   ```powershell
   .\run.ps1
   ```

   If PowerShell says running scripts is disabled, run
   `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` once and try again.

### macOS

1. Install the tools:

   ```bash
   xcode-select --install          # Apple Clang, git, make
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
   # Apple Silicon: run the two "Next steps" lines Homebrew prints so `brew` is on PATH
   brew install cmake node ffmpeg
   ```

2. Clone (into a folder outside iCloud Drive) and download the default Whisper model:

   ```bash
   mkdir -p ~/dev && cd ~/dev
   git clone --recursive https://github.com/fatimatamanna/Lingo.git
   cd Lingo
   backend/scripts/download-model.sh
   ```

3. Start everything:

   ```bash
   ./run.sh
   ```

On Apple Silicon, whisper.cpp runs on the GPU through Metal automatically. The configure step
prints `Lingo: whisper.cpp Metal = ON`.

### Both

`run.ps1` / `run.sh` build the backend, start it, then start the frontend; Ctrl+C stops both.
Open http://localhost:5173. It should say **backend connected**.
The first run compiles whisper.cpp and takes a few minutes.

Already cloned without `--recursive`? Run `git submodule update --init --recursive`.

Linux works like macOS: install `build-essential cmake nodejs npm ffmpeg` with your package
manager instead of Homebrew.

## Common commands

These work the same in PowerShell and bash (`--config` / `-C` matter only for Visual Studio
on Windows and are ignored elsewhere):

```bash
# Build the backend
cmake -S backend -B backend/build -DCMAKE_BUILD_TYPE=Release
cmake --build backend/build --config Release --parallel

# Run the backend tests
ctest --test-dir backend/build -C Release --output-on-failure

# Frontend only
cd frontend
npm install
npm run dev
```

Download another Whisper model into `backend/models/` (default `base`):

| Windows (PowerShell) | macOS / Linux |
|---|---|
| `.\backend\scripts\download-model.ps1 small` | `backend/scripts/download-model.sh small` |

## Testing whisper.cpp

`scripts/test-whisper.ps1` (PowerShell) and `scripts/test-whisper.sh` (bash) do the same thing:
transcribe your own recordings with the `base` and `small` models and report how long each took.
Results go to `whisper-results.md`. Build output, recordings, and results are all gitignored.

One-time setup, from the repo root (needs ffmpeg, which the Setup steps above install):

```bash
# 1. Build whisper-cli on its own, outside the submodule (a few minutes)
cmake -S backend/third_party/whisper.cpp -B build-whisper -DCMAKE_BUILD_TYPE=Release -DWHISPER_BUILD_TESTS=OFF
cmake --build build-whisper --config Release --parallel --target whisper-cli
# Windows:       build-whisper\bin\Release\whisper-cli.exe
# macOS / Linux: build-whisper/bin/whisper-cli
```

```powershell
# 2. Download both models — Windows
.\backend\scripts\download-model.ps1 base; .\backend\scripts\download-model.ps1 small
```

```bash
# 2. Download both models — macOS / Linux
backend/scripts/download-model.sh base && backend/scripts/download-model.sh small
```

Then drop recordings (`.m4a`, `.mp3`, `.wav`, ...) into `test-audio/`. The filename prefix sets
the language: `en_` English, `hi_` Hindi, `zh_` Mandarin, anything else auto-detect.
For example, `en_1.m4a` or `hi_greeting.mp3`. Then run:

| Windows (PowerShell) | macOS / Linux |
|---|---|
| `.\scripts\test-whisper.ps1` | `scripts/test-whisper.sh` |
| options: `-Models base,small,medium -Threads 8` | options: `-m base,small,medium -t 8` |

On a Mac the timings include Metal GPU acceleration, so expect them to differ from Windows (CPU only).

## Project layout

```
Lingo/
├── run.sh / run.ps1           # start backend + frontend
├── scripts/test-whisper.{ps1,sh}  # whisper.cpp model comparison on your own recordings
├── .github/workflows/ci.yml   # CI: builds and tests on Linux + macOS on every push
├── backend/
│   ├── CMakeLists.txt
│   ├── include/               # headers
│   ├── src/                   # main.cpp = server; everything else builds into lingo_core
│   ├── tests/                 # GoogleTest tests (tests/*.cpp are picked up automatically)
│   ├── scripts/download-model.{ps1,sh}
│   └── third_party/whisper.cpp   # git submodule
└── frontend/                  # Vite + React app; /api requests are proxied to the backend
```

## Rules

- Don't edit anything under `backend/third_party/`.
- Don't commit build output, model files, `.env`, or `node_modules/` (`.gitignore` already covers these).
- CI must be green before merging.
- Every script comes in a PowerShell (`.ps1`) and a bash (`.sh`) version with the same
  behavior. Change both together. Keep bash scripts compatible with macOS's bash 3.2.
