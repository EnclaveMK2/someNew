---
id: TC-ROLE-004
title: Cadet — assigned tasks only
target: installed-app
priority: P1
---

## Preconditions
App running, logged OUT (log out first if someone is logged in). Use the **cadet** account from
credentials.local.txt. Never print passwords.

## Steps
1. Log in as the cadet.
2. Screenshot the toolbar and list EVERY button you see, by label.
3. Click "New" and record what happens — does the scenario editor open, is the button inert, or
   is a permission message shown?
4. Open the assignments/tasks screen and confirm it opens and lists assigned tasks (an empty
   list is fine — it must not error).
5. If the editor did open at step 3, try to add one unit and record whether it is permitted.

## Expected result
Only the assigned-tasks area is available. A cadet may accept a task, deploy their own forces
within limits, and run the simulation — but general scenario authoring is NOT available to them.

## Verdict
- PASS — the assignments screen is available, and general scenario creation/editing is blocked
  (New does not give a working editor, or unit editing is refused).
- PARTIAL — assignments work, but the cadet also gets authoring rights they should not have, or
  vice versa. Name exactly which.
- FAIL — the assignments screen is unavailable to the cadet, or the app errors.
- BLOCKED — could not log in as cadet.

## Notes
This case is mostly about what is DENIED, so be precise about the mechanism rather than the
outcome alone. For "New", state which of these happened:
- the button is absent;
- present but visibly disabled;
- clickable but nothing happens;
- it opens an editor that is read-only;
- it opens a fully working editor (which would be a finding).

An empty assignments list is NOT a failure — this account may simply have no tasks assigned.
Judge whether the screen is reachable and functional, not whether it has content.

## Evidence to record
The literal toolbar buttons seen, exactly what "New" did, whether the assignments screen opened,
and whether unit editing was permitted anywhere.

## End state
Leave the app logged out.
