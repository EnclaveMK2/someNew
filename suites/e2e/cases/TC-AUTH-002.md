---
id: TC-AUTH-002
title: Login with an incorrect password
target: installed-app
priority: P1
---

## Preconditions
App running, on the login screen, logged OUT. A valid username exists — use the admin username
from credentials.local.txt. Never print passwords.

## Steps
1. `wake <pid>`, screenshot, confirm the login form with empty fields.
2. Type the admin username into Username.
3. Type the deliberately WRONG password `WrongPass123!` into Password.
4. Screenshot; confirm both fields hold content before continuing.
5. Click Log in once.
6. Wait about 4 s, screenshot the modal area.

## Expected result
1. An error message that CONTAINS the text "401" and the text "Invalid credentials". The
   surrounding wording is not prescribed — a substring match on both fragments is enough.
2. Login does not occur — the modal stays; no map, no Logout button, no account name.

## Verdict
- PASS — login refused AND the visible error text contains both "401" and "Invalid credentials".
- FAIL — login refused but the message is missing "401", missing "Invalid credentials", or absent
  altogether. Quote the EXACT text you saw.
- FAIL (severe) — login SUCCEEDED despite the wrong password. Flag this loudly.
- BLOCKED — app not running or not on the login screen.

## Notes
Transcribe the error text literally so the substring check can be verified. The app renders it
as a raw HTTP/JSON dump - that is ACCEPTED project behaviour, not a defect; never report it as
a finding. A transient SSL or transport error is a known flake: retry once; if it recurs, record
FAIL with the exact text.

## Evidence to record
The exact error string displayed, and confirmation that no login happened.
