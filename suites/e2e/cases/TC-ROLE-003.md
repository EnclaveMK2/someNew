---
id: TC-ROLE-003
title: Tester — no access to tasks
target: installed-app
priority: P1
---

## Preconditions
App running, logged OUT (log out first if someone is logged in). Use the **tester** account from
credentials.local.txt. Never print passwords.

## Steps
1. Log in as the tester.
2. Screenshot the toolbar and list EVERY button you see, by label.
3. Click "New" and confirm the scenario editor opens.
4. In the editor, confirm the map/scenario tools are usable: add one unit (equipment placement)
   and confirm it appears. Do not save or push.
5. Confirm the simulator is reachable — a simulate/run control is present in the editor.
6. Look specifically for the tasks/assignments module.

## Expected result
1. Map-building tools, equipment placement and the simulator ARE available.
2. The tasks/assignments module is NOT available — no such button in the toolbar, or it is
   present but blocked.

## Verdict
- PASS — editor, unit placement and the simulate control all work, AND the tasks module is not
  accessible.
- FAIL — the tasks module IS accessible to this account, or the editor/placement/simulator is
  unavailable when it should be.
- BLOCKED — could not log in as the tester account.

## Notes
The decisive check is the tasks module. State clearly which of these you observed:
- the assignments button is absent from the toolbar entirely;
- it is present but visibly disabled;
- it is present and opens (which would be a FAIL).

Also record which role the app believes this account has, if the UI shows it anywhere. The
client distinguishes User / Cadet / Instructor / Admin, and only the plain User role is expected
to lose the assignments module — so if this account behaves differently, that is worth saying.

## Evidence to record
The literal toolbar buttons seen (this is the core evidence), whether a unit could be added,
whether a simulate control exists, and the exact state of the tasks/assignments module.

## End state
Leave the app logged out.
