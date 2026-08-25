---
name: work-on-gh-issue
description: Implement one approved GitHub issue end-to-end via strict red→green discipline — pick an eligible issue, branch, reproduce it with a failing Editor check, fix to green, run the QA pass, open a PR, and shepherd it through review. Use when asked to "work on issue N", "fix issue N", "pick up the next ready issue", or "work the backlog".
---

# work-on-gh-issue — implement one approved issue via red→green discipline

You implement ONE approved issue from `Theater-Dev/theater-viz` and open one PR. The
issue is already triaged and approved (its Project Status is **To Do**); your job is to
implement it well, not to re-decide whether it should be done.

All file changes happen in the workspace: the current checkout (the repo you run this skill in)

> **Unity reality.** theater-viz is a Unity 6000.3.2f1 client with **no headless test
> runner**, and the repo's standing rule forbids building screenshot/UI-driving or
> headless Unity test harnesses. The verification gate here is the **live Unity Editor
> QA pass** — the `test-theater-viz-editor` skill (ad-hoc, single-change verification)
> or `test-theater-viz-qa` (the full auth + role-gating + scenario-editing acceptance
> suite), driven over MCP. Throughout this skill, "the test" means a concrete,
> reproducible Editor verification procedure, not a unit test.

## Invocation

- `work-on-gh-issue <number>` — work that specific issue. If its Project Status is not
  currently **To Do**, say so and ask the user to confirm before proceeding.
- `work-on-gh-issue` (bare) — rank the eligible issues (§1), show the list, propose the
  top one, and WAIT for the user to confirm or pick another before starting.

## 1. Select the issue

This project tracks issue state with the **Status** field of GitHub Project
**4 (Theater R&D)**, owner `Theater-Dev`. There is **no `Blocked` Status option**, so
"blocked" here means: revert the item's Status to **To Do** and post an explanatory
comment (beginning `blocked:` or `could not reproduce:`) so a human re-triages it. The
item stays in the eligible pool and may be re-picked — the comment is the signal, so
make it explicit.

Selection: fetch items with
`gh project item-list 4 --owner Theater-Dev --format json --limit 100`
and pipe into this ranking jq (keeps Status == `To Do`, orders by priority then issue
number):

```bash
# Reads `gh project item-list --format json` on stdin; prints "<number>\t<title>".
jq -r --argjson prio '["P0","P1","P2","P3"]' '
  .items
  | map(select(.status == "To Do"))
  | map(.prank = ((.priority // "") as $p | ($prio | index($p)) // ($prio|length)))
  | sort_by(.prank, .content.number)[]
  | "\(.content.number)\t\(.title)"'
```

Adapter operations (set Status via GraphQL; read/comment on the linked issue). Get an
item's `<itemId>` by matching `.content.number` in the `item-list` JSON. Pick `<o>`
from the Status option ids below for the target state:
- `In progress` → `47fc9ee4`
- `Ready for Test` → `df73e18b`
- `To Do` (also the "blocked"/back-to-pool target) → `f75ad846`

- set status: `gh api graphql -f query='mutation($p:ID!,$i:ID!,$f:ID!,$o:String!){updateProjectV2ItemFieldValue(input:{projectId:$p,itemId:$i,fieldId:$f,value:{singleSelectOptionId:$o}}){projectV2Item{id}}}' -f p=PVT_kwDOC3ZZ2M4A1WTR -f i=<itemId> -f f=PVTSSF_lADOC3ZZ2M4A1WTRzgq1V84 -f o=<o>`
- read content: `gh issue view <n> --repo Theater-Dev/theater-viz --json number,title,body,comments`
- comment:      `gh issue comment <n> --repo Theater-Dev/theater-viz --body "..."`
- to in-progress: set status `<o>=47fc9ee4`
- to blocked:     set status `<o>=f75ad846` (back to **To Do**) AND post the explanatory comment
- **Ready for Test** (`df73e18b`) is set by the **merge/deploy process when the PR lands**,
  NOT by this skill. While a PR is open and under review the issue stays **In progress**;
  this skill never moves an issue to Ready for Test.

## 2. Claim it

