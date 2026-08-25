---
name: e2e-ui-tests
description: Run end-to-end UI test cases against the INSTALLED Theater Viz desktop app by driving real mouse/keyboard, dispatched to isolated subagent workers so the orchestrator's context stays small. Use to "run the e2e tests", "run TC-XXX", "run the UI test cases", to add a new test case the tester describes, or to resume/aggregate a previous e2e run. Complements test-theater-viz-qa (which drives the Unity Editor over MCP instead of the installed app).
---

# E2E UI tests — subagent-batched

Everything lives in **`tests/e2e/`**. This skill is the entry point; the detail is in those files
so it survives across chats.

## Read these first

| File | What it is |
|---|---|
| `tests/e2e/README.md` | the design and the orchestrator procedure |
| `tests/e2e/dispatch-template.md` | **the exact worker prompt** + batching rules — do not re-invent it |
| `tests/e2e/worker-preamble.md` | what the worker reads (harness, UI labels, focus discipline) |
| `tests/e2e/cases/*.md` | the live suite; `_TEMPLATE.md` is the shape |

Do **not** read `worker-preamble.md` or the case files into your own context to pass them to a
worker — the worker reads them off disk itself. That is the entire cost saving.

## How this works

The tester supplies cases and starts the app. You capture each case as a self-contained file,
dispatch Sonnet workers per batch, and aggregate their JSON verdicts into one table.

```
Tester ──▶ Orchestrator (you) ──▶ Worker (Sonnet, own context)
                  ▲                      │ drives the real desktop
                  └── verdict table ◀────┘ writes results/<run>/TC-*.json
```

Measured: a worker burns ~50-60k tokens per case; the orchestrator's context grows ~1k.

## Procedure

1. **App:** the tester launches it themselves. Get the pid with
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File tests/e2e/tools/winput.ps1 pid`.
   Never launch or close it yourself.
2. **Capture the case.** The tester describes it in chat; write it to `cases/TC-XXX.md` following
   `_TEMPLATE.md`. Fill the gaps a cold worker cannot ask about: which account, how to judge a
   vague word like "disabled", what counts as evidence, the end state. Tell the tester what you
   added and why.
3. **Dispatch** using `dispatch-template.md` verbatim. One worker per 4-6 related cases,
   **sequentially** — never two at once, they share one screen.
4. **Aggregate** `results/<run-id>/*.json` into a table. Report verdicts, defects, and the
   worker's token usage.
5. **Scrutinise before relaying.** A worker's verdict is evidence, not gospel — if it judged
   something indirectly (appearance instead of behaviour) or contradicts known project docs,
   send it back for the decisive check with `SendMessage` (it keeps its context, so this is cheap).

## Hard-won rules

- **Never assert the app state in a dispatch prompt.** You do not know it — the tester may have
  logged out or restarted between runs, and a previous worker reported `end_state` goes stale.
  Tell the worker to DETERMINE the state and bring it to what the case needs. Only the pid is
  safe to pass, and the worker should re-check it.
- **Sequential only.** One screen, one app process.
- **Nobody touches mouse or keyboard while a worker runs.** Warn the tester every time.
- **The worker can capture the orchestrator's own chat window** and read expected outcomes from
  it. The preamble's FOCUS DISCIPLINE section guards against this — keep it there.
- **The UI language differs by build**: the installed app is English, older local builds were
  Ukrainian. The preamble carries an EN/UK label table; never fail a case over wording.
- **Project docs can be stale.** `test-theater-viz-editor` lists "Log In button is not greyed
  when fields are empty" as known — verified false on the installed build (TC-AUTH-001, run-001).
  When a case explicitly tests a documented quirk, judge it fresh.

## Target

`C:\Program Files\Theater Viz\Theater.Viz.exe` — override with `THEATER_VIZ_EXE` to test a
local build instead.
