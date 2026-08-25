---
id: TC-AUTH-006
title: Successful login with valid credentials
target: installed-app
priority: P1
---

## Preconditions
App running, on the login screen, logged OUT. Use the admin account from credentials.local.txt.
Never print the password.

## Steps
1. `wake <pid>`, screenshot, confirm the login form with empty fields.
2. Type the admin username into Username.
3. Type the admin password into Password.
4. Screenshot; confirm both fields hold content (the password renders masked). If a field did
   not receive the text, clear it and retype before continuing.
5. Click Log in once.
6. Wait about 4 s, take a full screenshot.

## Expected result
1. The user is logged in — the login modal is gone.
2. A map is displayed — real rendered map content (terrain, roads and similar), not a blank or
   black screen.
3. A Logout button is present in the upper-right corner.

## Verdict
- PASS — all three hold.
- PARTIAL — logged in, but the map did not render, or the Logout button is missing or not in the
  upper right. Name exactly which failed.
- FAIL — login did not happen: the modal is still shown, or an error appeared.
- BLOCKED — app not running or not on the login screen.

## Notes
UI language depends on the build: Log in / Logout (English) and Увійти / Вийти (Ukrainian) are
the same controls — note which you saw, never fail the case over wording.
Supporting evidence: Player.log should gain the line "AuthPanelController: login succeeded."

## Evidence to record
Whether the modal disappeared, a brief description of the map actually rendered, the exact label
and position of the Logout button plus any account name shown, and the matching log line.

## End state
Leave the application logged in.
