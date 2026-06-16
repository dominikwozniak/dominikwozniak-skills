---
name: dw-explain
description: >-
  After implementing a change, explain what it does and generate runnable,
  code-grounded verification scenarios — written to `.ai/verify/` so a later
  pass (`dw-verify`) can execute them. Resolves the change three ways (working
  diff, a branch against its base, or a PR via `gh pr diff`), reads the
  project's own test/run/db commands instead of assuming a stack, and anchors
  every scenario to a real referent (a route, a column, a file) — never a
  fabricated command. Use when you have just written or reviewed code, or whenever
  someone says "explain this change", "explain the diff", "what does this PR
  do", "how do I prove this works", "write verification scenarios", "walk me
  through what changed", or invokes "dw-explain". Prefer this over an ad-hoc
  verbal summary whenever a change needs explaining or checking.
argument-hint: "Which change should I explain? (diff, branch, or PR)"
---

# dw-explain — explain the change, then generate runnable verification scenarios

You just implemented (or reviewed) a change. The valuable next step is to explain
**what it does** and lay out **how to prove it works** — but that thinking usually
evaporates into the conversation and gets reinvented from scratch in the next
session, or at review time. This skill captures it as a durable artifact:
`explain.md`, holding the intent, the mechanism, and a set of **runnable,
code-grounded verification scenarios**. That artifact is exactly what `dw-verify`
later opens and executes — so the scenarios you write here must actually run.

The whole point is **runnable, not plausible**. A scenario that looks right but
references a route, column, or command that doesn't exist is worse than no
scenario — it sends the next pass chasing a ghost. Hence the one hard rule below.

## Output location

Write to `.ai/verify/<branch-slug>/explain.md`. `.ai/` is tracked in git —
verification artifacts are real work documentation, committed alongside the code.

- Branch: `git rev-parse --abbrev-ref HEAD`. Slugify it for the folder name
  (e.g. `ABC-123/password-reset` → `abc-123-password-reset`).
- `mkdir -p .ai/verify/<branch-slug>` before writing.

**Connector — read your neighbours first.** The whole `dw-quality` cluster writes
to this same folder. If `review.md` (from `dw-review`) or `conform.md` (from
`dw-conform`) already sit beside your target, **read them before you start** —
they tell you what a reviewer already flagged as risky or non-conforming, which is
precisely where your P0 scenarios should concentrate. Their absence is fine;
`dw-explain` is self-contained and never depends on another skill having run.

## Resolve the change (three input shapes)

The request — which change, and what to focus on — may arrive as `$ARGUMENTS`.
Accept any of three shapes; pick by what the user pointed at, else default to the
working diff:

