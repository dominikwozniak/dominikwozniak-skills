# Workflows

How to actually _use_ these skills day to day — the loop, the recipes for common
situations, and the decisions you'll hit along the way. The [README](../README.md) is the
index (what each skill is, one row each); [`DESIGN.md`](DESIGN.md) is the _why_; this is
the _how_.

---

## Philosophy in one line

The recipes below rest on five ideas — persistence in the skill (not a wrapper), a tracked `.ai/`
folder per task, `file:line` grounding, a human gate over an autonomous loop, and
composable-not-chained skills. The full argument is in [`DESIGN.md`](DESIGN.md); the failure modes
each one answers — mapped to the skill that kills each — are in the
[README](../README.md#-why-these-skills-exist).

---

## The canonical loop

```
  SPEC         PLAN         BUILD                   REVIEW · VERIFY           SHIP
  /dw-spec  →  /dw-plan  →  /dw-build       →       /dw-review  /dw-explain → (open PR — your own tooling)
                          ↺ /dw-resume (pick up)    /dw-conform /dw-verify
                            /dw-sync (fix drift)    /dw-prune   /dw-risk
  └────────────── .ai/runs/<id>/ ──────────────┘    └─ .ai/verify/<branch-slug>/ ─┘
```

Two artifact homes anchor the loop:

- **`.ai/runs/<id>/`** — the planning + build half. `SPEC.md` (the goal + open questions),
  `PLAN.md` (the status table whose first not-`done` row is the resume point), `NOTES.md`
  (an append-only log). One self-contained folder per task; the `<id>` is a date-stamped
  slug, so parallel branches and worktrees never collide.
- **`.ai/verify/<branch-slug>/`** — the quality half. `review.md`, `conform.md`,
  `explain.md`, `verify-run.md`, `risk.md`, `fix.md` — one file per axis, named for the
  current branch. `<branch-slug>` is the branch slugified, e.g.
  `ABC-123/password-reset` → `abc-123-password-reset`.

**SHIP — deciding when to open the PR, and the deploy/CI after — is intentionally outside
this toolkit.** The loop hands you a reviewed, verified change; opening the PR is your call
and your tooling.

The arrows are a _recommendation, not a rail_. Every skill is invoked on its own when you
need it; they cohere because they read each other's `.ai/` artifacts, not because a
conductor drives them.

---

## Scenario recipes

Each recipe: when you reach for it, what it reads and writes, and where it points next.

### 1. Start a feature

- **Trigger:** "spec this out", "write a spec", or `/dw-spec`.
- **Flow:** `dw-spec` opens `SPEC.md` under `.ai/runs/<id>/` with a skeleton plus numbered
  **Open Questions (HARD STOP)** — it will not plan or code until you answer the ones where
  a wrong assumption forces a rewrite.
- **Artifact:** `.ai/runs/<id>/SPEC.md` (frontmatter `status: draft → open-questions →
ready`).
- **Next:** once the spec is `ready`, `/dw-plan`.

### 2. Resume after a `/clear` or in a fresh session

- **Trigger:** "where were we", "what's left", "resume", or `/dw-resume`.
- **Flow:** `dw-resume` matches the current git branch to a run's `SPEC.md` `branch:`,
  reads `PLAN.md`, and reports the goal, what's `done`, the **first not-`done` step** (your
  resume point), and the state of any quality pass under `.ai/verify/`. Read-only — it never
  edits anything.
- **Artifact:** none written; a status report.
- **Next:** `/dw-build` for that step. (You usually know the next step yourself — `dw-resume`
  shines after a long gap or a context reset, not as a step you run on every transition.)

### 3. Turn a spec into a plan

- **Trigger:** "plan this", "break this into tasks", or `/dw-plan`.
- **Flow:** `dw-plan` decomposes a `ready` spec into **thin vertical slices**, each with
  acceptance criteria and a verify command read from the project. It presents the
  breakdown and HARD-STOPS for approval before writing — a wrong decomposition surfaces
  before it becomes the committed spine of the build.
- **Artifact:** `.ai/runs/<id>/PLAN.md` — the status table `Phase | Step | Title | Status |
Commit`. Step ids are immutable once committed.
- **Next:** `/dw-build`.

### 4. Build the next step

- **Trigger:** "build the next step", "implement the plan", or `/dw-build` (`auto` for the
  whole plan).
- **Flow:** builds the first not-`done` row end-to-end — **RED** (a failing verify) →
  **GREEN** (make it pass) → **regression** (broader test + lint) → **commit** (one logical
  change) → **mark-done** (flip the row to `done` + short SHA, append `NOTES.md`). Stops
  before anything irreversible even in `auto`.
- **Artifact:** code + tests; the `PLAN.md` row flipped; `NOTES.md` appended.
- **Next:** `/dw-build` again, or once every row is `done`, prove and review it.

