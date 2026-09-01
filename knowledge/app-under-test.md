# The app under test

**Theater** is a realistic military-themed real-time strategy **video game**. Everything in it
is game mechanics: NATO-style symbology, line-of-sight and concealment modelling, real-world
map geography, RL-trained unit AI. There is no operational use. Treat all of it as game QA.

**theater-viz** is the Unity 6 desktop client that visualises scenarios from the backend, and it
is what we test. It is one repo of several:

| Repo | What | Do we test it |
|---|---|---|
| `theater-viz` | Unity desktop client — the visualiser | **yes, this one** |
| `theater-se` | React frontend | no |
| `theater-sim` | .NET services, Blazor admin | no |
| `theater-integra-tests` | integration tests | no |

When the tester says "фронт" or "візуалізатор" they mean **theater-viz**, not the React app.

## Getting it running

**The backend is already running remotely.** Never start a local backend or docker. The client
reads its server from the `THEATERVIZ_SERVER_IP` environment variable at runtime
(`ConfigLoader.Load()`).

Two ways to get a client:

**Installed build** — what the e2e suite targets:
`C:\Program Files\Theater Viz\Theater.Viz.exe` (override with `THEATER_VIZ_EXE`).

**Local build** from source, Unity 6000.3.2f1:

```powershell
& "C:\Program Files\Unity\Hub\Editor\6000.3.2f1\Editor\Unity.exe" -quit -batchmode `
  -projectPath "C:\Work\theater-viz\Theater.Viz" `
  -executeMethod CIBuild.PerformWindowsBuild `
  -logFile "<scratchpad>\unitybuild.log"
```

Output: `Theater.Viz\Build\Win64\Theater.Viz.exe`. The exit-code notification can fire before the
build finishes — wait until the exe and `Theater.Viz_Data/` exist and the log says
`CIBuild result: Succeeded`. Startup scene `Stoianka_ScenarioEditor`, then `Stoianka`; the map
`Stoianka.thrmap` is in `Assets/StreamingAssets/Maps/`.

Boot takes ~10-15 s. Do not interact before the login modal is on screen.

## Accounts

Four roles exist. **Usernames only here — passwords are never stored in this repo**; they live
in `tests/e2e/credentials.local.txt` (git-ignored). Ask the tester on a new machine.

| Role | Usernames | Sees |
|---|---|---|
| Admin | `AdminTest` | New / Scenarios / Assignments; task panel incl. **Delete** |
| Instructor | `inst`, `inst_2`, `inst_3` | same menus, but **no Delete** — that is admin-only |
| Tester / integration | `IntegraTest` | New / Scenarios only — no task module |
| Cadet | `cadet`, `cadet_2`, `cadet_3` | Assignments only — no builder, no analytics |

## The teaching flow

The roles are not just different permission sets — they are two ends of one workflow:

1. An **instructor** builds a scenario in the editor. It saves itself to the backend as soon as
   it has a unit on each side.
2. The instructor presses **Publish**, which turns that scenario into an **assignment**.
3. A **cadet** logs in and sees that assignment under `Assignments` — the only menu they have.

So Publish is the hand-off between the two accounts. A test that presses it is creating work in
a cadet's account, not just changing local state; treat it as an outward-facing action and only
do it when the case is actually about assignments.

All roles land on the same main window (map + top bar); the role only changes which menus and
task-panel actions appear. theater-viz has no server-management or account-config UI at all —
that lives in the Blazor admin, so the only visible admin-vs-instructor difference is Delete.

## Log as evidence

The player writes to
`C:\Users\<user>\AppData\LocalLow\The A-Team\Theater.Viz\Player.log`.

Grep it for `login succeeded`, `Logout succeeded on backend`, scenario loads and errors. Log
lines are **cheap text evidence** — prefer them to screenshots when they prove the same thing.
A click that produced no log line did nothing, which is how you prove a disabled button is
genuinely inert rather than merely grey.

## House rules

- **Launch the app once per session.** It is not single-instance; launching again stacks another
  copy. The tester once ended up with five.
- **To refocus, wake the existing window** (`winput.ps1 wake <pid>`), never relaunch, and never
  click the map to "wake" it — a stray map click triggers a map reload that looks like a restart.
- **Close the app when a run finishes.** Do not leave stray fullscreen windows and processes
  behind.
- **Verify every field after typing.** A click meant to move between input fields sometimes
  misses, and the text lands in the previous field. Never judge form state (a button
  enabling/disabling) without confirming each field holds what you intended.
- **If a click seems not to register, suspect focus or z-order first**, not an app bug. Another
  window coming to the front — Unity Hub is a repeat offender — silently pushes the app behind,
  and every later click lands on nothing. That looked exactly like a broken Logout button once
  and cost a long detour.
