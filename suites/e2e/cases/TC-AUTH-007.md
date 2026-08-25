---
id: TC-AUTH-007
title: Logout returns the user to the login form
target: installed-app
priority: P1
---

## Preconditions
The user is LOGGED IN and sees the map with the Logout button in the upper-right corner.
DETERMINE the state yourself: wake the app and screenshot. If it is NOT logged in, log in first
using the admin account from credentials.local.txt, confirm the map and Logout button are there,
and only then run this case. Never print the password.

## Steps
1. Wake the app, guarded screenshot, confirm the map is shown and Logout is in the upper right.
2. Click Logout once.
3. Wait about 3 s, take a full guarded screenshot.
4. Crop the login modal closely so both field contents are legible.

## Expected result
All four must hold:
1. The user is logged out and returned to the login screen.
2. The login form is displayed with the Username and Password fields EMPTY.
3. The Log in button is present and DISABLED (the fields are empty, so it must not be usable).
4. The Logout button is NOT shown.

## Verdict
- PASS — all four hold.
- PARTIAL — logged out, but something is wrong: a field retains its previous value, the Log in
  button is enabled despite the empty fields, the map is still drawn behind the form, or a
  Logout button is still visible. Name exactly which.
- FAIL — the user is not logged out (map and Logout still shown), or the app errored or froze.
- BLOCKED — app not running, or the user could not be logged in to establish the precondition.

## Notes
Pay particular attention to whether the Username field retains the previous account name. Some
applications keep it deliberately as a convenience; this case requires it EMPTY, so if a value
survives, that is a PARTIAL with the retained value quoted.

Also check the log for anything logged at logout:
/c/Users/nogra/AppData/LocalLow/The A-Team/Theater.Viz/Player.log
An unhandled error there is worth reporting even if the UI looks correct.

## Evidence to record
Whether the login form returned, the literal contents of both fields after logout, the Log in
button state (present? dimmed or bright?), absence of the Logout button, and any relevant log
line. Judge "disabled" the same way TC-AUTH-001 does: by appearance, with one tiebreaker click
only if genuinely ambiguous.

## End state
Leave the app on the login screen, logged out.
