---
id: TC-ROLE-001
title: Administrator — full access
target: installed-app
priority: P1
---

## Preconditions
App running. DETERMINE the state yourself: wake it and screenshot. If a user is already logged
in, click Logout first. Use the **admin** account from credentials.local.txt. Never print
passwords.

## Steps
1. Log in as the administrator.
2. Screenshot the main screen and inspect the top toolbar.
3. Check which modules are reachable. For each toolbar button, click it, confirm the screen it
   opens actually appears, then return to the main view.
   - The scenario list must open and show entries (or an empty-list state, not an error).
   - The assignments/tasks screen must open.
   - "New" must open the scenario editor.
4. In the scenario editor, confirm editing is permitted: add one unit and confirm it appears.
   Do not save or push the scenario.

## Expected result
Full, unrestricted access to all modules. Every module in the toolbar is present, opens, and is
usable — nothing is hidden, greyed out, or blocked with a permission message.

## Verdict
- PASS — every toolbar module is present, opens, and editing is permitted.
- FAIL — any module is missing, disabled, or refuses to open for an administrator.
- BLOCKED — could not log in as administrator.

## Notes
Judge only what this desktop client exposes. Account, database and server-side administration
are not part of this application and are out of scope for this case.
List the toolbar buttons you actually saw, by their labels, so the other role cases can be
compared against this baseline.

## Evidence to record
The literal list of toolbar buttons visible, which screens opened successfully, and whether
adding a unit was permitted.

## End state
Leave the app logged out (click Logout at the end).
