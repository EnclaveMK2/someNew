# E2E UI tests for theater-viz — subagent-batched

End-to-end tests driven through **real mouse/keyboard input** against the **installed
Theater Viz application**, executed by **isolated subagent workers** so the orchestrating
session's context stays small.

**Target under test:** `C:\Program Files\Theater Viz\Theater.Viz.exe`
(override with the `THEATER_VIZ_EXE` environment variable — e.g. to test a local build).

## Why subagents

Driving a UI is screenshot-heavy. Done inline, every frame is re-sent along with the whole
conversation on each turn, and a long pass burns the daily limit. A worker subagent absorbs all
that churn in **its own** context and returns only a verdict table.

**This buys cost isolation, not parallelism.** There is one screen and one application process,
so workers run **sequentially** — parallel workers would fight over the same window. What
batching does buy:

- each worker's context stays small,
- a crashed batch loses only its own cases,
- results already on disk make a run resumable,
- workers can run on a cheaper model than the orchestrator.

## Layout

```
tests/e2e/
├── README.md               this file — also the orchestrator's instructions
├── worker-preamble.md      self-contained driving reference handed to every worker
├── cases/                  the live suite — cases supplied by the tester
│   └── _TEMPLATE.md        copy this shape for a new case
├── examples/               sample cases, kept only as format reference
├── tools/winput.ps1        DPI-aware SendInput harness (launch/click/type/screenshot)
├── credentials.local.txt   git-ignored; role : username : password
├── results/<run-id>/*.json one verdict per case
└── shots/                  scratch screenshots (git-ignored)
```

## Workflow

Cases are **written by the tester**, not invented by the model.

1. **Tester describes a case** (in chat, or by dropping a file into `cases/`).
2. **Orchestrator captures it** as a self-contained `cases/TC-XXX.md` following `_TEMPLATE.md`
   — preconditions, numbered steps, expected result, explicit verdict rules, known quirks.
   Getting this right matters: a cold worker cannot ask follow-up questions.
3. **Orchestrator dispatches** one worker per batch of ~4-6 related cases, **sequentially**.
   Keep the prompt SMALL: tell the worker to **read** `worker-preamble.md` and its assigned
   case files from disk itself, and pass it the results directory path. Pasting file contents
   into the prompt would push them through the orchestrator's context — exactly what this
   design avoids.
   Default the workers to **Sonnet**; the orchestrator stays wherever it is.
4. **Aggregate**: read `results/<run-id>/*.json` and print one table.
5. **Clean up**: close the app; remove anything the run created on the backend.

While a worker runs, **nobody touches the mouse or keyboard** — it is driving the real desktop.

## Verdicts

| Verdict | Meaning |
|---|---|
| `PASS` | expected result observed |
| `PARTIAL` | main goal met, something secondary wrong |
| `FAIL` | expected result not observed |
| `BLOCKED` | could not be executed (environment, prerequisite) |

A `FAIL` with clear evidence is a good outcome. An invented `PASS` is the only real failure.
