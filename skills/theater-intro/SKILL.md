\---

name: theater-intro
description: Orientation for the Theater workspace — READ FIRST when starting work here. Explains what Theater is, the four sibling repos (theater-sim backend, theater-viz Unity client, theater-docs, theater-devops), how they fit together, the git layout, and where to run each. Use whenever you need to get oriented, understand the architecture, find which repo owns something, or learn how the pieces connect.
---

# Theater — workspace orientation

**Theater** is a large-scale battle-simulation platform: it ingests geospatial
maps, lets users author scenarios, runs deterministic simulations, and plays the
results back in a 3D client. `\\\~/projects/theater` is an **umbrella workspace**,
not a single repository — it holds **four independent git repos** (all under
`github.com/Theater-Dev`) checked out side by side, plus shared data assets.

## The four units

|Dir|What it is|Stack|Run skill|
|-|-|-|-|
|**`theater-sim/`**|The backend \& source of truth — microservices for auth, scenarios, simulation, an admin web UI, and postgres, behind a YARP gateway. Also the simulation engine + CLI runner.|.NET 10, Docker Compose, Blazor Server|**`run-theater-sim`**|
|**`theater-viz/`**|Desktop visualization client — plays back a scenario fetched from the backend on a 3D map.|Unity 6000.3.2f1 (macOS/Windows)|**`run-theater-viz`**|
|**`theater-docs/`**|Knowledge base (architecture, features, workflows, retros).|Obsidian / Markdown|—|
|**`theater-devops/`**|Deployment automation — a tagged-release auto-deployer daemon and one-off data-migration scripts.|Python 3.11+ (uv), systemd|—|

## How they fit together

```
        authors scenarios / runs sims              visualizes a scenario
  user ───────────────────────────▶  theater-sim  ◀───────────────────────  theater-viz
                                      (gateway :8443)   downloads scenario+JWT
                                          │
                                          ▼  deployed by
                                     theater-devops   ──── documented in ───▶  theater-docs
```

* **theater-sim is the hub.** It owns auth (JWT), scenario storage, the
simulation engine, and the admin UI. Everything else points at it.
* **theater-viz** is a pure client: it logs in to the sim backend, downloads a
scenario by id + token (deep link `theaterviz://play?scenarioId=…\\\&token=…` or
`--scenarioId`/`--token`), and renders it. Default backend `https://localhost:8443`.
* **theater-devops** deploys the sim stack (polls GitHub tags → `docker compose`
redeploy) and held the one-time Mongo→Postgres migration (v0.5 → v0.6).
* **theater-docs** is the Obsidian-based knowledge base for all of the above.

## Running things — use the run skills

* **`run-theater-viz`** — launches the prebuilt Unity player
(`open Theater.Viz/build.app`) and documents scenario loading + building from
source. (Its GUI is not auto-driven by design.)

Both live in their unit's `.claude/skills/` and auto-load when you ask to run,
start, build, or screenshot that app.

## Git \& conventions you must know

* **Each subdirectory is its own git repo** with its own remote — there is **no
root repo** (`git` at the workspace root fails). Always `cd` into the right
unit before committing; a change touching sim and viz is **two commits in two
repos**, not one.
* **Shared map asset:** `Stoianka.thrmap` (\~134 MB) lives at the **workspace
root** and is consumed by both sim (bind-mounted into containers at
`../Stoianka.thrmap`) and viz (`Assets/StreamingAssets/Maps/`). Maps are in the
binary `.thrmap` format produced by `Theater.Map.Converter`.
* **Versions are pinned:** .NET 10 SDK for sim, Unity **6000.3.2f1 exactly** for
viz (a mismatched editor force-upgrades the project).
* **Self-signed dev TLS** everywhere locally — clients use `-k` /
`ignoreHTTPSErrors`; the gateway redirects `:8080`→`:8443`.

## When you need more

* Architecture / feature details → `theater-docs/` (open in Obsidian or read the
Markdown directly).
* How to run/build a unit → its `run-\\\*` skill.
* API surface → `https://localhost:8443/swagger/index.html` when the stack is up.

