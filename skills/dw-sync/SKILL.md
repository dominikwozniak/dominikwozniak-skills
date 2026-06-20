---
name: dw-sync
description: >-
  Re-align the active run's `PLAN.md` with the real state of the code and git after
  manual edits or drift — the reconciler `dw-build` defers to. Reads the run's
  `PLAN.md` (branch-matched, like `dw-resume`), `git log` / `git diff`, and the code,
  then proposes a re-sync: flip `todo` / `doing` rows to `done` + short SHA where a real
  commit covers the step, append new rows with fresh ids for off-plan work, and flag
  `blocked` where code and plan diverge. The only `dw-planning` skill that mutates — it
  shows the plan diff and STOPS, applying only on your explicit word (per-row or batch),
  then appends a `NOTES.md` changelog. Never renumbers a committed step, and never flips
  a row without a commit verified in `git log`. Explicit-invoke only. Use when the plan
  has drifted from the code, or someone says "sync the plan", "re-sync plan to code",
  "re-align the plan", "reconcile plan with commits", or invokes "dw-sync".
argument-hint: "empty = re-sync the active run's plan to code; or name a run id"
disable-model-invocation: true
---

# dw-sync — reconcile the plan with the code, on your word

`dw-sync` is the reconciler of the loop. Plans drift: someone edits a row by hand, commits
work that no step anticipated, or finishes a step in a different shape than the plan
described. `dw-build` deliberately refuses to fix that — it flips only the row it just
built and leaves re-alignment to here. `dw-sync` reads the active run's `PLAN.md`, compares
it against what `git log` / `git diff` and the code actually say, and brings the two back
into agreement — never silently, always on your explicit word.

It is the counterpart to `dw-resume`: where `dw-resume` _reports_ the resume point
read-only, `dw-sync` _repairs_ the table that resume point is read from. And like
`dw-prune`, it is a mutator — so it proposes the change and STOPS, touching `PLAN.md` only
after you approve.

## What it reads and writes

- **Reads:** the active run's `PLAN.md` (status table + frontmatter) and `SPEC.md` (each
  step's acceptance, to judge whether a commit truly covers it); `git log` / `git diff` /
  `git show`; and the real files the steps touch. The commit convention
  (`## Git conventions`) is read **from the project**, never hardcoded — it only helps
  parse commit messages, and never decides a flip on its own.
- **Writes:** the reconciled `PLAN.md` (rows flipped to `done` + short SHA, new rows
  appended, divergences flagged `blocked`) and an appended `NOTES.md` changelog. It writes
  nothing until you consent, and it never runs tests or builds — this is bookkeeping under
  `.ai/`, not code.

## The immutability gate — a committed id is frozen

This is why `dw-sync` is its own skill, and its hardest rule:

> A step id carrying a SHA in the Commit column is **immutable** — never renumber it, never
> move its position. New work always gets a **new** id appended at the end of its phase,
> never an insertion that shifts an existing id.

Those ids are load-bearing: `NOTES.md` entries, commit messages, and your own memory all
reference "step 2.3". Renumber it and every one of those references silently points at the
wrong thing. So reconciliation is **append-and-flip**, never re-sequence. `dw-build` flips
Status/Commit and stops; `dw-sync` may also append rows and flag divergence — but the same
frozen-id discipline binds both. Status and Commit are bookkeeping you may correct; the id
and its order are not.

## Ground every change in a verified commit — the anti-hallucination invariant

The other half of the discipline, and the easy way to fool yourself: a re-sync is only as
trustworthy as the evidence under each row.

> No row flips to `done` without a **real commit, verified in `git log`, whose diff
> actually covers the step.** The SHA you write is one you read from git, never one you
> guessed. No reconciliation decision without a verified referent — step ↔ commit/diff.

A commit message that merely _mentions_ a step is not proof; the diff has to implement the
step's acceptance (the files it touches, the behavior it adds). Matching by message alone is
how a plan ends up confidently wrong. When you can't tie a row to a real commit, it does not
flip — it stays as it is, or it's flagged for the user, never invented.

## Workflow

### 1. Find the run (branch-matched, no index)

If `$ARGUMENTS` names a run id, use that run. Otherwise resolve it with
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/find-active-run.sh"` — it matches the current
git branch against each run's `SPEC.md` `branch:` field, prints the run directory
(newest wins when several match), and exits non-zero when none does.
`${CLAUDE_PLUGIN_ROOT}` is the env var Claude Code substitutes to this plugin's
install dir; the script ships with the plugin, not the project repo. Interpret its
result, stop at the first that applies:

1. **No `.ai/runs/` directory, or no run for this branch** → there's nothing to sync. If a
   `SPEC.md` exists but no `PLAN.md`, point to `dw-plan`; if neither, point to `dw-spec`.
   Stop.
2. **Detached HEAD** (branch resolves to the literal `HEAD`) → list every run with its
   recorded `branch:` and ask which to sync. Stop.
3. **Exactly one run matches** → use it.
4. **More than one matches** → use the newest by `<YYYYMMDD>` prefix; list the others so
   nothing is hidden. (Same-date tie → ask.)

`dw-sync` never creates a run and never moves one to `archive/` — that mv is a manual
lifecycle step, not its job. Never silently guess which run to sync.

### 2. Read the plan and the real state