1. **Working diff** (default): uncommitted + committed work on this branch vs its
   base — `git diff $(git merge-base HEAD <base>)` (base is usually `main`; read it
   from the project's git conventions if declared).
2. **Branch vs an explicit base**: when the user names a base — `git diff <base>...HEAD`.
3. **PR**: when the user points at a pull request — `gh pr diff <number>` (or
   `gh pr diff` on the current branch's PR).

Read the actual diff. Everything downstream is grounded in these hunks, not in
your memory of what you wrote.

## Read the project's commands (don't hardcode a stack)

Scenarios are **runnable** only if the commands are the project's real commands.
Never assume a framework or invent a runner. Discover in this order:

1. **Declared block** — `## Commands` / `## Project specifics` in `CLAUDE.md`,
   `CLAUDE.local.md`, or `AGENTS.md` (test / lint / run / db-console / server URL /
   run-snippet). Reuse whatever the project already documents.
2. **Manifests / scripts** — `package.json` scripts, `Gemfile` + `bin/`,
   `Makefile`, `Procfile`, `composer.json`, `pyproject.toml`, … Their presence is
   also how you detect the stack (Gemfile → Ruby, package.json → Node, go.mod → Go).
3. **The code itself** — when neither declares it, infer from the code you can read.

If a command can't be resolved, **state the assumption you're making** and ask when
it's genuinely ambiguous — exactly like a fallback in `git-workflow`. Never guess a
command silently and never paper over the gap with a made-up one; an unresolved
command makes its scenario an open question (section E), not a fabrication.

The scenario **types** below are a fixed, technology-agnostic taxonomy. The
**command** that realises a given type is always resolved from the project.

## The anti-hallucination invariant

**No line in `explain.md` without a verified referent.** Every scenario — every
command, route, column, table, file path you write down — must trace to something
that demonstrably exists in _this_ change or _this_ repo:

- an HTTP scenario → a route you found in the router / routes file;
- a db scenario → a column or table you found in the schema or a migration in the diff;
- a file or function you name → opened via `Read` (or present in the diff hunks);
- a command → resolved from the project per the section above.

If you cannot ground a scenario — the referent isn't there, or the command can't be
resolved — it does **not** become a confident-looking guess. It goes to **section E
(Open questions)**, flagged as something to confirm. This is the line between an
artifact `dw-verify` can trust and one that wastes its time. When in doubt, demote
to E rather than assert.

## Workflow

### 1. Resolve the diff and read neighbours

Pick the input shape (above), read the diff, read the project's command sources,
and read any `review.md` / `conform.md` already in the target folder. Note which
files, routes, columns, and behaviours actually changed — this is your referent
set for the rest of the run.

### 2. A — Intent (what changed, and why)

A plain-language summary: what this change is for, from the user's / caller's point
of view. One or two sentences. Not a restatement of the diff — the _purpose_.

### 3. B — How it works

The mechanism, grounded in the diff: the path a request/value takes through the
changed code, the key functions or modules touched, and any non-obvious decision a
future reader would otherwise have to reverse-engineer. Cite real paths.

### 4. C — Prove it works (runnable scenarios — the payload)

The core of the artifact. Derive scenarios that, run together, would convince a
skeptic the change works. Each scenario is:

- **Typed** — one of `db` / `http` / `cli` / `console` / `test` (add `browser`
  when the change is user-facing UI). The taxonomy is agnostic; the command comes
  from the project.
- **Prioritised** — `P0` (the core path; if this fails the change is broken),
  `P1` (important behaviour / main edge), `P2` (nice-to-have, secondary edge).
- **Concrete** — a real, project-resolved command **plus its expected result**.
  "Expected" is what makes it verifiable: the row returned, the status code, the
  output line, the assertion that passes.

Apply the invariant to every scenario as you write it. Anything you can't ground
moves to section E. See `references/scenario-taxonomy.md` for what each type covers,
the referent that grounds it, and how to write a good expected result; see
`references/examples-by-stack.md` for fully worked (illustrative) examples.

### 5. D — Edge cases · E — Open questions

- **D — Edge cases**: boundaries and failure modes the change should handle
  (empty input, auth failure, concurrent write, null, limit) — grounded the same way.
- **E — Open questions**: scenarios you couldn't ground, commands you couldn't
  resolve, and assumptions you had to make. This section is a feature, not an
  admission — it's where honesty about the limits of static analysis lives.

### 6. Write `explain.md` and finalize

Copy the shape from `references/explain.md`, fill A–E, and write it to
`.ai/verify/<branch-slug>/explain.md`. Keep it lean — it's a working artifact, not
a report.

End by telling the user where it landed and the connector line:

> **Next:** consider `dw-verify` — it reads these scenarios and runs them,
> recording actual vs expected.

## The explain.md shape

`references/explain.md` is the exact shape to copy: light frontmatter
(`branch` / `base` / `input` / `created`) plus **A. Intent · B. How it works ·
C. Prove it works · D. Edge cases · E. Open questions**. The scenario block in C is
a small table (type · priority · command · expected · referent) so `dw-verify` can
walk it row by row.

## References

- `references/explain.md` — the artifact template. Copy this shape every run.
- `references/scenario-taxonomy.md` — read when deriving section C: the scenario
  types, the referent that grounds each, the P0/P1/P2 rubric, and the
  expected-output discipline.
- `references/examples-by-stack.md` — worked Rails and Node examples. Illustrative
  only: read to see the referent → scenario → expected pattern, never to copy a
  stack — the stack always comes from the project in front of you.
