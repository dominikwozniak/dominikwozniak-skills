---
name: dw-resume
description: >-
  Deterministically resume the active run after a `/clear` or in a fresh
  session: read the persisted plan under `.ai/runs/` for the current branch and
  report where work stands, instead of reconstructing context from scrollback.
  Reports the goal, what is already done, the first not-done step (your resume
  point), and any blockers. Read-only — never edits files or code. Use when
  starting a session, after a `/clear`, or picking up paused work — or any time
  someone asks "where were we", "what's left", "where did I leave off",
  "resume", "pick up where I left off", or invokes "dw-resume".
---

# dw-resume — deterministically resume the active run

Reconstruct where work stands from the persisted run under `.ai/runs/`, keyed to
the current git branch — no scrollback, no central index. **Read-only:** it
reports the resume point and stops. It never edits `.ai/` artifacts or code
(flipping a step to `done` is `dw-build`; re-aligning a drifted plan is
`dw-sync`).

## What it reads

A "run" is a folder `.ai/runs/<id>/` (id = `<YYYYMMDD>-<ticket-or-slug>`) holding
some of:

- `PLAN.md` — frontmatter (`run/spec/status`) + the status table
  (`Phase | Step | Title | Status | Commit`). The resume point lives here.
- `SPEC.md` — frontmatter (`run/ticket/status/created/branch`) + a `## TLDR` (the
  goal).
- `NOTES.md` — append-only log; its tail carries the latest blockers / quirks.

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

### 2. Read the matched run

Read `SPEC.md` (goal + status), `PLAN.md` if present, and the tail of `NOTES.md`.
Read frontmatter tolerantly (trim quotes / whitespace, ignore trailing
`# comments`); treat any unreadable value as missing.

### 3. Report — branch on what exists

**PLAN.md present, table parseable** — columns are
`Phase | Step | Title | Status | Commit`; Status ∈ `todo`/`doing`/`done`/`blocked`.
The **resume point is the first row, top-to-bottom, whose Status ≠ `done`** (a
`doing` row is the resume point even if `todo` rows follow it — never skip ahead to
the first `todo`). Report:

- **Goal** — from SPEC's TLDR (or "unknown — no SPEC" if absent).
- **Done** — count + the `done` rows with their commit SHAs.
- **Resume point** — the first not-done row (Phase / Step / Title / Status). If that
  row is `blocked`, lead with it as a **BLOCKER**, not a step — surface the matching
  `NOTES.md` reason; the next move is to clear the blocker, not build.
- **Blockers** — any `blocked` row + recent `NOTES.md` entries.
- **Next:** continue building the resume step (e.g. via `dw-build`).
- **All rows `done`** → "Plan complete — all N steps done." Next: `dw-sync` (verify
  plan vs code) or open a PR. Don't invent a further step.

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

- **Read-only.** Never edit `.ai/` artifacts or code.
- **Branch-keyed, no index.** Identity is the git branch matched against run
  frontmatter — never a central index file.
- **Never silently guess.** Report only what the files state; mark anything missing as
  "unknown (not recorded)." If the run is ambiguous, say so and ask — don't pick a path
  for the user.
- **Tech-agnostic.** `dw-resume` itself needs only `git`; any build / verify commands
  belong to the `dw-build` / `dw-plan` it points to, which read them from the project.
