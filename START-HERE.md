# Start here

You are picking up QA of the **Theater** project on a machine that knows nothing about it.
Everything you need is in this repo. Read in this order; do not ask the tester to re-explain
what is written down here.

| # | Read | Gives you |
|---|---|---|
| 1 | `knowledge/app-under-test.md` | what the app is, how to get it running, which accounts exist |
| 2 | `knowledge/known-issues.md` | quirks and open defects — so you do not "discover" them again |
| 3 | `skills/` | the workflows: `e2e-ui-tests` (run the suite), `viz-scenario-editing` (build scenarios) |
| 4 | `suites/e2e/README.md` | how a test run is organised and dispatched |
| 5 | `suites/e2e/worker-preamble.md` | the driving reference every worker reads |
| 6 | `harness/` | the scripts that actually move the mouse |

## What is NOT here, and never will be

**Credentials.** No passwords are stored in this repo and none should ever be added. The suite
reads them from `tests/e2e/credentials.local.txt`, which is git-ignored;
`suites/e2e/credentials.example.txt` shows the shape. Ask the tester for the values on a new
machine — that is the one thing worth asking for.

## Working copy vs home of record

This repo is where the tooling **lives**. It is not where it **runs**: the harness and suite
expect to sit at `<theater-viz>/tests/e2e/`, and paths inside them are absolute
(`C:/Work/theater-viz/...`). On a new machine, clone this repo and work from it — read the
docs here, run the scripts from here, and adjust the paths if the checkout is elsewhere.

**Never commit any of this into the product repo** (`theater-viz`). It is the tester's own
tooling and does not belong in the product's history. New tools, skills and updates are
committed HERE.
