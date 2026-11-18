# Lingo — CSE 3150 Team Project (UConn)

Lingo is a language-learning web app. Users create a profile, pick a language
(English, Hindi, optionally Mandarin) and a scenario (Introductions, Family,
Ordering Food), **speak** their answers, get AI feedback, and review difficult
words as adaptive flashcards.

- **Due:** Thu Dec 10, 2026. Feature freeze: Sun Dec 6.
- **Runs locally only** (`localhost`). Not deployed or hosted anywhere.
- **The C++ backend is the graded part of the course** (CSE 3150: C++ Essentials).
  Prefer clear, idiomatic C++17 that shows course concepts (classes, RAII,
  const-correctness, std::optional, templates, STL algorithms, smart pointers).

## Stack

| Layer | Tech |
|---|---|
| Frontend | React + Vite + Tailwind CSS v4 (`frontend/`) |
| Backend | C++17, CMake, cpp-httplib, nlohmann/json, GoogleTest (`backend/`) |
| Speech-to-text | whisper.cpp (git submodule, runs locally) |
| Audio decoding | dr_wav (bundled inside whisper.cpp) |
| Feedback | An LLM API, with a keyword-matching fallback |
| Storage | JSON files under `backend/data/` |

Not used (cut on purpose): Python, PyTorch, Hugging Face, PortAudio, FFTW, SQLite.

## Repo layout

```
Lingo/
├── backend/
│   ├── CMakeLists.txt
│   ├── include/        # headers
│   ├── src/            # .cpp files; main.cpp = server entry point
│   ├── tests/          # GoogleTest files (auto-globbed)
│   ├── content/        # scenario + vocab JSON
│   ├── data/           # runtime user data (gitignored)
│   ├── models/         # Whisper ggml model files (gitignored)
│   ├── scripts/download-model.sh
│   └── third_party/whisper.cpp   # submodule — never edit
├── frontend/           # Vite React app; dev server proxies /api -> localhost:8080
├── .github/workflows/ci.yml
└── run.sh
```

## How things run

- Backend server listens on `127.0.0.1:8080`; it must be started from `backend/`
  so relative paths (`models/`, `data/`, `content/`) resolve.
- Frontend dev server: `cd frontend && npm run dev` → http://localhost:5173.
  `vite.config.js` proxies `/api` to the backend.
