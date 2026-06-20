---
name: dw-build
description: >-
  Build the active run's plan one step at a time. Take the run's `PLAN.md`, build the
  first not-done row as a single thin slice end-to-end: RED (failing verify), GREEN
  (make it pass), regression (broader test + lint), commit one logical change, then
  flip the row to `done` + short SHA and append `NOTES.md`. Reads the step's
  acceptance from the plan and `SPEC.md`, the files it touches, and the project's own
  test / lint / run commands and `## Git conventions` — never assuming a framework or
  a commit format. Builds one step by default; `auto` runs the whole plan, still
  pausing before any irreversible action (migration, drop, deploy, force-push,
  production data). Never renumbers a committed step — that is `dw-sync`'s job. Use
  when a `PLAN.md` exists and it is time to build the next step, or any time someone
  says "build the next step", "implement the plan", "build this", "continue the
  build", or invokes "dw-build". Prefer this over ad-hoc coding whenever a run's plan
  is the source of truth.
argument-hint: "empty = next not-done step; 'auto' = build the whole plan"
---

# dw-build — build the first not-done step, RED to GREEN to commit

`dw-build` is the executor of the loop. It reads the active run's `PLAN.md`, builds
the **first not-done step** end-to-end, and records the result back into the plan so
the next session (or `dw-resume`) sees exactly where things stand. It is the mirror
of `dw-resume`: where `dw-resume` _reports_ the resume point read-only, `dw-build`
_builds_ it and flips the row. One step at a time by default — `auto` runs the whole
plan.

The discipline is RED → GREEN → regression → commit → mark-done, one commit per step.
That cadence is what keeps the plan and the code in sync: every `done` row carries the
short SHA that landed it.

## What it reads and writes

- **Reads:** the active run's `PLAN.md` (the first not-done row) and `SPEC.md` (the
  step's acceptance), the real files the step touches, and — **from the project, never
  hardcoded** — the test / lint / run commands and the commit convention
  (`## Git conventions`).
- **Writes:** the step's code and tests; the `PLAN.md` row flipped to `done` + short
  SHA (and its frontmatter `status:` refreshed from the table by the bundled `plan-status.sh`);
  an appended `NOTES.md` entry. One logical change per commit.

## Workflow

### 1. Find the run (branch-matched, no index)

Get the current branch: `git rev-parse --abbrev-ref HEAD`. Glob `.ai/runs/*/` and read
each run's frontmatter `branch:` (from `PLAN.md`, else `SPEC.md`) — the same match
`dw-resume` and `dw-plan` use. Resolve in order, stop at the first that applies:

1. **No `.ai/runs/` directory, or no run for this branch** → there's nothing to build
   yet. If a `SPEC.md` exists but no `PLAN.md`, point to `dw-plan`; if there's no spec
   either, point to `dw-spec`. Stop.
2. **Detached HEAD** (branch resolves to the literal `HEAD`) → say so, list every run
   with its recorded `branch:`, ask which to build. Stop.
3. **Exactly one run matches** → use it.
4. **More than one matches** → use the newest by `<YYYYMMDD>` prefix; list the others
   so nothing is hidden. (Same-date tie → list both, ask.)

Never silently guess which run to build.

### 2. Pick the step (first not-done — deterministic)

Read `PLAN.md`'s status table (`Phase | Step | Title | Status | Commit`). The step to
build is the **first row, top-to-bottom, whose Status ≠ `done`** — the exact rule
`dw-resume` reports as the resume point. Branch on what that row is:

- **All rows `done`** → the plan is complete. Don't invent a further step. Report it
  and point to `dw-verify` (prove the change) or `dw-review`, or open a PR. Stop.
- **Row is `blocked`** → lead with the blocker, not the build. Surface the matching
  `NOTES.md` reason and ask how to clear it. Never build through a block.
- **Row is `doing`** (an interrupted step) → resume _that_ row. Don't skip ahead to the
  next `todo`.
- **Row is `todo`** → that's your step.

### 3. Ground the step in the code (read before write)

Same anti-hallucination discipline as `dw-spec` and `dw-plan` — every action rests on
something real:

- Read the step's **acceptance + verify** from its `PLAN.md` row and the `SPEC.md`.
  Open the actual files the step touches and confirm each with `Read` / `grep` — never
  edit a file you haven't opened.
- Resolve the project's **commands** (don't assume a stack), in order: a declared block
  (`## Commands` / `## Project specifics` in `CLAUDE.md` / `CLAUDE.local.md` /
  `AGENTS.md` — test / lint / run), then manifests (`package.json` scripts, `Gemfile` +
  `bin/`, `Makefile`, `pyproject.toml`…), then the code itself.
