---
name: test-theater-viz-editor
description: Dev-level verification of theater-viz by driving a LIVE Unity Editor (6000.3.2f1) over MCP — enter Play Mode, read the Console, screenshot the Game/Scene view, and inspect the scene graph against a running scenario. Use to "test the viz in the Editor", "run the viz Editor test pass", verify a viz change actually works in-Editor, or do MCP-driven Unity verification. Complements run-theater-viz (which only launches the standalone player).
---

# Test theater-viz in the Editor (via MCP)

This skill drives a **running Unity Editor** through the **CoplayDev MCP for Unity**
server (`com.coplaydev.unity-mcp`, committed dev tooling) to verify the viz the way a
developer would: play it, watch the Console, look at it, and poke the scene graph.

> **Scope.** This is interactive, exploratory verification against a live Editor —
> NOT a headless CI runner and NOT an authored unit-test suite. For launching the
> standalone *player* and reading `Player.log`, use the **`run-theater-viz`** skill
> instead. The two are complementary: `run-theater-viz` = does the built app come up;
> this skill = does the thing actually behave, observed from inside the Editor.

Validated on **Unity 6000.3.2f1** (2026-06-22). The Coplay server was chosen over
IvanMurzak/Unity-MCP, which gates setup behind an `ai-game.dev` third-party login.

---

## Preflight (do this every time, in order)

The single most important fact: **the MCP server must be running AND registered with
Claude Code BEFORE the Claude Code session starts.** Claude Code only reads MCP config
at startup, so a server added mid-session is invisible until you restart. Get the
Editor + server up first, *then* start (or restart) Claude Code.

1. **Unity Editor open on the project** — `6000.3.2f1`, project `Theater.Viz`, the
   **Editor** (not `build.app`):
   ```bash
   pgrep -fl "Unity.app/Contents/MacOS/Unity" | grep -i theater.viz
   ```
   Expect a `.../6000.3.2f1/Unity.app/.../Unity ... -projectpath .../Theater.Viz` line.
   If absent, the user must open it in Unity Hub. If you only see `build.app`, that's
   the player — wrong process.

2. **MCP for Unity server started.** In Unity: **Window → MCP for Unity** → the status
   panel must show the server **running** and **"Session connected"**. If it says
   *stopped*, click **Start** (first start may take ~a minute to install deps).
   - **Make this automatic:** enable **Advanced → "Auto-start on load"** (EditorPref
     `MCPForUnity.AutoStartOnLoad`) so the server starts whenever the Editor opens — no
     manual Start each session.
   - Note the **port** (default `8080`; this machine uses **`8685`**).

3. **Claude Code sees it connected:**
   ```bash
   claude mcp list | grep -i unity
   ```
   Expect `UnityMCP: http://127.0.0.1:<port>/mcp (HTTP) - ✔ Connected`.
   - **`✘ Failed to connect`** → the server isn't running (do step 2), or the
     registered port is stale. If the port was changed, re-point Claude Code:
     ```bash
     claude mcp remove UnityMCP -s local
     claude mcp add --transport http UnityMCP http://127.0.0.1:<port>/mcp
     ```
   - **Tools not callable / `/mcp` doesn't list UnityMCP** → this session started
     before the server existed. **Restart the Claude Code session** (config persists in
     `~/.claude.json`; the in-Editor server keeps running). Then the `mcp__UnityMCP__*`
     tools load as deferred tools — pull schemas with ToolSearch (`select:mcp__UnityMCP__read_console,...`).