### 5. Prove it works (explain → verify)

- **Trigger:** "how do I prove this works", then "verify this change".
- **Flow:** `dw-explain` writes runnable, code-grounded verification **scenarios**;
  `dw-verify` executes them with the project's own commands and records the **actual
  output** — it never reports PASS without captured evidence. This is the one true chain in
  the catalog: verify reads explain's scenarios.
- **Artifact:** `.ai/verify/<branch-slug>/explain.md` → `verify-run.md`.
- **Next:** `/dw-review`, or open a PR.

### 6. Review before a PR

- **Trigger:** "review my PR", "code review", "does this match our patterns", or
  `/dw-review` · `/dw-conform` · `/dw-risk`.
- **Flow:** read-only auditors, each a different axis (see _Decision points_ below). Each
  resolves the change three ways — working diff, branch vs base, or a PR via `gh pr diff` —
  and writes a verdict plus findings, every finding a real `file:line` + severity + a
  concrete fix.
- **Artifact:** `.ai/verify/<branch-slug>/{review,conform,risk}.md`.
- **Next:** if there are findings, `/dw-fix`.

### 7. Fix the findings

- **Trigger:** "fix the findings", "address the review", or `/dw-fix`.
- **Flow:** `dw-fix` is the **single writer** in the quality pipeline — the auditors only
  diagnose. It reads `review.md` / `conform.md` / `risk.md`, fixes each finding
  severity-ordered (one commit per fix), and marks it resolved. It's severity-gated:
  `blockers` clears the critical/high findings and **stops for a re-audit**, so downstream
  checks never run against code a review already flagged broken. It issues no verdict —
  re-running the auditor on the fixed code is what confirms it's clean.
- **Artifact:** code commits + `.ai/verify/<branch-slug>/fix.md`.
- **Next:** re-audit (required after blockers, optional after a medium/low-only pass).

### 8. Reconcile drift

- **Trigger:** "sync the plan", "reconcile plan with commits", or `/dw-sync` (explicit-only).
- **Flow:** when the plan and the code disagree — a hand-edited row, off-plan commits, a
  step finished in a different shape — `dw-sync` compares `PLAN.md` against `git log` /
  `git diff` and **proposes** a re-sync (flip rows to `done` + SHA, append new rows with
  fresh ids, flag divergence `blocked`), then **STOPS**. It applies only on your explicit
  word and never flips a row without a commit verified in `git log`.
- **Artifact:** reconciled `PLAN.md` + `NOTES.md` changelog (consent-gated).
- **Next:** `/dw-build` for the next not-`done` step.

---

## Decision points

**Review vs conform vs risk — three different questions about one change:**

| Skill        | Asks                                                                                           | Reads                                |
| ------------ | ---------------------------------------------------------------------------------------------- | ------------------------------------ |
| `dw-review`  | Is the change itself good? (correctness · readability · architecture · security · performance) | the diff                             |
| `dw-conform` | Does it match the repo's **existing, pre-committed** patterns?                                 | the diff + its sibling files         |
| `dw-risk`    | What's the **blast radius** and out-of-code impact? rollback?                                  | the diff + review/conform if present |

They're independent axes — run the ones that fit. `dw-risk` reads whatever neighbours exist
and closes the pipeline.

**When to `dw-sync`** — only when the plan has genuinely drifted from the code. It's _not_ a
step you run on every transition; `dw-build` keeps the row it just built in sync on its own.
Reach for `dw-sync` after manual edits, off-plan commits, or a reverted SHA. "The plan
already matches the code" is a complete, common result.

**`dw-fix` is the only writer in the quality half.** The auditors (`dw-review`,
`dw-conform`, `dw-explain`, `dw-verify`, `dw-risk`) are read-only by design — an auditor
that also patched things would be tempted to under-report what it couldn't fix. Diagnosis
and treatment are separate skills.

**Explicit-invoke-only skills** never auto-fire — say their name: `dw-bootstrap`,
`dw-handoff`, `dw-prune`, `dw-sync`, `dw-setup-precommit`. They scaffold a repo, install
shared tooling, compact or mutate state, or act on an explicit drift signal — so the model
shouldn't reach for them unbidden. Everything else can be model-invoked when the task fits.

---

## Quick reference

The full skill-to-task map — every skill, its trigger phrases, and what it outputs — is the
[**task-router table in the README**](../README.md#-task-router--which-skill-for-which-task).
This guide is the narrative; that table is the lookup.

Setup once per repo: `/dw-bootstrap` (scaffold), `/dw-doctor` (read-only health check),
`/dw-setup-precommit` (git-level hooks). Anytime: `/dw-git` (all git ops by your
conventions), `/dw-handoff` (compact the session for the next agent).
