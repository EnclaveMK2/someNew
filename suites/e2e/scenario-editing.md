# Scenario editing — worker reference

Read this **in addition to `worker-preamble.md`** when your case builds a scenario: placing
units, setting sides, drawing routes. Everything here is verified against the installed build
v1.1.0-rc.2 and is driven through real cursor and keyboard input.

## Tools

Both live next to `winput.ps1` in `tests/e2e/tools/` and take the app pid.

```bash
T="C:/Work/theater-viz/tests/e2e/tools"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$T/viz-unit.ps1"  -AppPid <pid> [-Via hotkey|button] [-MoveTo "x,y"] [-Shot out.png]
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$T/viz-route.ps1" -AppPid <pid> -Points "x,y;x,y;..." [-Via hotkey|button] [-UnitAt "x,y"] [-Shot out.png]
```

`-Via hotkey` (default) uses `Space` / `R`. `-Via button` clicks the Unit tool / Create Route.
**A case that tests the buttons must pass `-Via button`** — the default proves only the
hotkeys work.

`viz-unit.ps1` exits non-zero if no unit appeared, so a failed placement stops the case
instead of silently continuing against an empty map.

## The order that works

**Position the unit, then route it.** Never the other way round.

```bash
viz-unit.ps1  -AppPid $PID -MoveTo "700,300"
viz-route.ps1 -AppPid $PID -Points "820,230;950,300;1080,240"
```

## Rules you cannot see on screen

- **A new unit always appears at the CENTRE of the map viewport** (~`1165,535` in a
  1920x1080 window), never where you clicked. It arrives selected.
- **Units stack invisibly.** Leave one at the centre and the next lands exactly on top of it;
  two units then look like one. If something impossible seems to happen — a unit teleports,
  a route sprouts from the wrong place, two routes share one origin — suspect a stack first.
  Confirm by dragging the top one aside.
- **The route is drawn FROM the unit and the unit does not move.** Every click adds a
  waypoint; the double-click adds the last one and ends the route.
- **While route mode is active the PROPERTIES panel reads "Nothing selected".** This is not a
  failure and not a lost selection — keep clicking your points.
- **A new unit is a COPY of the last selected unit** (side, size, type). To place a red one,
  select a red one first. But clicking the Unit tool button CLEARS the selection, so
  "select red -> click Unit -> click map" yields a default blue.
- **The Unit tool button is a toggle whose state cannot be read.** Its amber highlight means
  "last used tool", not "armed", and never clears — not by clicking it, not by Esc. Do not
  reason about it; `viz-unit.ps1 -Via button` detects the miss and retries.
- **`New` wipes the scenario silently**, no confirmation. Never click it to tidy up.

## Placing a unit at an exact coordinate

```bash
viz-move.ps1 -AppPid <pid> -Mgrs "36U UA 03889 93291" [-UnitAt "x,y"] [-Verify out.png]
```

The PROPERTIES panel's **MGRS field is editable**, and typing into it is the only precise way to
place a unit: at typical zoom one pixel is ~1.3 m, so dragging cannot land on a given 10-digit
grid reference. The unit must be selected first (a freshly placed one already is).

The script cannot read text, so it detects the silent failure — a click that missed the field,
after which the typing goes nowhere — but not wrong digits. Pass `-Verify` and read the crop
when the exact value matters.

## Reading a coordinate back

Two sources, and they do **not** agree:

| Source | Gives |
|---|---|
| PROPERTIES panel, MGRS field (unit selected) | the unit's own stored coordinate — **authoritative** |
| bottom status bar | the coordinate under the CURSOR, wherever the mouse happens to be |

Hovering over a unit reads ~10-15 m off, because the symbol is drawn above its anchor point and
you cannot hover exactly on it. Use the panel to assert where a unit is; use the status bar
(`winput.ps1 move x y`, then crop the bar) to ask what a point on the map is.

## Clicking anything in the left panel: use `pick`, not `click`

UI Toolkit panel controls — **buttons as well as dropdown items** — swallow a synthetic click
that arrives with no preceding mouse-move. The control never enters its hover state, the click
does nothing, and nothing anywhere reports a failure. It looks exactly like a dead button.

```bash
powershell.exe ... -File "$H" pick 204 710       # hover, settle, then click
```

Use `pick` for everything in the left panel. Plain `click` is fine on the map. This is the
single most common way an editor case fails silently.

## Measuring a route: viz-route-nodes.ps1

```bash
viz-route-nodes.ps1 -AppPid <pid> [-Expect 3] [-Shot out.png]
```

Reports the screen coordinates of a route's waypoints, read off the pixels. **Click the route
first** — a selected route is drawn red, and the script keys off that colour; an unselected one
is black and it will say so rather than report nothing found.

This is the only thing here that reports what the app ENDED UP WITH rather than what a script
DID, and it is what turns editor work from guesswork into measurement. Use `-Expect N` in a case
to fail the run when the count is wrong.

Known limits, all of them over-reporting rather than missing waypoints:

- It needs the route **selected** (red).
- It drops blobs sitting on a unit — a unit draws its own pale anchor dot on the route start.
- A **road junction crossed by the route** can still be counted. Roads on this map are pale with
  dark outlines, which is exactly a waypoint's signature, so no colour or shape rule separates
  them cleanly.

