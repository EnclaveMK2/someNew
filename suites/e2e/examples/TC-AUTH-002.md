---
id: TC-AUTH-002
title: Wrong password is rejected with a visible error
target: player
priority: P1
---

## Preconditions
At the ВХІД login modal, logged out. (If logged in, click **Вийти** first.)

## Steps
1. Type the **admin** username.
2. Type a deliberately wrong password: `wrongPass123!`
3. Click **Увійти**.
4. Wait ~3 s, screenshot the modal area.

## Expected
- Login is refused: the modal STAYS on screen.
- A readable error message appears (red error box under the title).
- No account name appears top-right.

## Verdict
- **PASS** — still on the login screen AND a visible error message.
- **PARTIAL** — refused, but no error shown to the user (silent failure).
- **FAIL** — login succeeded with a wrong password (security defect — flag loudly).

## Notes
An SSL/transport error message instead of a credentials error is a known transient flake:
retry once. If it recurs, record it as PARTIAL with the exact text.

## Evidence to record
The exact error text displayed.
