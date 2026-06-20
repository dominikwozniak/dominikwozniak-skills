---
name: dw-resume
description: >-
  Deterministically resume the active run after a `/clear` or in a fresh
  session: read the persisted plan under `.ai/runs/` for the current branch —
  and the quality pass under `.ai/verify/` — then report where work stands and
  the single next step across the whole loop, instead of reconstructing context
  from scrollback. Reports the goal, what is already done, the first not-done
  step (your resume point), the state of any review / verify / risk pass, and
  any blockers. Read-only — never edits files or code. Use when starting a
  session, after a `/clear`, picking up paused work, or asking "what next" — or
  any time someone asks "where were we", "what's left", "where did I leave off",
  "what should I do next", "resume", "pick up where I left off", or invokes
  "dw-resume".
---

# dw-resume — resume the active run and point to the next step

Reconstruct where work stands from the persisted run under `.ai/runs/` — and the
quality pass under `.ai/verify/` — keyed to the current git branch, with no
scrollback and no central index. **Read-only:** it reports the resume point and
the single next step, then stops. It never edits `.ai/` artifacts or code
(flipping a step to `done` is `dw-build`; re-aligning a drifted plan is
`dw-sync`; the review / verify / risk artifacts it reads are written by the
`dw-quality` skills).

## What it reads

A "run" is a folder `.ai/runs/<id>/` (id = `<YYYYMMDD>-<ticket-or-slug>`) holding
some of:

- `PLAN.md` — frontmatter (`run/spec/status`) + the status table
  (`Phase | Step | Title | Status | Commit`). The resume point lives here.
- `SPEC.md` — frontmatter (`run/ticket/status/created/branch`) + a `## TLDR` (the
  goal).
- `NOTES.md` — append-only log; its tail carries the latest blockers / quirks.

It also reads the **quality pass** in `.ai/verify/<branch-slug>/` — the artifacts
the `dw-quality` skills write — to recommend the next step once the plan is done.
The `<branch-slug>` is the current branch slugified the same way `dw-quality` uses
it (`ABC-123/password-reset` → `abc-123-password-reset`). It reads only what each
artifact literally states:

- `review.md` — the **Verdict** line
  (`request-changes` / `approve-with-comments` / `approve`).
- `verify-run.md` — the scenario verdicts (`PASS` / `FAIL` / `INCONCLUSIVE`).
- `conform.md`, `risk.md`, `explain.md` — presence and any verdict line.

**Their absence is normal** — it just means the quality pass hasn't started yet;
`dw-resume` is self-contained and never depends on a sibling having run.

## Workflow

### 1. Find the run (branch-matched, no index)

Get the current branch: `git rev-parse --abbrev-ref HEAD`. Glob `.ai/runs/*/` and
read each run's frontmatter `branch:` (from `PLAN.md`, else `SPEC.md`) — the same
branch match `dw-handoff` uses. Resolve in order and **stop at the first that
applies**:

1. **No `.ai/runs/` directory** → "no runs in this repo yet." Next: `dw-spec`. Stop.
2. **Detached HEAD** (branch resolves to the literal `HEAD`) → say so, list every
   run with its recorded `branch:`, ask which to resume. Stop.
3. **Exactly one run matches the branch** → use it (go to step 2).
4. **More than one matches** → use the newest by `<YYYYMMDD>` prefix; list the
   others so nothing is hidden. (Same-date tie → list both, ask.)
5. **Zero matches but runs exist** → don't guess. Name the run(s) and their
   recorded `branch:` (mark any run lacking `branch:` frontmatter as "unmatched")
   and ask which to resume. Stop.

### 2. Read the matched run — plan side and quality side

Read `SPEC.md` (goal + status), `PLAN.md` if present, and the tail of `NOTES.md`.
Read frontmatter tolerantly (trim quotes / whitespace, ignore trailing
`# comments`); treat any unreadable value as missing.

Then slugify the current branch and read whatever exists in
`.ai/verify/<branch-slug>/` — `review.md`'s **Verdict**, `verify-run.md`'s scenario
verdicts, and the presence of `conform.md` / `risk.md` / `explain.md`. An empty or
absent folder is fine. Parse only what each file literally states; mark anything
missing or unparseable as "not recorded" — never infer a verdict.

### 3. Report — branch on what exists

