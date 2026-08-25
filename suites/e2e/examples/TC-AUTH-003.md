---
id: TC-AUTH-003
title: Empty credentials do not log in
target: player
priority: P2
---

## Preconditions
At the ВХІД login modal, logged out, both fields empty.

## Steps
1. Screenshot; confirm both fields are empty.
2. Click **Увійти** without typing anything.
3. Wait ~2 s, screenshot.

## Expected
- No login occurs; the modal stays.
- Ideally some feedback (error text or an inert button).

## Verdict
- **PASS** — no login happened.
- **PARTIAL** — no login, but zero feedback to the user.
- **FAIL** — the app logged in, crashed, or froze.

## Notes
The button being clickable while the fields are empty is a KNOWN issue — do not report it
as new. Only judge whether a login actually occurs.

## Evidence to record
What the UI did after the click (unchanged / error text / other).