- Resolve the **commit convention** the same way — from `## Git conventions` in the
  project. Fall back to defaults only if none is declared: Conventional Commits
  (`type: description`, or `[TICKET-123] type: description` when the branch encodes a
  ticket), no `Co-Authored-By` or generated-by footer, a plain `git commit` (signing is
  the project's concern — never add `-S` or reconfigure it).

If a command or convention can't be found, **state the assumption and ask** — never
invent one.

### 4. Build the step — RED → GREEN → regression → commit → mark-done

The heart of the skill. One step, one cycle:

- **(optional) flip to `doing`.** Mark the row `doing` while you work, so an interrupted
  build shows as mid-flight rather than untouched.
- **RED.** Write or run the step's verify (the project's test command) and watch it
  **fail**. A check that passes before you've built anything proves nothing — it isn't
  anchored to the new behavior.
- **GREEN.** Implement the thin slice — the plan already sized it to **≤5 files** —
  until the verify passes. Touch only what the step needs; resist cleaning up adjacent
  code (that's scope creep, and it muddies the commit).
- **regression.** Run the broader test suite and lint (project commands) so the slice
  didn't break anything outside itself.
- **commit.** **One logical change**, message per the project's `## Git conventions`
  (resolved in step 3). Plain `git commit` — it auto-signs; never add `-S` or "fix"
  signing. Capture the short SHA with `git rev-parse --short HEAD`.
- **mark-done.** Flip the row's Status to `done` and write that short SHA into the
  Commit column, then run `bash "${CLAUDE_PLUGIN_ROOT}/scripts/plan-status.sh" <PLAN.md>` to refresh
  the frontmatter `status:` from the table — you own the row, the script owns the scalar (it's
  _derived_; idempotent; never hand-edit it). `${CLAUDE_PLUGIN_ROOT}` is an env var Claude Code
  substitutes to this plugin's install dir; the script ships with the plugin, not the project repo. Append a `NOTES.md` entry (newest at the bottom) recording what landed,
  any decision worth keeping, and follow-ups. The recorded SHA is the _code_ commit's —
  land the plan/notes bookkeeping as a small follow-up commit or leave it staged for
  review, but never amend the code commit to fold it in.

Step ids are immutable: you change a row's **Status and Commit only**, never its id or
its position in the table.

### 5. Mode — one step, or the whole plan (`$ARGUMENTS`)

- **Empty (default)** → build **one** step, then stop with the Next pointer below. The
  pause is deliberate: it's where a human eyeballs the slice before the next one builds
  on it.
- **`auto`** → after marking a step `done`, pick the next not-done row and repeat — no
  pause _between_ steps — until every row is `done`, a verify can't be made to pass, or
  regression fails. The stop-and-ask guard (next section) still fires inside `auto`.

Read the mode from `$ARGUMENTS`: treat `auto` as whole-plan mode, a specific step id as
"build that one", and anything else (including empty) as the default single-step mode.

### 6. Stop-and-ask on irreversible actions (hard guard)

Some actions a `git revert` can't undo: schema migrations, `DROP` / `TRUNCATE`, data
backfills, deploys, force-pushes, anything touching production data or an external
service. Before any of these — **even in `auto`** — stop, name the action, and ask.
`auto` only removes the pause _between_ steps; it never removes this guard. (Same spirit
as `dw-verify`'s mutation guard.)

### 7. Stop — report and point

After the step (or after `auto` finishes / a guard trips), report which step landed
(id + short SHA), what the verify showed, and the regression result. Then:

> **Next:** `dw-build` for the next step — or `dw-build auto` to finish the remaining steps
> unattended (it still stops before anything irreversible). `dw-verify` proves the change
> works; `dw-sync` if the plan has drifted. After a `/clear` or if you've lost the thread,
> `dw-resume` re-orients.

## The PLAN.md and NOTES.md shapes

`dw-build` edits two files the run already owns — it never restructures them.

**`PLAN.md` status table** — columns `Phase | Step | Title | Status | Commit`;
Status ∈ `todo` | `doing` | `done` | `blocked`; Commit holds the short SHA once the step
lands. The first row whose Status ≠ `done` is the resume point. Step ids are frozen once
committed — `dw-build` flips Status / Commit, nothing else. The frontmatter `status:` is
_derived_ from this table (`plan-status.sh`: any `blocked` → `blocked`; else all
`done` → `done`; else any started → `doing`; else `todo`) — never hand-edit it.

**`NOTES.md`** — an append-only log, newest entries at the bottom, each under a
`## YYYY-MM-DD HH:MM` heading. Capture decisions, blockers, and surprises; don't rewrite
earlier entries.

## Guardrails

- **Build the first not-done step only** (in `auto`, each in turn) — never skip ahead or
  reorder.
- **Read before write.** Open the real files; resolve commands and the commit convention
  from the project. Never edit an unopened file or invent a command.
- **RED before GREEN.** A verify that passes before you build is not anchored to the
  step — make it fail first.
- **One logical change per commit**, message per the project's `## Git conventions`;
  plain commit auto-signs (never `-S`, never reconfigure signing).
- **Never renumber a committed step.** `dw-build` only flips Status / Commit; re-aligning
  a drifted plan is `dw-sync`'s job.
- **Stop-and-ask on irreversible actions** — a hard guard, independent of `auto`.
- **Never silently guess.** Ambiguous run, unfound command, `blocked` row — name it and
  ask.