Real waypoints are always found and their coordinates are accurate to a pixel; treat a count
higher than you expect as "look at the shot", not as a wrong route.

## Moving a waypoint

Both work, verified by measurement:

```bash
winput.ps1 drag 1100 561 1150 700 25                       # drag and drop
viz-move.ps1 -AppPid <pid> -Mgrs "36U UA 03700 93400"      # exact, waypoint selected first
```

Dragging moved a waypoint from `1100,561` to exactly `1150,701` with the other three untouched.
It does **not** change which element is selected.

A selected waypoint has its own MGRS field in the COORDINATES section, at the same panel
position as a unit's — so `viz-move.ps1` works on a waypoint unchanged. Note the app stores a
value one metre off what you type (`03700` came back as `03699`); harmless, but do not assert on
an exact echo.

## What is selected right now: viz-selected.ps1

```bash
viz-selected.ps1 -AppPid <pid>                    # prints: nothing | unit | route | waypoint
viz-selected.ps1 -AppPid <pid> -Expect waypoint   # exits non-zero on any other state
viz-selected.ps1 -AppPid <pid> -Counts            # also prints the raw pixel counts
```

**Check this before every `Delete`.** The same keystroke removes a unit, a whole route, or one
waypoint depending only on this, and the map alone does not show you which — a selected route
and a selected waypoint look nearly identical.

It reads the panel, not the map: the type word (`UNIT` is 4 letters, `ROUTE` is 5) plus whether
a COORDINATES section is present (a route has none). Measured on v1.1.0-rc.2 at 1920x1080:
nothing 187/0, unit 27/784, route 40/368, waypoint 40/734. Re-measure with `-Counts` if the
panel layout ever changes.

It also catches the miss that looks like success: **a click that misses leaves the previous
selection intact.** Route lines are thin — clicking a segment at `1000,480` missed while
`1000,481` hit, one pixel away, and the panel still showed the unit selected from before.

## Selecting one waypoint of a route

Click it. `winput.ps1 click <x> <y>` — 12 of 12 in trials, on two different waypoints.

**How to tell it worked:** the PROPERTIES panel gains a **COORDINATES** section with that
waypoint's own MGRS and altitude. A selected ROUTE has no COORDINATES section, so the presence
of that section is the difference between "the route is selected" and "a waypoint is selected".
The waypoint also gains a thin dark ring, but the panel is the reliable signal — assert on that.

Get exact waypoint coordinates from `viz-route-nodes.ps1` rather than assuming your build points
landed where you asked.

This only works because `click` now holds the button ~70 ms. An instantaneous press-and-release
is ignored by the map entirely — see "A click the app never sees" in `knowledge/known-issues.md`.

## Deleting an element

**`Delete` removes whatever is selected** — a unit, a whole route, or a single waypoint. There
is no separate gesture for any of them, so the only thing that decides the outcome is the
selection. Check it with `viz-selected.ps1 -Expect ...` first; that is the whole reason that
tool exists.

Verified for the hard case: with a waypoint selected, a route went from 4 waypoints to 3, the
deleted one being exactly the selected one and the rest untouched. Afterwards the ROUTE is
selected. Earlier attempts appeared to delete the whole route only because the waypoint was
never actually selected — the click was not reaching the map.

Two ways, both verified. There is **no confirmation** either way — the element goes immediately.

```bash
powershell.exe ... -File "$H" key delete      # hotkey, with the unit selected
powershell.exe ... -File "$H" pick 204 710    # the Delete button (panel showing a UNIT)
```

Prefer the hotkey: the button's position moves with the panel's contents.

The `Delete` key only works if no text field holds keyboard focus — after typing into the MGRS
field, click the unit first. And it only works from a harness that sends it as an **extended
key**; see below.

## A key that "does nothing" may be your own bug

`Delete`, `Insert`, `Home`, `End`, `PageUp`, `PageDown` and the arrows are **extended keys** in
Win32. Sent without `KEYEVENTF_EXTENDEDKEY`, they arrive as their numpad twins and an app
listening for the real key never sees them — the keypress simply has no effect, with nothing to
distinguish it from "this app has no such shortcut".

`winput.ps1` sets the flag for those keys now. It did not always, and that produced a confident,
wrong conclusion recorded here: that deleting had no keyboard shortcut. It does. Before deciding
an app lacks a shortcut, make sure the keystroke is actually reaching it.

## Changing a unit's side

No tool for this yet — it is a dropdown. With the unit selected:

```bash
H="C:/Work/theater-viz/tests/e2e/tools/winput.ps1"
powershell.exe ... -File "$H" pick  204 494    # open Side (Blue y=530, Red y=559)
powershell.exe ... -File "$H" pick  200 559    # pick = hover + click
```

**The hover is required.** A dropdown item swallows a cold synthetic click: the list stays
open and the value does not change. Move the cursor onto the item, pause ~1 s, then click.

Red units render as a diamond, blue as a rectangle — that difference is your cheapest
verification that a side change actually took.

## Verifying

Take a `-Shot` after each unit and route, and actually look at it. Count the units you expect
to see. Most of the ways this goes wrong are invisible in the tool's own output: the tools
report what they did, not what the app ended up with.
