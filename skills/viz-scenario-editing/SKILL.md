---
name: viz-scenario-editing
description: Build scenarios in the installed Theater Viz desktop app by driving real cursor and keyboard — place units, set sides, draw routes. Use to "add units to the map", "build a route", "set up a scenario with N blue and M red", "test the scenario editor", or when an e2e case needs units and routes on the map. Complements e2e-ui-tests, which runs the written case suite.
---

# Scenario editing in Theater Viz

Everything is driven through **real cursor and keyboard input** — the same path a person takes.
There is no back door into the app, and that is the point: a test that bypasses the UI proves
nothing about the UI.

## Dispatch it, do not drive it yourself

Driving the editor is screenshot-heavy: every placement and every route needs a capture to
verify, and each capture is re-sent with the whole conversation on the next turn. **Send it to
a worker** using `tests/e2e/dispatch-template.md`, and tell the worker to read:

- `tests/e2e/worker-preamble.md` — harness, focus discipline, evidence rules
- `tests/e2e/scenario-editing.md` — the tools, the working order, and the invisible rules

Do not paste either file into the dispatch prompt; the worker reads them off disk. That is the
whole saving. Drive the app inline only for a one-off check of a single action.

## What the worker uses

| Tool | Does |
|---|---|
| `tests/e2e/tools/viz-unit.ps1` | places a unit — `Space`, or the Unit button with `-Via button` |
| `tests/e2e/tools/viz-route.ps1` | draws a route — `R` or Create Route, then mouse clicks |
| `tests/e2e/tools/winput.ps1` | the underlying input harness |

Both take `-Via hotkey|button`, so a case can cover either entry point. A case that is about
the buttons **must** pass `-Via button` — the default exercises only the hotkeys.

## The two things that cause most failures

**Position the unit before routing it.** Routing does not move the unit; it draws from where
the unit already is. `viz-unit.ps1 -MoveTo "x,y"` first, `viz-route.ps1` second.

**Units stack invisibly at the map centre.** Every new unit lands at the viewport centre, so
leaving one there makes the next one land on top and the two look like one. Whenever the app
seems to do something impossible, suspect a stack before believing the app misbehaved.

The rest of the rules — the copy-the-last-selected behaviour, the unreadable Unit toggle, the
panel that blanks during route mode, the dropdown that ignores a cold click — are all in
`scenario-editing.md`. Do not re-derive them by experiment; they cost a full session to find.

## Verifying

The tools report what they *did*, not what the app *ended up with*. Require a screenshot after
each step and an explicit unit count in the worker's report. A run that says "placed 3 units"
without a picture has proven nothing.

## Home of record

These tools live in `github.com/EnclaveMK2/someNew` (`harness/`, `suites/e2e/`). Commit changes
and new tools THERE, never into the product repo. See the `qa-tooling-repo` memory.
