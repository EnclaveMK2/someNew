---
id: TC-AUTH-001
title: Login form displayed with empty fields and a disabled button
target: installed-app
priority: P1
---

## Preconditions
App running (started by the tester), NOT authenticated, sitting on the login screen. DETERMINE
the state yourself: wake it, screenshot, and see. If it is logged in, click Logout first.
Do not launch, close or restart the app.

## Steps
1. Wake the app, guarded screenshot, confirm Theater Viz is frontmost.
2. Observe the login screen. Do NOT click, do NOT type.
3. Crop the login modal with `region` so field contents and the button state are legible.

## Expected result
All four must hold:
1. The login form is displayed.
2. The Logout button is NOT shown.
3. Username and Password fields are empty.
4. The Log in button is disabled.

## How to judge "disabled"
Primary: appearance — a disabled button is visibly dimmed / low-contrast versus an enabled one.
Describe precisely what you see. If genuinely ambiguous, take ONE tiebreaker: click Log in with
the fields still empty and record whether anything happened at all (screen change, error, or a
new Player.log line). State that you used the tiebreaker.

## Verdict
- PASS — all four hold.
- PARTIAL — some hold; name exactly which failed.
- FAIL — form not displayed, fields pre-filled, or a Logout button visible here.
- BLOCKED — app not running.

## Notes
This case SPECIFICALLY tests the button enabled/disabled state — judge it fresh; do not excuse a
wrong state using the preamble known-behaviours list.

The fields must be empty AS FOUND. If they already hold text left over from earlier activity,
that is itself worth reporting: say so in the evidence, then clear them before continuing with
the rest of the run.

## Evidence to record
Form present, literal field contents (or "empty") and whether you had to clear them, Logout
button anywhere, and a precise description of the Log in button appearance.
