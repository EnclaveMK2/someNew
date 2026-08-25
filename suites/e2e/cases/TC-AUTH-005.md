---
id: TC-AUTH-005
title: Login attempt with empty fields
target: installed-app
priority: P2
---

## Preconditions
App running, on the login screen, logged OUT, both fields EMPTY. If anything was typed during a
previous case, clear both fields first and confirm by screenshot.

## Steps
1. `wake <pid>`, screenshot, confirm both fields are empty.
2. Note the current last line of the log:
   /c/Users/nogra/AppData/LocalLow/The A-Team/Theater.Viz/Player.log
3. Click Log in once.
4. Wait about 4 s, screenshot.
5. Re-read the log tail and compare with step 2.

## Expected result
1. No login occurs — the user is not authorized: the modal stays, no map, no Logout button.
2. Record whether a server request appears to have been made at all (any new log line), or
   whether the click was completely inert.

## Verdict
- PASS — no login and no authorization.
- PARTIAL — no login, but something unexpected happened (an odd state, or an error that looks
  like a server error rather than client-side validation). Describe it.
- FAIL — the app logged in, froze, or crashed.
- BLOCKED — app not running, or the fields could not be emptied.

## Notes
TC-AUTH-001 covers whether the button LOOKS disabled. This case is about the OUTCOME: that no
authorization happens. Report both what the UI did and whether the log gained anything.

## Evidence to record
UI state after the click, whether Player.log gained any line, and any message shown.