Once the user confirms an issue, read its full content first (title, body, and ALL
comments — human comments OVERRIDE the body's proposed approach).
Then transition it **To Do → In progress** (adapter "to in-progress").

## 2a. Existing PRs on this issue (rework — preserve approvals)

Rework happens when an issue is made eligible again while PR(s) from a prior pass are
still open. Before branching, check for them on the repo:
`gh pr list --repo Theater-Dev/theater-viz --state open --search "Theater-Dev/theater-viz#<n> in:body" --json number,title,headRefName,reviewDecision,labels`
(also look for branches matching `fix/<n>-*`).

If any exist, you are ADDING the outstanding delta (per the issue body + human
follow-up comments), NOT redoing the fix:
- Do NOT touch, reword, or re-push an APPROVED PR or its branch.
- Implement ONLY the outstanding work as a NEW sibling PR on a branch
  `fix/<n>-<new-slug>` (a DISTINCT slug, same `<n>-` prefix so the siblings group
  together).
- ADDITIVE ONLY: if the outstanding work would require MODIFYING an already-approved PR
  (rather than a new sibling), STOP — hard-stop (§6) with a reason beginning
  "needs-human:" explaining why.
- NOTHING-TO-DO: if nothing remains beyond what the existing PR(s) already cover, do
  NOT open a PR — hard-stop (§6) with a reason beginning "needs-human: all work already
  covered by existing PR(s) — please review/merge or clarify".

## Ground truth — intended behavior

Treat the repo's `CLAUDE.md` (and any docs/specs it points to) as the authoritative
description of how this project is meant to behave; read the relevant parts before
changing code. Never make a change that contradicts intended behavior. And if the ISSUE
ITSELF contradicts it — it asks for something the project intentionally does the other
way — do NOT implement it: hard-stop (§6) with a reason beginning "needs-human:" that
explains the conflict, so a human can reconcile the issue with intended behavior.

## 3. Branch

In the workspace, ensure you are on an up-to-date `main` with a clean tree, then create
`fix/<issue#>-<short-slug>`. Never commit to `main`.

## 4. Implement via strict red→green discipline (non-negotiable)

theater-viz has **no headless test runner** — its verification gate is the live Unity
Editor QA pass (invoke the `test-theater-viz-editor` skill for single-change
verification, or `test-theater-viz-qa` for the full acceptance suite, over MCP). Do
NOT build screenshot/UI-driving or headless Unity test harnesses. So "the test" is a
concrete, reproducible **Editor verification procedure**, run red→green:

a. REPRODUCE FIRST. Write down the exact Editor steps that exhibit the bug (scenario to
   load, role to log in as, UI action to take, what to observe), then run that
   procedure via the Editor QA pass against the UNMODIFIED workspace. It MUST visibly
   FAIL — that red observation IS your reproduction. CAPTURE it (Console error /
   screenshot / described wrong behavior); you quote it in the PR.
   CANNOT REPRODUCE — HARD STOP: if the procedure shows correct behavior on unmodified
   code, you cannot reproduce the finding (already fixed, stale, or an environment
   artifact). Do NOT implement a fix and do NOT open a PR. Move the issue back to
   **To Do** (adapter "to blocked") with a comment beginning "could not reproduce: ".
b. Implement the MINIMAL fix.
c. Run the SAME Editor procedure again — it must now pass (green). CAPTURE the result.
d. Run the broader `test-theater-viz-qa` acceptance pass (auth + role-gating + scenario
   editing) to confirm no regression. ALL green, or hard-stop (§6).

> When done in the Editor, leave it **un-paused** and in a clean state (don't wedge the
> play toggle) — follow the `test-theater-viz-editor` skill's discipline.

## Pre-PR self-review (before opening the PR)

After the Editor pass is green and committed, review your branch diff with fresh,
skeptical eyes BEFORE opening the PR — this front-loads the hygiene the PR reviewer
would otherwise catch and usually collapses the review loop to a single round. For true
independence, dispatch a SEPARATE read-only review subagent over the diff if you can;
otherwise self-review. Run `git diff main...HEAD` and check each hunk against this
checklist:

- **Repro** — the Editor verification procedure is written down, exercises the changed
  code path, and doesn't rely on flaky timing; the captured red→green evidence is real.
- **Correctness** — async callbacks check a cancellation/still-valid guard before
  writing state; `||` vs `??` is right where empty string must fall through;
  fire-and-forget tasks are awaited or have error handling; the code honors the
  invariant its own adjacent comment states.
- **DRY** — grep for an existing constant/util/mapping before adding a new one.
- **Docs** — comments/docstrings don't over-claim behavior this path doesn't guarantee.
- **Conventions** — the change follows the surrounding C#/Unity idioms and naming.

For each BLOCKING finding, fix it with the SAME red→green discipline (§4), re-run the
QA pass green, then re-review. Stop once the diff is clean or after **2 rounds**,
whichever comes first; carry any leftover suggestions into the PR's `## Pre-review
notes`.

## 5. Commit & open the PR

Small conventional commits (`fix:`, `test:`); keep history readable.

NEVER use a GitHub closing keyword for the issue — none of `close`/`closes`/`closed`,
`fix`/`fixes`/`fixed`, `resolve`/`resolves`/`resolved` followed by `#<n>` or
`Theater-Dev/theater-viz#<n>` — in ANY commit message OR the PR title/body. Merging to
`main` would auto-close the issue and bypass this skill's state transitions (the issue
reaches **Ready for Test** only via the merge/deploy process on merge — let that process
decide its final state). To reference the issue without closing it, use a bare link or
`Refs Theater-Dev/theater-viz#<n>` — no closing verb before it.

