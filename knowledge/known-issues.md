# Known issues and quirks

Two different things, kept apart on purpose:

- **Quirks** — how the app behaves. Not defects. Knowing them stops you reporting phantom bugs
  and stops you "discovering" them again at the cost of a session.
- **Open defects** — real findings, not yet filed.

Every entry below was paid for with a full test session. Read it instead of re-deriving it.

## Quirks — do NOT report these as defects

**The UI language varies on the same build.** The same installed exe, launched with no language
argument, has come up English (`LOGIN` / `Username` / `Log In`) on some runs and Ukrainian
(`ВХІД` / `Ім'я користувача` / `Увійти`) on others. It is not a build property — most likely a
per-profile setting behind the toolbar gear. Never fail a case over wording; the worker preamble
carries an EN/UK label table.

**Enter does not submit the login form.** Only Tab is wired between fields. Accepted.

**The login error is a raw HTTP/JSON dump** —
`HTTP/1.1 401 Unauthorized, status: 401, url: /auth/login, response: {"message":"Invalid credentials"}`.
Accepted by the project. Transcribe it when a case asks; never raise it as a finding.

**A new unit appears at the CENTRE of the map viewport**, never where you clicked, and it arrives
selected. Leave one there and the next lands exactly on top: two units then look like one. Most
"impossible" editor behaviour is really an invisible stack — a unit that teleports, a route that
sprouts from nowhere, two routes sharing an origin. Drag the top one aside to check.

**A new unit is a COPY of the last selected unit** (side, size, type). Select a red one and the
next is red. But clicking the Unit tool button clears the selection, so "select red → click Unit
→ click map" yields a default blue.

**The Unit tool button is a toggle whose state cannot be read.** Its amber highlight means "last
used tool", not "armed", and never clears — not by clicking it, not by Esc. Do not reason about
it. `Space` places a unit and has none of this ambiguity.

**Routes are drawn FROM the unit and the unit does not move.** Position the unit first, route it
second. While route mode is active the PROPERTIES panel reads "Nothing selected" — that is normal
and does not mean the mode failed to start.

**Dropdown items swallow a cold synthetic click.** Move the cursor onto the item, pause ~1 s,
then click. Without the hover the list stays open and the value silently does not change.

**`New` wipes the current scenario with no confirmation.** Never click it to tidy up.

## A click the app never sees

An instantaneous click — press and release delivered in the same `SendInput` batch — is ignored
by the **map**, though panel buttons accept it. Small map targets like route waypoints then look
completely dead: no selection, no ring, no panel change, nothing in the log.

`winput.ps1` now holds the button ~70 ms between press and release, and waypoint selection
became deterministic: **12 of 12** trials on two different waypoints, measured rather than
eyeballed.

This produced two wrong conclusions before it was found — first that the app had no
single-waypoint selection, then that the gesture was flaky. When a target does not respond,
check what the harness actually delivers before concluding anything about the app.

## Capture

**On v0.19.3+ the login modal and map viewport come back near-black** in computer-use
screenshots. The UI moved from uGUI to UI Toolkit and the map is a RenderTexture inside a
VisualElement, which those tools cannot read back — even though it is perfectly visible on the
monitor. Capture with `PrintWindow(hwnd, hdc, 2)` (`PW_RENDERFULLCONTENT`) to a PNG and read the
file. `winput.ps1 region/shot` is the everyday path and works.

## Open defects — found, not yet filed

*(A defect filed here claiming route waypoints could not be selected has been withdrawn. It was
a harness fault, not an app fault — the press and release were being sent in the same instant,
which the map's hit-testing ignores. See "A click the app never sees" below.)*

**Password reveal ("eye") toggle is sticky.** It resets only on an actual Logout, not on every
render of the login modal. A failed login attempt keeps reveal ON, so a later unrelated login in
the same session starts with the password in plain text. Default masking itself is correct
(verified twice from a clean state). Suspect `AuthPanelController`'s toggle-state lifecycle.
Found run-007, 2026-08-25.

**`!` renders as a bare vertical bar** when a revealed password contains it — no dot, looks like
`l`. `Player.log` shows `Unable to load font face for [LiberationSans SDF] font asset.` at boot,
so a fallback font is probably mis-rendering the glyph. Unknown whether it is purely cosmetic or
whether the submitted credential is affected. Found run-008, 2026-08-25. Note the repo also had
a locally modified `LiberationSans SDF - Fallback.asset` — possibly related.

## Settled — do not re-test as open

**"Log In is not greyed when fields are empty"** — listed as a known defect in older project
docs. **False on the installed build.** The button is genuinely inert: clicking it with empty
fields produces no Player.log line at all, not merely a grey appearance. Verified run-007.

**No user enumeration.** A wrong password and a non-existent username return byte-identical 401
`Invalid credentials`. Verified run-007 and run-008.