Read `PLAN.md`'s status table (`Phase | Step | Title | Status | Commit`) and `SPEC.md` for
each step's acceptance. Then read what actually happened: `git log` (commits on this branch
since the run began), `git diff` (uncommitted working changes), and the files the steps
touch. You're building two pictures — what the plan claims, and what the code and history
show — so the next step can name every place they disagree.

### 3. Reconcile — flip, append, or flag (grounded in git)

Walk the gap between plan and reality. Every proposed change is one of three shapes, and
each rests on a verified referent (the invariant above):

- **Flip → `done` + SHA.** A `todo` / `doing` row whose step a real commit covers. Confirm
  the commit's diff implements the step's acceptance (`git show <sha>`), then propose
  flipping Status to `done` and writing that **short SHA** into Commit. A `doing` row with
  only uncommitted changes is not done — leave it `doing`.
- **Append a new row (fresh id).** Work that exists in git or the tree but no plan row
  describes. Propose a **new** row at the end of its phase with a fresh id (e.g. `2.4`),
  Status `done` + SHA if it's committed, or `doing` / `todo` if it's work-in-progress.
  Never renumber or reorder to make room — the immutability gate forbids it.
- **Flag a divergence (`blocked`).** Code and plan genuinely conflict: a step half-built, an
  approach that changed, or a `done` row whose recorded SHA is gone from `git log` (reverted
  work). Don't paper over it — propose marking the row `blocked` and record the conflict so
  the user decides. Flagging touches Status only, never the frozen id.

A row the plan and code already agree on needs no change — leave it. Manufacturing churn to
look busy is its own failure; "the plan already matches the code" is a complete, common
result.

### 4. Propose the re-sync — then STOP

Like `dw-prune`, the proposal and the mutation are two separate steps, and the second never
happens on its own. Present the re-sync as a legible plan diff:

- the rows to **flip**, each with the short SHA it will carry;
- the rows to **append**, each with its fresh id and status;
- the rows to **flag** `blocked`, each with the divergence in one line.

At this point `PLAN.md` is untouched. Ask how to proceed, offering **batch** (apply every
proposed change), **per-row** (name the rows, e.g. "flip 1.2 and 1.3, skip the append"), or
**none** (proposal only). Without explicit consent, write nothing — the proposal standing in
the conversation is a correct outcome. Never apply on silence, on inference, or on a vague
"looks good".

### 5. Apply the approved changes and log them

Apply only what was approved, editing `PLAN.md` in place — flip Status/Commit, append the
new rows, set `blocked` where flagged. Then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/plan-status.sh"
<PLAN.md>` to refresh the frontmatter `status:` from the table — it's _derived_ state (idempotent;
never hand-set the scalar). `${CLAUDE_PLUGIN_ROOT}` is an env var Claude Code substitutes to this
plugin's install dir; the script ships with the plugin, not the project repo. Then run
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/validate-ai-artifacts.sh" <run-dir>` to confirm the reconciled
`PLAN.md` still satisfies the structural schema (column shape, status enum, every done row's SHA) —
fix any reported error before logging. Then append a `NOTES.md` entry (newest at the bottom,
under a `## YYYY-MM-DD HH:MM` heading) recording what was reconciled: which rows flipped to
which SHA, which ids were appended, what was flagged and why. Mark any
proposed-but-unapproved change in the note as `proposed (not applied)`, so the record matches
what's on disk. This is the only step that mutates files.

Committing the reconciled `.ai/` artifacts is the user's call — `dw-sync` writes them and
stops, the same way `dw-build` leaves its bookkeeping for review. Never commit or push unless
asked.

### 6. Stop — report and point

Report what changed: rows flipped (id + SHA), rows appended, rows flagged `blocked`, and
anything left as proposed-only. Then point forward:

> **Next:** `dw-build` to build the next not-done step, or open a PR if every row is now
> `done`. After a `/clear`, `dw-resume` shows the refreshed resume point.

## The PLAN.md and NOTES.md shapes

`dw-sync` edits two files the run already owns — it never restructures them.

**`PLAN.md` status table** — columns `Phase | Step | Title | Status | Commit`; Status ∈
`todo` | `doing` | `done` | `blocked`; Commit holds the short SHA once a step lands. The
first row whose Status ≠ `done` is the resume point `dw-resume` reads. `dw-sync` flips
Status/Commit, appends rows with fresh ids, and flags `blocked` — never an id or a position
that already carries a SHA.

**`NOTES.md`** — an append-only log, newest entries at the bottom, each under a
`## YYYY-MM-DD HH:MM` heading. Record what each re-sync reconciled; don't rewrite earlier
entries.

## Guardrails

- **Reconcile by the Commit column.** A row flips to `done` only with a real commit, verified
  in `git log`, whose diff covers the step. Never flip on a guess or a message alone.
- **A committed id is frozen.** Never renumber or reorder a row that carries a SHA. New work
  gets a fresh id appended — never an insertion that shifts existing ids.
- **Propose, then STOP.** `dw-sync` mutates `PLAN.md`; it shows the plan diff and edits only
  on explicit consent (batch / per-row / none). Proposal-only is a complete outcome.
- **Validate after applying.** Once the approved edits land, `validate-ai-artifacts.sh` on the run
  dir must pass before you log and report — a schema error means the re-sync malformed the table.
- **Bookkeeping, not code.** Never run tests or builds, never create or archive a run, never
  commit or push unless asked. The work is `.ai/` reconciliation, nothing more.
- **Never silently guess.** Ambiguous run, a commit you can't tie to a step, a divergence you
  can't classify — name it and ask.
