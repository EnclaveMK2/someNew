---
id: TC-AUTH-001
title: Successful login with the Admin account
target: player
priority: P1
---

## Preconditions
Player running and sitting at the ВХІД login modal, logged out.

## Steps
1. Screenshot; locate the username and password fields.
2. Click the username field, type the **admin** username from the credentials file.
3. Click the password field, type the admin password.
4. Screenshot and confirm both fields are populated (password shows as `*` characters).
5. Click **Увійти**.
6. Wait ~3 s, screenshot.

## Expected
- The login modal disappears.
- The account name and a **Вийти** button appear top-right.
- The toolbar (**Новий** / **Сценарії** / **Завдання**) is present.
- `Player.log` contains `AuthPanelController: login succeeded.`

## Verdict
- **PASS** — modal gone AND account name visible AND the log line present.
- **PARTIAL** — logged in but something is missing (e.g. toolbar item absent).
- **FAIL** — still on the login screen, or an error box appeared.

## Evidence to record
The account name shown top-right, and the matching `Player.log` line.