Push the branch and open a PR on the repo, assigning it to the repo owner so they find
it on their list — `gh pr create --assignee <owner>` (where `<owner>` is the gh login
from Attribution, i.e. `gh api user --jq .login`). PR body:
- `## Finding` — summary + a BARE link to the issue (`Theater-Dev/theater-viz#<n>`; a
  bare link does NOT close — never precede it with a closing verb)
- `## Red repro` — the Editor verification procedure, what it exercises, the captured
  RED observation
- `## Green` — the change that made it pass + the captured green Editor/QA result
- `## Risk` — blast radius
- `## Pre-review notes` — only if the pre-PR self-review left suggestions or
  unaddressed findings after 2 rounds
- `## Deviation from approved approach` — only if you deviated

If `gh pr create --assignee` didn't take, add it after:
`gh pr edit <n> --repo Theater-Dev/theater-viz --add-assignee <owner>`.

Once the PR is open, **leave the issue in In progress** and comment the PR URL on the
issue. Do NOT move it to **Ready for Test** — that transition happens only when the PR is
**merged** (by the merge/deploy process or a human), never when the PR is merely opened.

## PR review-phase labels

These live on the **PR** and are independent of the issue's Project Status. All label
edits are best-effort: tolerate a label not existing (log and continue).

- Immediately after `gh pr create` succeeds, mark the PR in the automated loop:
  `gh pr edit <n> --repo Theater-Dev/theater-viz --add-label in-auto-review`.
- On Copilot-loop exit (no actionable comments, 2 rounds, or poll timeout) — and also
  on any hard stop that happens while the PR is already open (§6) — swap it:
  `gh pr edit <n> --repo Theater-Dev/theater-viz --remove-label in-auto-review --add-label ready-for-human`.

## Copilot review loop

After the PR is open and labelled `in-auto-review`, shepherd it through Copilot review:

- WAIT by ACTIVELY POLLING IN-SESSION — a blocking loop you run right now: repeat up to
  ~20 times: `sleep 30`, then
  `gh pr view <n> --repo Theater-Dev/theater-viz --json reviews`; break as soon as a
  Copilot review with `submittedAt` newer than the head commit appears. If ~10 min
  elapse with no new review, note the timeout in a PR comment and exit the loop (treat
  as "done"). NEVER end your turn to "wait for a notification" — if you stop, the loop
  is abandoned and the PR is left unfinished.
- ADDRESS every comment with the SAME red→green discipline (§4) → reply signed per
  Attribution and resolve the thread. REST cannot resolve threads; use GraphQL — get
  the thread id from
  `gh api graphql -f query='{repository(owner:"Theater-Dev",name:"theater-viz"){pullRequest(number:<n>){reviewThreads(first:50){nodes{id isResolved comments(first:1){nodes{body}}}}}}}'`
  then
  `gh api graphql -f query='mutation($t:ID!){resolveReviewThread(input:{threadId:$t}){thread{id}}}' -f t=<thread-id>`.
- RE-REQUEST review (a push does NOT auto-trigger it):
  `gh api --method POST repos/Theater-Dev/theater-viz/pulls/<n>/requested_reviewers -f 'reviewers[]=copilot-pull-request-reviewer[bot]'` (the `[bot]` suffix is required).
- Repeat, ≤2 rounds. STOP on no actionable comments, after 2 rounds, OR on the poll
  timeout; note any still-open point for the human. On exit, do the PR-labels "loop
  exit" swap above.

## 6. Hard stops

If you cannot reproduce the finding (§4a), the QA pass will not go green, the fix needs
changes the issue did not approve, or anything is ambiguous: STOP, push your branch
as-is (work preserved), and leave a comment explaining why (for non-reproduction, begin
with "could not reproduce: "). What happens to the issue depends on whether a PR is
already open:

- **No PR yet** (the common case — stop happened before §5): do NOT open a PR, and move
  the issue **In progress → To Do** (adapter "to blocked") with the explanatory
  comment.
- **PR already open** (stop happened during the Copilot loop, so the PR carries
  `in-auto-review` and the issue is in **In progress**): the automated loop has given up
  and a human should look. LEAVE the issue in **In progress** — it has an open PR, so do
  NOT move it back to **To Do**. Just swap the PR labels (best-effort): remove
  `in-auto-review`, add `ready-for-human`, and leave the PR open.

## Forbidden

Merging PRs (`gh pr merge`), pushing to `main`, force-pushing, editing files outside
the workspace, unrelated refactoring, committing secrets, building headless Unity test
harnesses.

## Attribution

When you post a comment, sign it clearly as an automated fixer acting on behalf of
@vadym-vorotilin. Derive the exact GitHub login with `gh api user --jq .login` — NEVER
guess it or use an OS username; a wrong @mention pings a stranger.