4. **Unfocused-Editor access — flip Interaction Mode = No Throttling for the session.**
   By default a backgrounded/unfocused Editor throttles its update loop, so the bridge
   returns `Unity session not ready ... (ping not answered); please retry`. Setting the
   Editor's **Interaction Mode** to **No Throttling** keeps the tick (and the bridge)
   alive while Unity is in the background — **validated**: with it on, calls succeed at
   `is_focused=false` / `isApplicationActive=false`.
   - **Cost:** No Throttling makes the Editor's main thread never idle ⇒ ≈one CPU core
     pegged continuously **the whole time the Editor is open** (more heat/fan/battery).
     So **don't leave it on** — this skill treats it as **session-scoped**: turn it ON
     at the start of a driving session, **revert to Default when done**.
   - **Enable** (run once at session start, while the Editor is reachable — focused):
     ```csharp
     UnityEditor.EditorPrefs.SetInt("ApplicationIdleTime", 0);
     UnityEditor.EditorPrefs.SetInt("InteractionMode", 1); // PreferencesProvider.InteractionMode: Default=0, NoThrottling=1, MonitorRefreshRate=2, Custom=3
     typeof(UnityEditor.EditorApplication).GetMethod("UpdateInteractionModeSettings",
         System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic)?.Invoke(null, null);
     ```
   - **Revert when done** (idle CPU back to normal):
     ```csharp
     UnityEditor.EditorPrefs.SetInt("InteractionMode", 0); UnityEditor.EditorPrefs.SetInt("ApplicationIdleTime", 4);
     typeof(UnityEditor.EditorApplication).GetMethod("UpdateInteractionModeSettings",
         System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.NonPublic)?.Invoke(null, null);
     ```
   - It's a **persistent EditorPref**, so if a session ends without reverting it stays on
     until you flip it back (Edit → Preferences → General → Interaction Mode → "Default",
     or the revert snippet). Verify the current value any time via
     `EditorPrefs.GetInt("InteractionMode", 0)`.
   - **For Play Mode** (so the *sim keeps advancing* unfocused, not just the bridge),
     also set `UnityEngine.Application.runInBackground = true` (runtime-only, resets each
     play session; no idle-CPU cost).
   - Per-call fallback when No Throttling is off: click the Editor window, then retry.