- Tests: `ctest --test-dir backend/build --output-on-failure`.
- Browser records audio with the Web Audio API, encodes WAV (16 kHz mono) in JS,
  and POSTs it. Do NOT use MediaRecorder (webm output that whisper.cpp can't read).
- Load the Whisper model **once at server startup**, never per request.

## Dev environment (Fatima)

- Windows, PowerShell, repo at `C:\Users\fatim\dev\Lingo` (moved out of OneDrive
  on purpose — do not suggest putting it back there).
- Node v26 and npm installed.
- **C++ toolchain not chosen yet**: either Visual Studio Build Tools + CMake on
  Windows, or WSL Ubuntu. Give PowerShell commands unless told otherwise, and
  note when a step (e.g. `run.sh`) needs bash.
- `.gitattributes` forces LF endings on `*.sh` files.

## Team ownership (each person owns features end to end: C++ endpoint + React screen + tests)

| Person | Owns |
|---|---|
| Ria | Profiles (`ProfileStore`), browser recording component, vocabulary storage (`VocabStore`), progress tracker |
| Diya | Shared headers/types (`Types.h`, `AudioClip`), API contract, scenario selection, whisper.cpp `SpeechRecognizer`, LLM `ResponseEvaluator` |
| **Fatima** | Repo/CMake/CI setup, whisper.cpp proof, language & difficulty preferences, backend audio validation, flashcard scheduler + endpoints |
| Meghana | Dialogue session endpoints + practice screen, transcript → dialogue, speech feedback UI |
| Nithya | Scenario/vocab content JSON, transcript + retry UI, flashcard + progress screens, end-to-end testing, demo |

Only change other people's code if asked; otherwise code against their interfaces
(or a small stand-in/mock if theirs isn't ready) and note the assumption.

## API contract

| Endpoint | Owner | Request | Response |
|---|---|---|---|
| `GET /api/health` | Fatima | – | `{ ok: true }` |
| `POST /api/profile` | Ria | `{ name, language, level }` | profile |
| `GET /api/profile/:id` | Ria | – | profile |
| `PUT /api/profile/:id/prefs` | Fatima | `{ language, level }` | updated profile |
| `GET /api/scenarios?lang=&level=` | Diya | – | `[{ id, title, description }]` |
| `POST /api/session` | Meghana | `{ profileId, scenarioId }` | `{ sessionId, prompt }` |
| `POST /api/session/:id/answer` | Meghana | WAV body or `{ text }` | `{ transcript, feedback: { score, grammarNotes, difficultWords }, nextPrompt, done }` |
| `GET /api/flashcards/next?profileId=` | Fatima | – | `{ empty, wordId, word, meaning, example }` |
| `POST /api/flashcards/:wordId/mark` | Fatima | `{ profileId, known }` | `{ ok }` |
| `GET /api/progress?profileId=` | Ria | – | `{ sessions, wordsKnown, wordsPracticing, weakTopics }` |

Valid values: language ∈ `en | hi | zh`, level ∈ `beginner | intermediate`.
Errors return JSON `{ error: "<user-friendly message>" }` with a 4xx status.

## Fatima's tasks and deadlines

1. **Sat Nov 21 — Repo setup.** CMakeLists (FetchContent for httplib/json/gtest,
   `add_subdirectory` whisper.cpp with examples/tests OFF, `lingo_core` static lib
   from `src/*.cpp` minus `main.cpp`, `lingo_server`, `lingo_tests`), `main.cpp`
   with `/api/health`, `tests/test_health.cpp`, Vite+Tailwind frontend with proxy,
   `download-model.sh`, `run.sh`, `.gitignore`, CI workflow. Done when a fresh
   clone runs and the page shows "backend connected".
2. **Sat Nov 21 — whisper.cpp proof.** Build `whisper-cli`, transcribe English and
   Hindi 16 kHz mono WAVs (`-l en`, `-l hi`), compare `base` vs `small` models,
   post results to the team. Fallback if not working by Mon Nov 23: hosted STT API.
3. **Wed Nov 25 — Flashcard scheduler.** `FlashcardScheduler` (Leitner boxes 1–5:
   known → up one box, needs practice → box 1; `next()` = lowest box, then
   least-recently seen, never repeats the card just marked if another exists;
   `toJson`/`fromJson`) + 8 GoogleTest tests.
4. **Wed Nov 25 — Preferences.** `PUT /api/profile/:id/prefs` with `validatePrefs()`
   + 3 tests, and `frontend/src/components/Preferences.jsx`.
5. **Thu Dec 3 — Audio validation.** `AudioValidator`: dr_wav decode from memory,
   downmix to mono, linear resample to 16 kHz, reject < 0.5 s, > 30 s, or RMS
   < 0.01 with friendly messages; returns `AudioClip` for Diya's recognizer.
   `#define DR_WAV_IMPLEMENTATION` in exactly one .cpp. + 5 tests.
6. **Sun Dec 6 — Flashcards wired to vocab.** `FlashcardService` syncs word ids from
   Ria's `VocabStore` into a per-profile deck saved at
   `data/<profileId>/flashcards.json` (guarded by `std::mutex`), and registers the
   two flashcard routes.
7. **Tue Dec 8 — Testing; Thu Dec 10 — demo** (one slide on her modules).

## Current status

- [x] GitHub repo `fatimatamanna/Lingo` created
- [x] whisper.cpp added as a submodule
- [x] `.gitattributes`
- [x] Frontend scaffolded with Vite (React, ESLint), `npm install` done
- [ ] Tailwind installed + `vite.config.js` / `index.css` / `App.jsx` updated
- [ ] Backend files: CMakeLists.txt, main.cpp, placeholder.cpp, test_health.cpp
- [ ] Scripts, `.gitignore`, CI workflow committed
- [ ] C++ toolchain installed and backend builds
- [ ] whisper.cpp proof

## Rules

- Never edit anything under `backend/third_party/`.
- Never commit `backend/models/`, `backend/data/`, `backend/build/`, `.env`,
  `node_modules/`, or `frontend/dist/`.
- The LLM API key lives only in `backend/.env`; never hard-code it or send it to React.
- Work on feature branches named `fatima/<feature>`; merge to `main` via PR.
- Every new C++ class gets GoogleTest tests in `backend/tests/`.
- Keep explanations beginner-friendly: Fatima is a CS student; explain *why* when
  introducing a C++ concept, and give exact commands to run.
- After changing files, tell Fatima what to run to verify (build, test, or browser check).
