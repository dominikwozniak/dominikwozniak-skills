---
name: dw-plan
description: >-
  Turn the active run's ready `SPEC.md` into a persistent, gated `PLAN.md`
  status table under `.ai/runs/` — thin vertical slices, each with acceptance
  criteria and a verify command read from the project. Presents the slice
  breakdown and HARD STOPS for approval before writing, so a wrong
  decomposition surfaces before it becomes the committed spine of the build.
  The PLAN.md it writes is the anchor `dw-resume` and `dw-build` read (first
  not-done row = resume point); step ids are immutable once committed. Use when
  a spec is ready and the work needs breaking into steps, or any time someone
  says "plan this", "break this into tasks", "turn the spec into a plan",
  "decompose the work", "make a build plan", or invokes "dw-plan". Reads stack
  and commands from the project — never assumes a framework.
---

# dw-plan — turn a ready spec into a persistent, gated plan

Convert the active run's `SPEC.md` into a `PLAN.md` the rest of the loop runs
on. The plan is a status table of thin vertical slices: `dw-resume` reads its
first not-done row as the resume point, and `dw-build` builds that row. Because
those consumers depend on it, the decomposition is presented for approval before
anything is written — and a step id never changes once that step has a commit.

## What it reads and writes

- **Reads:** the active run's `SPEC.md` (branch-matched, see below) and the
  codebase, **read-only** — you ground the plan in real files but change none.
- **Writes:** `.ai/runs/<id>/PLAN.md`, once, after the gate. Nothing else.

## Workflow

### 1. Find the run (branch-matched, no index)

Get the current branch: `git rev-parse --abbrev-ref HEAD`. Glob `.ai/runs/*/`
and read each run's frontmatter `branch:` (from `SPEC.md`) — the same branch
match `dw-resume` and `dw-handoff` use. Resolve in order and **stop at the first
that applies**:

1. **No `.ai/runs/` directory, or no run for this branch** → there's nothing to
   plan yet. Point to `dw-spec` to write a spec first. Stop.
2. **Detached HEAD** (branch resolves to the literal `HEAD`) → say so, list every
   run with its recorded `branch:`, ask which to plan. Stop.
3. **Exactly one run matches the branch** → use it.
4. **More than one matches** → use the newest by `<YYYYMMDD>` prefix; list the
   others so nothing is hidden. (Same-date tie → list both, ask.)

Never silently guess which run to plan — if it's ambiguous, name the candidates
and ask.

### 2. Read the spec — plan only when it is `ready`

Read the matched run's `SPEC.md` frontmatter `status`:

- **`ready`** → proceed.
- **`draft` or `open-questions`** → the spec isn't settled. Planning it now would
  decompose a moving target — the Open Questions could still reshape the scope.
  Stop and finish `dw-spec` first (answer its Open Questions), then come back.
- **No `SPEC.md`** in the run → point to `dw-spec`. Stop.

If `PLAN.md` **already exists** in the run, do not overwrite it. Committed step
ids are immutable, so silently regenerating the plan would orphan history and
break the resume point. Report that a plan exists, and point to `dw-resume` (to
see where work stands) or `dw-build` (to keep building). Re-planning a plan
that's already in flight is `dw-sync`'s job, not this skill's — surface it,
don't clobber. Stop.

### 3. Ground the plan in the code (read-only)

Before decomposing, read the repo so every step rests on something real — the
same anti-hallucination discipline `dw-spec`'s Approach uses:

- Open the sibling files, modules, and patterns the work will follow, and note
  them by path. Confirm each with `Read`/`grep` — never reference a file,
  module, or command you haven't verified exists.
- Find the project's verify commands (you'll put one in each step's acceptance).
  Read them **from the project**, never hardcode them: first a declared block
  (`## Commands` / `## Project specifics` in `CLAUDE.md` / `CLAUDE.local.md` /
  `AGENTS.md` — test / lint / typecheck / run), then manifests (`package.json`
  scripts, `Makefile`, `Gemfile` + `bin/`, `pyproject.toml`…), then the code
  itself. If a command can't be found, state the assumption and ask rather than
  inventing one.

### 4. Decompose into vertical slices

Break the spec's Scope into steps, not layers:

- **Vertical slices.** Each step is a thin, end-to-end change that leaves the
  system working — not "all the models" then "all the controllers". A slice a
  reviewer could merge on its own.
- **Small.** A step touches **≤5 files**. If it needs more, split it.
- **Stable ids.** Each step's id is `Phase.Step` (e.g. `1.1`, `1.2`, `2.1`).
  Once a step has a commit, the id is frozen — never renumber it. That immutability
  is what makes the first-not-done resume point deterministic.
- **Acceptance + verify per step.** Every step states what "done" looks like (an
  observable outcome) and the command that proves it — the verify command read
  from the project in step 3, not a generic placeholder.

Group related slices into phases, ordered so earlier phases unblock later ones.

### 5. Present the breakdown and wait — HARD STOP

Show the user the phase/step breakdown — ids, titles, the file(s) each touches,
and each step's acceptance + verify — and **stop**. Do not write `PLAN.md` yet.
This gate mirrors `dw-spec`'s: a wrong decomposition is cheap to fix as a list
and expensive to fix once it's the committed spine of the build. The instinct is
to write the file and move on — resist it here.

If the user adjusts the breakdown, revise and show it again. Only on explicit
approval, continue.

### 6. Write PLAN.md

Write `.ai/runs/<id>/PLAN.md` in the shape below. Frontmatter `run` matches the
run id, `spec: ./SPEC.md`, `status: todo`. Every step starts `todo` with an empty
Commit cell. Write nothing else — no code, no other files.

### 7. Stop

End with a one-line pointer so the next move is obvious:

> **Next:** `dw-build` to build the first not-done step (or `dw-build auto` to build the
> whole plan). After a `/clear`, `dw-resume` re-orients.

## The PLAN shape

Write exactly this shape (ids stay stable once committed):

```markdown
---
run: YYYYMMDD-ticket-or-slug
spec: ./SPEC.md
status: todo # todo | doing | done | blocked
---

# Plan — [title]

## Status table

The first row whose Status ≠ `done` is the resume point (`dw-resume`). Step IDs
are immutable once committed — never renumber a step that already has a commit.

| Phase | Step | Title                 | Status | Commit |
| ----- | ---- | --------------------- | ------ | ------ |
| 1     | 1.1  | [thin vertical slice] | todo   |        |
| 1     | 1.2  | [...]                 | todo   |        |

Status ∈ `todo` | `doing` | `done` | `blocked`. Commit = short SHA once the step
lands. The frontmatter `status:` is _derived_ from this table — `dw-build`/`dw-sync`
refresh it via `scripts/plan-status.sh`; write it `todo` here and never hand-set it again.

## Architecture decisions

- [decision + rationale]

## Risks

- [risk + mitigation]

## Verification checkpoints

- [after which step, what to run or observe — commands read from the project]
```

## Guardrails

- **Read-only until the gate.** You read the spec and the code to plan; you
  change no code and write no file before approval.
- **Never overwrite an existing `PLAN.md`.** Committed step ids are immutable;
  re-planning in flight is `dw-sync` territory — surface it, don't clobber.
- **Plan only a `ready` spec.** A draft or open-questions spec goes back to
  `dw-spec` first.
- **Commands come from the project**, never from this skill — verify steps
  against the project's real test / lint / run.
- **Never silently guess.** Ambiguous run, missing spec, unfound command — name
  it and ask.
