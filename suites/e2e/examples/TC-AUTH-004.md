---
id: TC-AUTH-004
title: Logout returns to the login screen
target: player
priority: P1
---

## Preconditions
Logged in as the admin account (run TC-AUTH-001 first if needed).

## Steps
1. Screenshot; confirm the account name and **Вийти** are visible top-right.
2. Click **Вийти**.
3. Wait ~3 s, screenshot.

## Expected
- The ВХІД login modal returns.
- The account name and toolbar actions are gone.
- No unhandled error appears in `Player.log`.

## Verdict
- **PASS** — back at the login modal with the session cleared.
- **PARTIAL** — logged out but UI remnants persist (e.g. toolbar still active).
- **FAIL** — still logged in, or the app errored/froze.

## Evidence to record
Whether the ВХІД modal is present after logout, plus any error line from the log.
