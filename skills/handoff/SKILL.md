---
name: handoff
description: Resume or wrap up a work session via the living handoff doc (docs/HANDOFF.md). On resume, read the handoff + git state to orient before working. On wrap-up, rewrite the handoff with current progress so the next agent (or another machine) can pick up cleanly. Use when starting a session ("resume", "continue", "pick up", "where were we"), ending one ("wrap up", "hand off", "update the handoff", "I'm done for today"), or switching machines.
---

# Handoff — session continuity

This skill manages **`docs/HANDOFF.md`**, the single living handoff document.
The handoff holds **state** — where things stand, what's next, and the gotchas.
It has two modes — pick by the user's intent:

- **RESUME** — default; also: `resume`, `start`, `continue`, `pick up`, "where were we".
- **WRAP-UP** — `wrap`, `wrap up`, `update`, `end`, `done`, "hand off", "I'm done".

All paths below are relative to the repo root (`/Users/vadim/projects/theater/theater-viz`).

---

## RESUME mode

Goal: orient yourself from the doc + real repo state, then tell the user what's
next. **Do not start coding until you've reconciled the doc against reality.**

1. **Read** `docs/HANDOFF.md` end to end.
2. **Verify the doc against the live repo** (the doc can be stale — trust the repo):
   - `git -C . log --oneline -3` and `git -C . status -sb` (parent).
   - If the doc's HEAD/Remote table disagrees with the repo, **trust the repo**
     and note the discrepancy to the user.
3. **Skim the next task** from the handoff's "Next up" so the decisions/coupling notes are
   loaded before you touch code.
4. **Report** to the user, briefly: where things stand, the single next task, any
   reconciliation surprises, and any open gotcha (disk, unpushed work). Then ask
   whether to proceed or wait — don't auto-start a large coupled change.

---

## WRAP-UP mode

Goal: leave `docs/HANDOFF.md` accurate enough that a fresh agent on another
machine can continue with zero extra context. **Rewrite the doc; don't just
append.**

1. **Gather ground truth first** (don't write from memory):
   - `date +"%Y-%m-%d %H:%M %Z"` — for the stamp.
   - Parent: branch, HEAD short hash, and whether pushed
     (`git -C <repo> status -sb | head -1` shows `ahead`/`behind`; `[origin/...]`
     with no ahead/behind = pushed).
   - The current `(in progress)` / next task.
2. **Warn about anything that breaks tomorrow's clone** and surface it to the user:
   - Unpushed commits that the next clone wouldn't see.
   - Uncommitted working-tree changes; an in-flight half-done task.
   - Offer to push / commit as needed.
3. **Rewrite `docs/HANDOFF.md`**, preserving its section structure:
   - **Header** — refresh `Last updated` (from `date`) and `Updated by`.
   - **TL;DR** — one honest paragraph: what's done, what's in flight, what's next.
   - **Repo & branch state** — update the HEAD/Remote table from step 1.
   - **Done recently** — add a subsection for each task finished this session
     (decision, commit hashes per repo, test result, open notes). Demote older
     entries into **History** when the list grows long.
   - **Next up** — the next task(s) with their locked decisions/coupling so the
     next agent doesn't re-litigate.
   - **Open known issues** / **Working rules & gotchas** — add any new lesson
     learned this session; drop anything no longer true.
   - **History** — keep a brief, link-out record of completed work; don't let it
     bloat (point to the trackers / git history instead of duplicating detail).
4. **Honesty bar:** if tests were not run, a task is half-done, or something is
   unpushed, **say so explicitly** in the doc. A handoff that overstates "done"
   is worse than none.
5. Remind the user to commit the doc and, if they're
   switching machines, to push everything.

---

## Notes

- Salvage, don't hoard: when a handoff item has a permanent home (a known issue in
  a `TASKS.md`, a decision in a design doc), move the detail there and leave a
  one-line pointer in the handoff.
- If `docs/HANDOFF.md` is ever missing, recreate it with the structure above:
  header, TL;DR, repo state, Done recently, Next up, open issues, working rules,
  how to run tests, history.