**PLAN.md present, table parseable** — columns are
`Phase | Step | Title | Status | Commit`; Status ∈ `todo`/`doing`/`done`/`blocked`.
The frontmatter `status:` is _derived_ from this table, so verify it (read-only) with
`bash "${CLAUDE_PLUGIN_ROOT}/scripts/plan-status.sh" --check <PLAN.md>` — `${CLAUDE_PLUGIN_ROOT}`
is an env var Claude Code substitutes to this plugin's install dir, and `--check`
**writes nothing**. On drift, lead the report with a one-line warning ("PLAN frontmatter
says `<x>` but the table implies `<y>` — heal via `dw-build` / `dw-sync` / `plan-status.sh`");
the table stays authoritative for the resume point regardless.
The **resume point is the first row, top-to-bottom, whose Status ≠ `done`** (a
`doing` row is the resume point even if `todo` rows follow it — never skip ahead to
the first `todo`). Report:

- **Goal** — from SPEC's TLDR (or "unknown — no SPEC" if absent).
- **Done** — count + the `done` rows with their commit SHAs.
- **Resume point** — the first not-done row (Phase / Step / Title / Status). If that
  row is `blocked`, lead with it as a **BLOCKER**, not a step — surface the matching
  `NOTES.md` reason; the next move is to clear the blocker, not build.
- **Blockers** — any `blocked` row + recent `NOTES.md` entries.
- **Next** (plan incomplete) — continue building the resume step via `dw-build`. If a
  `review.md` or `verify-run.md` already exists from an earlier pass, note it as
  context, but building the remaining steps comes first.
- **Next** (all rows `done`) — the plan is complete, so the **quality pass** drives the
  next step. Read `.ai/verify/<branch-slug>/` and recommend the first that applies:
  - **no `.ai/verify/` artifacts** → start the quality pass: `dw-review` (and/or
    `dw-explain`).
  - **`review.md` verdict = `request-changes`** → address the findings first (lead with
    the critical / high count); don't advance past an unresolved review.
  - **review clean, no `verify-run.md`** → `dw-explain` → `dw-verify` to prove it runs.
  - **`verify-run.md` has any `FAIL` / `INCONCLUSIVE`** → fix and re-verify; lead with
    the failing scenario.
  - **all scenarios `PASS`, review clean, no `risk.md`** → `dw-risk` for blast radius.
  - **`risk.md` present and everything green** → open a PR (`dw-git`, or your own
    tooling); run `dw-sync` first if the plan has drifted from the code.

  Recommend only what the artifacts state — an empty quality folder is itself the signal
  to start reviewing, never a reason to call the change shippable.

**SPEC.md only (no PLAN.md)** — the spec exists but isn't planned yet. Report its
`status` and goal:

- `ready` → **Next:** `dw-plan` to break the spec into a `PLAN.md`.
- `open-questions` / `draft` → the spec still has unanswered Open Questions;
  **Next:** finish `dw-spec` before planning.
- any other / missing `status` → report the raw value and recommend finishing
  `dw-spec`; don't map an unknown status onto a Next action.

**Neither SPEC.md nor PLAN.md** (only `NOTES.md`, or empty), **or PLAN.md present but
its table is missing / header-only / not the expected columns** → say exactly that,
fall back to whatever exists (SPEC status, NOTES tail), and recommend `dw-spec` /
re-running `dw-plan`. Never fabricate a goal or a resume point.

### 4. Stop

Report and hand off. `dw-resume` writes nothing — acting on the resume point is
`dw-build`'s job.

## Guardrails

- **Read-only.** Never edit `.ai/` artifacts or code. (Running `plan-status.sh --check` is
  fine — it only reads and reports; the bare, mutating form is `dw-build`/`dw-sync`'s job.)
- **Branch-keyed, no index.** Identity is the git branch matched against run
  frontmatter — never a central index file.
- **Never silently guess.** Report only what the files state; mark anything missing as
  "unknown (not recorded)." If the run is ambiguous, say so and ask — don't pick a path
  for the user.
- **Quality reads are tolerant and optional.** Read only what `.ai/verify/` artifacts
  literally state (the `Verdict` line, the PASS / FAIL rows); an absent folder is normal,
  not a failure. Never fabricate a verdict or treat an empty quality folder as
  "shippable".
- **Tech-agnostic.** `dw-resume` itself needs only `git`; any build / verify commands
  belong to the `dw-build` / `dw-plan` it points to, which read them from the project.
