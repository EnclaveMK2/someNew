# Theater QA tooling

Testing tooling for the **Theater** project, kept here so it survives outside any one product
repo: the input harness, the e2e suite, the Claude Code skills that drive them, and the local
harness settings.

## Layout

| Path | What it is |
|---|---|
| `harness/winput.ps1` | DPI-aware Win32 SendInput harness — launch, wake, click, drag, type, keys, guarded screenshots |
| `harness/viz-unit.ps1` | places a unit in the scenario editor — `Space`, or the Unit button |
| `harness/viz-route.ps1` | builds a unit's movement route — `R` or the Create Route button, then mouse clicks |

Both editor scripts take `-Via hotkey|button`, so an e2e pass can drive the same action
through either entry point and catch one of them regressing. Everything happens through real
cursor and keyboard input — there is no back door into the app.
| `suites/e2e/` | the e2e suite: orchestrator README, worker preamble, dispatch template, cases |
| `suites/e2e/cases/` | the live test cases (`TC-AUTH-*`, `TC-ROLE-*`); `_TEMPLATE.md` is the shape |
| `skills/` | Claude Code skills that run and maintain the tests |
| `settings/` | harness permission allowlist (`settings.local.json`) |

## Where it runs from

**This repo is the home of record, not the runtime location.** Deploy it as:

| From here | To | Why there |
|---|---|---|
| `suites/e2e/`, `harness/` | `C:/Work/theater-viz/tests/e2e/` (+ `tools/`) | next to the app under test; git-ignored there via `.git/info/exclude` |
| `skills/*` | `C:/Work/.claude/skills/` | **not** into the product repo |

Skills must go in the **workspace root** `.claude/skills/`, not in `theater-viz/.claude/skills/`.
A skill stored under a subdirectory is only offered once the session touches files in that
subdirectory, so a fresh chat that opens at `C:/Work` and is asked to build a scenario would
not be offered it at all — which defeats the point of writing it down. Keeping them out of the
product repo also means no exclude rule to maintain.

Paths inside the skills and the preamble are absolute (`C:/Work/theater-viz/...`) and assume
that checkout. Nothing syncs automatically; copy changes back deliberately.

## Credentials

Never committed. The suite reads `tests/e2e/credentials.local.txt`, git-ignored, one line per
account:

```
role : username : password
```

See `suites/e2e/credentials.example.txt` for the shape. Test accounts are shared out of band.

## Not included

Run artifacts — `results/` (verdict JSON per run) and `shots/` (screenshots) — stay local. They
are outputs, not tooling, and the screenshots capture whatever was on the desktop at the time.
