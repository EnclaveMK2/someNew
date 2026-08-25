---
id: TC-AUTH-004
title: Login with an incorrect username
target: installed-app
priority: P1
---

## Preconditions
App running. DETERMINE the current state yourself: wake it, screenshot, and see whether it is
logged in or at the login screen. If logged in, click Logout first. Both fields must be empty
before you start.

## Steps
1. Wake the app, guarded screenshot, confirm the login form with empty fields.
2. Type the non-existent username `nosuchuser_qa` into Username.
3. Type any well-formed password, for example `SomePass123!`, into Password.
4. Screenshot; confirm both fields hold content.
5. Click Log in once.
6. Wait about 4 s, screenshot the modal area.

## Expected result
1. An error message that CONTAINS the text "401" and the text "Invalid credentials". The
   surrounding wording is not prescribed — a substring match on both fragments is enough.
2. Login does not occur.

## Verdict
- PASS — login refused AND the visible error text contains both "401" and "Invalid credentials".
- FAIL — refused but the message is missing either fragment, or absent. Quote the EXACT text.
- FAIL (severe) — login SUCCEEDED for a non-existent user. Flag this loudly.
- BLOCKED — app not running or not on the login screen.

## Notes
The message must NOT reveal which of the two inputs was wrong — an unknown username and a wrong
password should produce the SAME response. If the message here differs from the one seen in
TC-AUTH-002, say so explicitly: that difference is a user-enumeration weakness worth reporting.

The app renders the error as a raw HTTP/JSON dump. That is ACCEPTED project behaviour, not a
defect - never report it as a finding. Only verify that both required substrings are present.

## Evidence to record
The exact error string, and whether it is identical to the TC-AUTH-002 message.
