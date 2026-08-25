---
id: TC-ROLE-002
title: Instructor — scenarios, tasks, analytics
target: installed-app
priority: P1
---

## Preconditions
App running, logged OUT (log out first if someone is logged in). Use the **instructor** account
from credentials.local.txt. Never print passwords.

## Steps
1. Log in as the instructor.
2. Screenshot the toolbar and list the buttons you see.
3. Click "New" and confirm the scenario editor opens.
4. In the editor, confirm scenario work is permitted: add one unit and confirm it appears. Do
   not save or push.
5. Return to the main view and open the scenarios list — confirm it opens.
6. Open the assignments/tasks screen — confirm it opens and that creating or assigning a task is
   offered (a create/assign control is present). Do not actually create one.

## Expected result
All of the following are available to an instructor:
1. Scenario work — create and edit scenarios (import/export controls present if the UI offers
   them).
2. Tasks — the assignments screen opens and offers creating/assigning a task.
3. Results — some way to review or grade simulation results is reachable from the assignments
   area.

## Verdict
- PASS — scenario editing, the tasks screen, and a create/assign capability are all available.
- PARTIAL — most are available but one is missing or blocked. Name exactly which.
- FAIL — the instructor cannot create/edit scenarios, or the tasks screen is unavailable.
- BLOCKED — could not log in as instructor.

## Notes
Compare the toolbar against the administrator baseline recorded in TC-ROLE-001 and state the
difference explicitly, even if there is none.
If a control for grading or reviewing results cannot be found anywhere, say so plainly rather
than assuming it exists behind something you did not open.

## Evidence to record
The literal toolbar buttons seen, whether a unit could be added, whether the assignments screen
opened, and what create/assign or grading controls were visible there.

## End state
Leave the app logged out.
