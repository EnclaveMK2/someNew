---
name: test-theater-viz-qa
description: Run the regimented manual-QA pass against theater-viz — the full auth + role-gating + scenario-editing test-case suite driven through the live Unity Editor, dispatched as an isolated subagent and reported as a pass/fail verdict table. Use to "run the viz QA pass", "run the manual test cases", "do the full viz acceptance test", or regression-check the auth/scenario UI. For ad-hoc dev testing of a single change, use test-theater-viz-editor instead.
---

# Manual-QA pass for theater-viz (via MCP)

This skill runs the **standardized manual-QA suite** — the auth, role-gating, and
scenario-editing acceptance cases — against a live Unity Editor over MCP, and produces a
**pass/fail verdict table**. It is a regression/acceptance harness, distinct from ad-hoc
dev testing.

> **Pick the right skill.**
> - **`test-theater-viz-editor`** — *dev testing*: interactively verify that one change
>   works in-Editor, from whatever session you're in (no model switching). It also holds
>   the shared **mechanics** this skill depends on: MCP preflight, the `execute_code`
>   gotchas (method-body / no `using` / fully-qualified types / `isPaused=false` prefix),
>   UI-Toolkit driving (Clickable reflection, deferred-tick focus reads), and the
>   **Viz-driving reference** (auth element names, controllers, scenario ops, push rule,
>   known bugs).
> - **`test-theater-viz-qa`** (this) — *acceptance/regression*: run the whole case suite
>   and report verdicts.
>
> **This skill does NOT duplicate the mechanics.** Read `test-theater-viz-editor` first
> (its Preflight, "Driving the UI", and "Viz-driving reference" sections) — everything
> below assumes it.

---

## How to run it: one isolated subagent

Run the suite as a **single isolated subagent** carrying a self-contained recipe prompt —
**not inline** in your main session. Two reasons:

1. **Cost.** Inline, the main loop re-reads the whole conversation every turn, so a long
   30-tool-call pass gets very expensive. An isolated subagent absorbs all the verbose
   `execute_code`/JSON churn and returns only a compact verdict table.
2. **Determinism.** A fixed recipe prompt makes the run *recipe-following* (cheap,
   repeatable) instead of *live discovery* (expensive, high-variance).

### Model choice (measured 2026-06-23, full 17-case pass)

- **Default the subagent to Sonnet.** Isolated full run: Opus **74,239 tok**, Sonnet
  **90,753 tok** — Sonnet used ~22% *more* tokens yet was **~4× cheaper in $** (price
  tier, not token volume). **Identical verdicts**; both caught a bug the old inline run
  missed.
- **Reserve Opus** for orchestrating very large runs where isolating a long transcript is
  the point — the *workers* should still be Sonnet.
- **Don't use Haiku** for the flow: it explored more verbosely (more tokens for fewer
  cases) and is the most likely to flail on reflection / the pause-stop traps. Fine only
  for trivial read-and-report probes.
- The subagent reports its own usage in a `<usage>subagent_tokens: …</usage>` block —
  that's the only clean way to measure cost (inline cost can't be isolated; use `/cost`
  for the session total).

> **Choosing the model does not change *your* session.** Dispatching a `model: sonnet`
> subagent from an Opus session keeps your session on Opus. The skill never silently
> downgrades anything — it spawns a separate worker.

### Single shared Editor ⇒ run cases sequentially

There is exactly **one** stateful Editor (Play Mode, login, loaded scenario are global
singletons mutated in place). So **do not fan out parallel subagents** over the Editor —
they would clobber each other's state. Multi-agent here buys cost isolation, not
wall-clock; keep the pass to one sequential worker.

### Pre-positioning before you dispatch

From the orchestrating session, get the Editor to a known start state, then hand off:

1. Confirm Play Mode is on and the bridge is reachable (`mcpforunity://editor/state`).
   Re-enable **No Throttling** + `Application.runInBackground=true` for the unattended run
   (see `test-theater-viz-editor` Preflight 4).
2. Leave the app at the **login screen, logged out** (`AuthController.LogOut()`), so the
   worker starts from a clean auth state.
3. Dispatch the Sonnet subagent with the recipe prompt (template below).
4. On completion: relay the verdict table, then **clean up** any scenarios the run created
   (the run pushes real scenarios to the backend) — `BackendClient.DeleteScenario` as the
   owning account; confirm they're gone. Revert No Throttling to Default.

---

## The case suite (17 cases)

Each case → **verdict (PASS / PARTIAL / FAIL) + one evidence line**. The element names,
controllers, login/logout, dropdown `TypedValue`, `AddRoute(RouteModel)`, push rule,
scenario-list, Tab-tick, and Play-Mode recovery are all in `test-theater-viz-editor`'s
**Viz-driving reference** — the recipe prompt should inline them.


**End state:** leave logged in as the Admin account. Do not delete scenarios — the
orchestrator cleans up.

---

## Recipe-prompt template (for the dispatched subagent)

Build the subagent prompt from these pieces (keep it self-contained so the worker never
has to discover anything live):

1. **Context line:** live Unity 6000.3.2f1 Editor, project Theater.Viz, already in Play
   Mode at the login screen; work via UnityMCP; don't stop Play Mode; produce a verdict
   table.
2. **Tool loading:** "First call ToolSearch `select:mcp__UnityMCP__execute_code,
   mcp__UnityMCP__read_console,mcp__UnityMCP__manage_editor`."
3. **The `execute_code` rules** (method-body / no `using` / fully-qualified types /
   `isPaused=false` prefix / walk the UITK tree manually) — copy from
   `test-theater-viz-editor`.
4. **The Viz-driving reference** (credentials source, element names, login/logout,
   role-gating props, scenario ops, dropdown `TypedValue`, `AddRoute(RouteModel)`, push
   rule, scenario list, Tab-tick) — copy from `test-theater-viz-editor`.
5. **The Play-Mode-exit recovery** block — copy from `test-theater-viz-editor`.
6. **The 17 cases above**, each asking for verdict + one evidence line.
7. **Return contract:** "Return ONLY a compact 17-row verdict table with one evidence line
   each, the created scenario Name + scenarioId + historyId, and the total execute_code
   call count."

Keep the prompt one self-contained block — the worker starts fresh with no inherited
context. (A known-good full prompt was used on 2026-06-23; reuse/adapt it rather than
re-authoring from scratch.)

---

## Reporting

Relay the subagent's verdict table verbatim, plus: the headline tally (e.g. *14 Pass /
1 Partial / 2 Fail*), the **key defects** distilled, the created scenario IDs, and the
measured `subagent_tokens`. Then perform cleanup (delete created scenarios, revert No
Throttling) and confirm the backend is left clean.

A PDF report generator (color-coded verdict table + cost section, fpdf2/Arial for
Cyrillic) was used previously; offer it when the user wants a shareable artifact.
