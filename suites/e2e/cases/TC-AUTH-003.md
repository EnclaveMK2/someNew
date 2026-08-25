---
id: TC-AUTH-003
title: Show password (eye) button reveals the entered password
target: installed-app
priority: P1
---

## Preconditions
App running (started by the tester). DETERMINE the current state yourself: wake it, screenshot,
and see whether it is logged in or at the login screen. If logged in, click Logout first. The
case needs the login screen with the Password field masked by default.

## Test value
Type exactly this into the Password field:

    Ab3!xY9@qZ

Ten characters, every one distinct — chosen so that a single dropped, duplicated or altered
character is immediately obvious when comparing.

## Steps
1. Wake the app, guarded screenshot, confirm the login screen.
2. Click the Password field and type the test value above.
3. **Before revealing**, crop the Password field closely and confirm it is MASKED, then count
   the mask characters. There must be exactly 10. Record the count.
   - If the count is not 10, the typing did not land correctly. Clear the field and retype.
     Do not proceed until the masked field holds exactly 10 characters — otherwise you cannot
     tell a reveal bug from a typing failure.
4. Click the eye button inside the Password field, once.
5. Crop the Password field closely again and read the revealed text character by character.
6. Compare it against the test value.

## Expected result
The password is displayed in plain text and matches the entered value EXACTLY — no characters
lost, added or altered.

## Verdict
- PASS — the revealed text is exactly `Ab3!xY9@qZ`, character for character.
- PARTIAL — the password is revealed but differs (a character missing, added, wrong case, a
  symbol changed). Quote EXACTLY what you read and say precisely how it differs.
- FAIL — clicking the eye does not reveal the password at all (still masked, or nothing
  happens), or the field is cleared by the click.
- BLOCKED — no eye button exists, the app is not running, or the field would not accept the
  test value after retries.

## Notes
Case sensitivity matters: `Y` and `Z` are capitals, `b`, `x`, `q` are lowercase. Read carefully
at high zoom — do not guess. If a character is genuinely unreadable, say which position is
uncertain rather than assuming it is correct.
Do not click Log in at any point. This case is only about the reveal.

## Evidence to record
The mask character count before revealing, the exact revealed string as you read it, and the
crop you read it from.

## End state
Clear the Password field and leave the app on the login screen, logged out.