5. **Confirm readiness** before driving:
   ```
   ReadMcpResource UnityMCP mcpforunity://editor/state
   ```
   Look at `editor.is_focused`, `compilation.is_compiling` (must be false),
   `editor.play_mode.is_playing`, **`editor.play_mode.is_paused` (must be `false`)**,
   and `advice.ready_for_tools`. If `is_compiling` or a domain reload is pending, wait
   and re-read.
   - **CRITICAL — check `is_paused`.** A *paused* Play Mode (`is_paused=true`) keeps the
     editor/bridge responsive and `execute_code` runs fine, so it's easy to miss — but
     **the player loop is frozen**, so nothing time-based advances: the sim doesn't tick,
     animations don't play, **UITK `schedule.Execute(...)` callbacks never fire**, and
     **`UnityWebRequest` coroutines never progress** (so any backend fetch's success/error
     callback never runs). This silently breaks anything deferred. Traps seen in the wild,
     both initially misdiagnosed as real bugs: (1) UITK focus via
     `field.schedule.Execute(() => field.Focus())` (the app's Tab-between-fields handler)
     **never applies while paused** — synchronous `Focus()` works, scheduled doesn't, so
     Tab/Enter nav looks broken; (2) the **Scenario list stuck on "Завантаження…"** forever
     — the `GetScenarioHistories` web request can't complete while the loop is frozen, even
     though the backend itself answers in <0.1 s.

   - **HARD GUARDRAIL — unpause is mandatory, restart is forbidden.** The editor on this
     machine gets paused out from under you mid-session (manual pause, or Console **Error
     Pause** halting on a logged error). Therefore:
     - **Prepend `UnityEditor.EditorApplication.isPaused = false;` to EVERY `execute_code`
       call that drives or reads runtime behavior** (anything that waits on the sim, the
       scheduler, an animation, or a web request). It's a cheap no-op when not paused and
       it eliminates this entire failure class. Treat it as boilerplate, like the
       fully-qualified-names rule.
     - **Before concluding ANYTHING is broken / hung / not-loading, re-read
       `play_mode.is_paused` (or just unpause and retry).** "Deferred thing didn't happen"
       ⇒ suspect pause *first*, every time.
     - **NEVER `manage_editor action=stop` (or stop+replay) to "get unstuck."** Stopping
       throws away all Play-Mode state (login session, loaded scenario, your in-progress
       setup) and does **not** fix a pause — it just forces a slow domain reload and loses
       your context. Unpausing is one instant call; stopping is a destructive detour. If
       you catch yourself reaching for stop/replay as a retry, **stop and unpause instead.**

6. **Backend (only for Recipe 1).** Loading a real scenario needs the theater-sim
   backend reachable and a `scenarioId` + JWT — see the **`run-theater-sim`** and
   **`run-theater-viz`** skills for `POST /api/auth/login` and `GET /api/scenario/histories`.

---

## The four recipes

Run any subset. Recipe 2 (console-clean) is the highest-signal check and pairs with
every other recipe. Each recipe ends with **evidence** (log excerpt / screenshot /
hierarchy), not a vibe.

### Recipe 1 — Scenario load + playback (end-to-end smoke)
**Goal:** a real scenario loads from the backend, visualization plays, sim units spawn.

The viz UI is **UI Toolkit** (see "Driving the UI" below), so you can drive the whole
flow with `execute_code` — **no manual clicks**. Validated 2026-06-22 (loaded a backend
scenario → 5 `T80` `Individual` units spawned). Preconditions: app already running &
authenticated (Play Mode, logged in), backend reachable.

1. **Enter Play Mode** if not already: `manage_editor action=play` (expect a brief
   `ping not answered` during the domain reload — retry). Confirm via
   `mcpforunity://editor/state` → `play_mode.is_playing == true` and
   `Application.isPlaying` (the app's runtime UI only exists in Play Mode).
2. **Open the scenario list** — call the controller directly (most robust):
   `execute_code` → find the `ScenarioListController` MonoBehaviour, invoke its public
   `Show()`. It fetches the list async from the backend.
3. **Pick & load a scenario** — walk the `UIDocument` tree for `scenario-list-item`
   rows (read each row's `scenario-item-name` / `scenario-item-id` `Label`), then
   **dispatch a `ClickEvent`** to the chosen row (rows use `RegisterCallback<ClickEvent>`,
   so a pooled `ClickEvent` with `target` set fires `OnListItemClick` →
   `BackendClient.GetScenarioById` → `ScenarioEditorController.LoadScenario`).
   Confirm: console logs `LoadScenario <name> (<id>): N units, …` and
   `ScenarioEditorController.IsScenarioLoaded == true`.
4. **Visualize + play** — click `btn-tab-visualize` then `btn-viz-play` via the
   **Clickable-reflection technique** (these are `Button`s wired with `.clicked +=`, so a
   raw `ClickEvent` does NOT fire them — see "Driving the UI"). `btn-viz-play.text`
   flips from `Відтворити` (Play) → `Продовжити`/`Пауза` when playback starts.
5. **Confirm units spawned** (they appear on **Play**, not before):
   ```
   execute_code → count MonoBehaviours named "Individual"   # e.g. 5x 'T80 ...'
   ```
   (In the **edit** tab units are `EditableUnit`; the `Individual` sim entities only
   exist during visualization playback.)
6. **Evidence:** `IsScenarioLoaded` true + the `LoadScenario … N units` log + a non-zero
   `Individual` count + a framed screenshot (Recipe 3, `view_target='T80 …'`) + clean
   console (Recipe 2).
7. Stop when done: `manage_editor action=stop`.

> If you have an explicit `scenarioId`/JWT instead of driving the list, you can skip
> steps 2–3 and call `SceneController.Instance.BackendClient.GetScenarioById(id, s => {
> SceneController.Instance.ScenarioEditorController.LoadScenario(s, id, historyId, …);
> SceneController.Instance.Ui.ShowEditor(); }, onErr)` directly via `execute_code`.

### Recipe 2 — Console-clean gate (highest signal)
**Goal:** no errors/exceptions during load + playback.

```
read_console action=get types=["error","warning"] count=50 include_stacktrace=true format=detailed
```
- **PASS:** zero `error` entries. Report the warning count (some are pre-existing,
  e.g. `CS0067 EditableGraphicsText.Cancelled is never used`).
- **FAIL:** any `error`/exception — quote the message + stack trace. A null-ref or
  missing-asset here is a real finding; report it, don't explain it away.
- Tip: `read_console action=clear` right before entering Play Mode to get a clean
  window scoped to the playback run.

### Recipe 3 — Visual screenshot checks
**Goal:** the picture is right.

```
manage_camera action=screenshot capture_source=game_view include_image=true max_resolution=640
```
- `include_image=true` returns an inline PNG you can actually view; it also writes a
  file. `output_folder` **must be project-relative** (inside the Unity project root) —
  an outside/`/tmp` path is rejected. Default is `Assets/Screenshots/`; to avoid
  committing captures, write to a gitignored in-project folder (e.g. `output_folder=Captures`)
  and/or delete the PNG + `.meta` after. You usually don't need the file at all —
  `include_image=true` is enough to see it.
- `capture_source=scene_view` captures the Editor Scene viewport; `batch=orbit` /
  `batch=surround` give multi-angle contact sheets; `view_target=<GO name/id>` frames a
  unit (e.g. `view_target='T80 187003'` for a close-up — confirms the hull/turret model
  and the solid-faction-color tint).
- **UI caveat:** captures are **camera-rendered** (the tool reports e.g.
  `camera: MapViewCamera`/`SceneViewCamera`), so the **UI Toolkit overlay may be absent
  or partial** — don't rely on a screenshot to verify UI. For authoritative UI state,
  read the visual tree with `execute_code` (see "Driving the UI"). Screenshots are for
  the **world** (units, terrain, hull/turret behavior); `execute_code` is for the **UI**.
- **Look for and report:** tank/IFV/infantry silhouettes read distinctly; billboard
  labels (`#N` + type) legible and constant-size; **hull drives in the movement
  direction while the turret independently tracks the engaged enemy and recenters when
  idle**; RL overlay renders. If something's off, the tunables are on the unit prefab
  controllers — `hullCatchUpSeconds` (lower = less drift), `hullTurnSpeed`,
  `traverseSpeed`, label `sizeFactor`, and the `TypeText`/`IdText` anchored offsets.

### Recipe 4 — Scene / object inspection (structural sanity)
**Goal:** the right objects exist and are wired, no screenshots needed.

```
find_gameobjects search_method=by_component search_term=SimulationRunner   # -> id
ReadMcpResource UnityMCP mcpforunity://scene/gameobject/<id>               # path, componentTypes, parent
ReadMcpResource UnityMCP mcpforunity://scene/gameobject/<id>/components    # component detail
find_gameobjects search_method=by_component search_term=SceneController
find_gameobjects search_method=by_component search_term=ArmoredUnitController   # after units spawn
ReadMcpResource UnityMCP mcpforunity://scene/cameras                       # Camera / PhotoCamera / MapViewCamera
```
- **Assert:** `SimulationRunner` present (validated at path `Visualizer/Simulation`);
  unit prefabs instantiated under their parent once playing; controllers attached;
  expected cameras exist.

---

## Driving the UI (UI Toolkit)

The viz UI is **UI Toolkit (UITK)** — a single `UIDocument` named `DarkTacticalPanel`,
**not uGUI**. So `find_gameobjects search_term=Button`/`Canvas` returns **0**, and
camera screenshots miss the overlay. You drive and inspect the UI with **`execute_code`**
(arbitrary C# in the Editor). There is **no pixel-click tool** in Unity MCP; for real
mouse/coordinate clicks, the separate **`computer-use`** MCP (screenshots the OS screen
and clicks) is the option — enable it if you need pixel-level input.

**Inspect** — walk the visual tree (the `Query`/`Q` extensions aren't in scope in
`execute_code`, so recurse `VisualElement.Children()` manually):
```csharp
var docs = UnityEngine.Object.FindObjectsByType<UnityEngine.UIElements.UIDocument>(UnityEngine.FindObjectsSortMode.None);
// recurse doc.rootVisualElement; collect ve.GetType().Name == "Button" (read ve.name, (ve as Button).text), "Label", etc.
```
Validated: this enumerated all 54 buttons of `DarkTacticalPanel` (`btn-new`, `btn-open`
"Сценарії", `btn-tab-visualize`, `btn-viz-play`, …).

**Click — two cases, this distinction matters:**
1. **Elements registered with `RegisterCallback<ClickEvent>`** (e.g. scenario rows
   `scenario-list-item`, the list's Apply/Clear): dispatch a pooled `ClickEvent`:
   ```csharp
   var e = UnityEngine.UIElements.ClickEvent.GetPooled(); e.target = el; el.SendEvent(e);
   ```
2. **`Button` controls wired via `.clicked +=`** (the Clickable manipulator — most
   toolbar/viz buttons): a raw `ClickEvent` does **NOT** fire them. Invoke the
   `Clickable.clicked` backing delegate via reflection:
   ```csharp
   var fld = typeof(UnityEngine.UIElements.Clickable).GetField("clicked",
       System.Reflection.BindingFlags.Instance | System.Reflection.BindingFlags.NonPublic | System.Reflection.BindingFlags.Public);
   (fld.GetValue(button.clickable) as System.Action)?.Invoke();   // fires exactly what a click fires
   ```
**Most robust of all:** call the app's own controller method directly when you know it
(e.g. `ScenarioListController.Show()`), rather than synthesizing UI events.

Find a controller instance:
```csharp
UnityEngine.MonoBehaviour ctrl = null;
foreach (var mb in UnityEngine.Object.FindObjectsByType<UnityEngine.MonoBehaviour>(UnityEngine.FindObjectsInactive.Include, UnityEngine.FindObjectsSortMode.None))
    if (mb.GetType().Name == "DarkTacticalPanelController") { ctrl = mb; break; }   // or "ScenarioListController", etc.
```
Key controllers: `DarkTacticalPanelController` (exposes `BtnTabVisualize`, `BtnVizPlay`,
… as `Button` properties), `ScenarioListController` (`Show()`, rows →
`OnListItemClick`), `ScenarioEditorController` (`IsScenarioLoaded`, `LoadScenario(...)`),
`SceneController.Instance` (`BackendClient`, `Ui`, `ScenarioEditorController`).

---

## Reporting

Report **pass/fail per recipe with the evidence inline**:
- Recipe 1: play_mode state + unit count.
- Recipe 2: error count (quote any errors + stack) + warning count.
- Recipe 3: the screenshot(s) + a written description of what you see.
- Recipe 4: the objects/components found vs expected.
Be honest: if the backend wasn't up and Recipe 1 didn't run, say so.

---

## Tool & resource reference (validated names)

**Tools** (`mcp__UnityMCP__*`; load schemas via ToolSearch before first call):
- `read_console` — `action` get/clear, `types` [error|warning|log|all], `count`,
  `filter_text`, `include_stacktrace`, `format` plain/detailed/json.
- `find_gameobjects` — `search_method` by_name/by_tag/by_layer/**by_component**/by_path/by_id,
  `search_term`. Returns instance IDs (use by_component to find script-only objects).
- `manage_camera` — `action=screenshot`, `capture_source` game_view/scene_view,
  `include_image`, `max_resolution`, `output_folder`, `batch` surround/orbit, `view_target`.
- `manage_editor` — `action` play/pause/stop (+ tag/layer/undo/redo).
- `run_tests` / `get_test_job` — **first** `manage_tools action=activate group=testing`;
  `run_tests` is async → returns `job_id`; poll `get_test_job job_id=... wait_timeout=30`.
  `mode` EditMode/PlayMode; for PlayMode set `init_timeout=120000`.
- `manage_scene`, `manage_gameobject`, `manage_components` — deeper scene reads/edits.
- `manage_tools` — `list_groups` / `activate` / `deactivate` tool groups (core is on by
  default; testing/profiling/scripting_ext/etc. are off).

**Resources** (`ReadMcpResource UnityMCP <uri>`):
- `mcpforunity://editor/state` — readiness: is_focused, is_compiling, play_mode, ready_for_tools.
- `mcpforunity://scene/gameobject/{id}` and `/{id}/components` — object + component detail.
- `mcpforunity://scene/cameras` — cameras in the scene.
- `mcpforunity://instances` — running Unity sessions (set_active_instance if >1 connected).
- `mcpforunity://tests` — test list (first page).
- `mcpforunity://project/info` — Unity version, paths, platform.
- `mcpforunity://custom-tools` — project-specific custom tools (check once per project).

---

## Troubleshooting (all observed on this project)

| Symptom | Cause | Fix |
|---|---|---|
| `UnityMCP` tools not callable; `/mcp` lists only built-ins | Server added after the session started | Ensure server running + registered, then **restart Claude Code** |
| `✘ Failed to connect` in `claude mcp list` | In-Editor server not started, or stale/changed port | Window → MCP for Unity → **Start**; re-register at the right port (see Preflight 3) |
| `Unity session not ready ... (ping not answered)` | Editor backgrounded/unfocused (throttled tick) | **Permanent fix:** set Interaction Mode = No Throttling (Preflight 4). Per-call fallback: focus the Editor, retry |
| `ping not answered` after `action=play` (or any recompile) | Domain reload dropped + must re-establish the bridge | **Unfocused this takes several seconds / a few retries** (vs ~instant when focused) but self-recovers with No-Throttling on — keep retrying `editor/state` until `ready_for_tools=true`; no focus needed |
| Deferred behavior never happens (sim frozen, animations still, UITK `schedule.Execute`/scheduled `Focus()` never fires, Tab/Enter nav looks broken, backend list stuck on "Завантаження…"/web-request callback never fires) | **Play Mode is paused** (`is_paused=true`) — bridge/`execute_code` still work, masking it; web-request & scheduler coroutines are frozen | **Unpause, never restart:** `execute_code` → `UnityEditor.EditorApplication.isPaused = false;`, then re-test. Prepend that line to runtime-driving calls as boilerplate. **Do NOT `manage_editor action=stop`** to retry — it destroys Play-Mode state and doesn't fix pause |
| `run_tests` tool missing/inert | `testing` group disabled by default | `manage_tools action=activate group=testing` |
| Must click **Start** every session | HTTP transport doesn't auto-start by default | Enable **Advanced → Auto-start on load** |
| Screenshots pile up in the project | `manage_camera` writes to `Assets/Screenshots/` | `output_folder` must be project-relative (no `/tmp`); rely on `include_image=true` and delete the PNG + `.meta`, or gitignore a `Captures/` folder |
| Clicked a UI button, nothing happened | It's a UITK `Button` (`.clicked +=` Clickable) — a raw `ClickEvent` doesn't fire it | Invoke `Clickable.clicked` via reflection, or call the controller method (see "Driving the UI") |
| `find_gameobjects` for `Button`/`Canvas` returns 0 | UI is UI Toolkit, not uGUI | Walk the `UIDocument` visual tree via `execute_code` instead |

---

## Viz-driving reference (validated app facts)

Concrete, validated facts for driving the viz's auth + scenario-editing flows via
`execute_code` — element names, controllers, and the app behaviors you'll hit. Useful for
any dev-testing of these areas (verifying a login-screen change, a role-gating fix, a
scenario-editor tweak). The full regimented manual-QA pass that exercises all of this
systematically lives in its own skill — see **`test-theater-viz-qa`**.

**Credentials:** the test accounts live in a local, git-ignored credentials file the user
maintains (one `username : password` per line) — **ask the user for its location** if you
don't already have it; never hard-code the path or the secrets. Typical role mapping:
an `Admin*` account = Admin, `inst*` = Instructor, a generic "Test" account = default
User, `cadet*` = Cadet. Use the **Admin** account for scenario-editing cases.

**Auth screen (UITK element names):** `auth-screen` (container; `resolvedStyle.display`
== `None` ⇒ logged in, `Flex` ⇒ login screen), `input-auth-login` (Username TextField),
`input-auth-password` (Password TextField; `isPasswordField=True`, `maskChar='*'`),
`btn-auth-login` (Log In Button), `auth-error-group` (red error box) + `label-auth-error`.
- **Login:** set the two `.value`s, `btn.SetEnabled(true)`, fire via the Clickable
  reflection (`Clickable.clicked` backing `Action`). Async → check `auth-screen` display
  in a *later* call. On `label-auth-error` containing "SSL" (transient self-signed flake),
  click once more.
- **Logout:** `AuthController.LogOut()` (revokes the refresh token server-side).

**Role gating:** `RolePolicy.Current` (static, may be non-public) exposes bool props
(`CanCreateScenario/CanOpenScenario/CanSeeAssignments/CanPublish/CanQueryByUsername`
[Admin-only]/`CanAddUnit`…). `SceneController.Instance.BackendClient` →
`IsAdmin/IsInstructor/IsCadet/Username`. Gated UI: `btn-new`, `btn-open` ("Scenarios"),
`btn-assignments` (hidden for User), `btn-logout`, `label-username`. Footer:
`coordinates` group with `wgs84` + `mgrs` labels (show "--" without a real cursor — that's
expected; they format WGS84 lat/lon + MGRS from a terrain raycast), and `version-text`.

**Scenario editing** on `SceneController.Instance.ScenarioEditorController`:
`CreateNewScenario()`; `OnAddUnit()` (adds at camera center, default Blue, inherits the
selected unit's side, and selects the new unit); `GetScenarioModel()` → `.Units`
(`.Side/.Type/.Size/.Id/.Position`(DVector2 X/Y doubles)), `.Routes`, `.Name`; private
`_units` (List), `_selectedUnit`, `_currentScenarioId` (**non-null ⇒ pushed**),
`_currentHistoryId`; private `OnSelect(IEditable)`.
- **Change a unit's options** (the realistic path for "change type/side/size"): select the
  unit, then set `SceneController.Instance.Ui.DropdownSideController/DropdownSizeController/
  DropdownUnitTypeController.TypedValue` (parse the enum from each controller's `TypedValue`
  property type). Setting `TypedValue` fires the bound setter `Model.X = v`. Enums:
  `UnitSide{Blue,Red}`, `UnitSize{Single,Squad,Platoon,Company}`,
  `UnitType{M1A1Abrams,Leo1A5,Leo2A4,Leo2A6,T90A,T80,T72,BMP1,BMP2,M2Bradley,Infantry,…}`.
- **Create a route that renders immediately:** build a `RouteModel` (`Id` uint unique,
  `UnitId` uint, `Points` = `DVector2[]` ≥2 pts) and invoke the **private**
  `AddRoute(RouteModel)` overload via reflection. (Interactive map-click drawing isn't
  scriptable via MCP; this is the construction the app itself uses on load.)
- **Push rule:** a scenario auto-pushes to the backend on change **only when it has ≥1
  Blue AND ≥1 Red unit** (and logged in). Single-side scenarios never push.
- **Delete a scenario** (cleanup): `BackendClient.DeleteScenario(historyId, Action onOk,
  Action<(string,long)> onErr)` — note the error arg is a `(string message, long code)`
  ValueTuple, not `Action<string>`. Only works for scenarios **owned by the logged-in
  user**; others 403. Capture the async result into an `EditorPrefs` key and poll it.
- **Scenario list:** `ScenarioListController.Show()` (async) → rows are Labels named
  `scenario-item-name`; click a row by dispatching a pooled `ClickEvent` to the
  `scenario-list-item` ancestor.

**Tab/focus:** the auth Tab handler switches focus via `schedule.Execute(...).StartingIn(0)`
— **deferred to the next tick**. Send the `KeyDownEvent` (Tab) in one call, then read
`panel.focusController.focusedElement` in a **separate** call. (Enter does NOT submit — see
known bugs.)

**Play Mode exits spontaneously on long unattended runs** (observed repeatedly). Recovery:
if a call throws `MissingReferenceException` mentioning `SceneController` or
`Application.isPlaying` is false → `manage_editor action=play`, poll `editor/state` until
`ready_for_tools`, set `Application.runInBackground=true`; the persisted token usually
auto-restores the last account (else re-login), then continue.

**Known app behaviors/bugs in these flows (don't re-debug as test-harness issues):**
- **Enter does not submit the login form** — only Tab is wired on the auth fields; no
  Return/NavigationSubmit handler.
- **"New" crashes when a unit is selected:** `ViewSectorMesh.SetInteractable`
  (`ViewSectorMesh.cs:177`) NREs on a null `meshRenderer` while a unit is selected, so
  `CreateNewScenario` aborts without clearing. Deselect first as a workaround.
- The whole UI is **Ukrainian, not English**; the Log In button is **not greyed when the
  fields are empty**.

---

## Future extensions (out of scope — noted, not built)
- Headless batchmode test runner (explicitly rejected for this project).
- An authored EditMode/PlayMode unit-test suite (`com.unity.test-framework` 1.6.0 is
  installed but there are no test assemblies yet).
- CI integration.

## Setup provenance
- Server: `com.coplaydev.unity-mcp` (MIT), committed to `Theater.Viz/Packages/manifest.json`
  (commit `42461be`). Runs in-Editor over HTTP; port + Claude Code registration are
  machine-local (EditorPrefs + `~/.claude.json`), so a fresh clone must Start the server
  and (if the port differs) re-register Claude Code.
- Design: `docs/superpowers/specs/2026-06-22-test-theater-viz-editor-design.md`.
  Plan: `docs/superpowers/plans/2026-06-22-test-theater-viz-editor.md`.
