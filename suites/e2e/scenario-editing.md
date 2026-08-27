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

## Deleting an element

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
