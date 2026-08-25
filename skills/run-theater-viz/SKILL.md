---
name: run-theater-viz
description: Build and launch the Theater visualization client (theater-viz) — a Unity 6000.3.2f1 desktop app that plays back Theater simulation scenarios. Use to run/start/launch/build the Unity viz app on macOS, or to load a scenario via deep link / CLI args against the theater-sim backend.
---

# Run theater-viz

`theater-viz` is a **Unity 6000.3.2f1** desktop app (macOS/Windows) that loads a
scenario from the theater-sim backend and plays it back frame-by-frame on a map.
A **prebuilt macOS player** is committed at `Theater.Viz/build.app`, so the fast
path is just to launch it — no Unity build needed.

> This skill covers **build + launch** only. The UI is not driven/auto-tested
> (a Unity GUI isn't worth scripting); you launch it and read `Player.log` to
> confirm it came up and what backend it reached. For the backend it talks to,
> see the `run-theater-sim` skill.

Paths below are relative to `theater-viz/`.

## Prerequisites

- **macOS** (this skill is verified on macOS; the prebuilt app is a universal
  Mach-O binary).
- To **build from source**: **Unity 6000.3.2f1** installed via Unity Hub at
  `/Applications/Unity/Hub/Editor/6000.3.2f1` (must match
  `Theater.Viz/ProjectSettings/ProjectVersion.txt` exactly).
- A reachable **theater-sim backend** (default scenario server) if you want to
  load a scenario — see the `run-theater-sim` skill (`https://localhost:8443`).

## Run (agent path) — launch the prebuilt player

```bash
open Theater.Viz/build.app
```

This launches the Unity player (window titled `Theater.Viz`). Confirm it came up
and see what it did via the runtime log:

```bash
tail -n 30 ~/Library/Logs/DefaultCompany/Theater.Viz/Player.log
```

A healthy launch shows `Initialize engine version: 6000.3.2f1`, GPU/Metal init,
and a `LoadScenario ...` line. The log also records the backend auth call — if no
scenario/token is supplied or the server is unreachable you'll see an
`Authentication failed` / `Curl error 28` timeout, which is expected without a
scenario.

Stop it:

```bash
osascript -e 'tell application "Theater.Viz" to quit'
```

### Load a scenario

The app loads a scenario by id + JWT, fetched from the configured scenario server.
Two ways to pass them at launch:

```bash
# deep link (theaterviz:// URL scheme is registered by the app)
open "theaterviz://play?scenarioId=<SCENARIO_ID>&token=<JWT>"

# or direct CLI args
Theater.Viz/build.app/Contents/MacOS/Theater.Viz --scenarioId=<SCENARIO_ID> --token=<JWT>
```

Get a `<JWT>` from the backend (`POST /api/auth/login`) and a `<SCENARIO_ID>`
from `GET /api/scenario/histories` — see the `run-theater-sim` skill.

**Which backend it hits:** the runtime config `viz-config.json`
(`~/Library/Application Support/<company>/Theater.Viz/viz-config.json`) sets
`scriptServerBaseUrl`. The in-repo default (`Assets/StreamingAssets/viz-config.json`)
points at `https://localhost:8443/`; an existing runtime config may point
elsewhere (e.g. a remote server) and overrides it. Edit it to target your stack.

## Build from source

> Not run this session — building Unity takes many minutes and wasn't needed
> (the prebuilt `build.app` is committed). Commands below are the documented path.

GUI: open `Theater.Viz` in Unity 6000.3.2f1, then **File → Build Settings →
macOS → Build**. The project's post-build hook (`MacUrlSchemeMaking.cs`) injects
the `theaterviz://` URL scheme into the app's `Info.plist`.

Headless (built-in batchmode flag — builds the scenes in Build Settings):

```bash
/Applications/Unity/Hub/Editor/6000.3.2f1/Unity.app/Contents/MacOS/Unity \
  -batchmode -quit -nographics \
  -projectPath "$(pwd)/Theater.Viz" \
  -buildOSXUniversalPlayer "$(pwd)/Theater.Viz/Builds/macOS/Theater.Viz.app" \
  -logFile -
```

Package a DMG from a built app:

```bash
./make-dmg.sh Theater.Viz/Builds/macOS/Theater.Viz.app dist Theater.Viz.dmg
```

## Gotchas

- **Editor version must match exactly** — `6000.3.2f1`. Opening in a different
  6000.x triggers a project upgrade you don't want. Check
  `Theater.Viz/ProjectSettings/ProjectVersion.txt`.
- **Don't confuse the player with the Editor.** `open build.app` launches the
  standalone player. If a `.../Unity.app/.../Unity -projectpath .../Theater.Viz`
  process is running, that's the Editor (a dev session) — leave it alone.
- **Self-signed dev backend:** development builds accept the self-signed cert
  via an in-app cert handler; release builds won't.
- **No scenario → app still launches** but idles with no playback and logs a
  backend timeout. That's not a crash.
- **Map data** (`Assets/StreamingAssets/Maps/Stoianka.thrmap`, ~134 MB) is
  required for map rendering; the scenario JSON is downloaded at runtime.

## Troubleshooting

- **`Player.log` shows `Curl error 28` / `Authentication failed`** — the
  configured `scriptServerBaseUrl` is unreachable or no token was supplied. Point
  `viz-config.json` at a running backend and pass `--scenarioId`/`--token`.
- **Window doesn't appear** — confirm the process: `pgrep -f MacOS/Theater.Viz`.
  If absent, the binary may be quarantined; `xattr -r -d com.apple.quarantine
  Theater.Viz/build.app` (also done by `make-dmg.sh`).
- **Deep link does nothing** — the `theaterviz://` scheme is only registered once
  the app has been launched/installed at least once (LaunchServices).
