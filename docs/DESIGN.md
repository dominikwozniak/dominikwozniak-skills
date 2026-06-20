# Design notes

Why these skills are built the way they are. The [README](../README.md) gives the short version;
this is the longer rationale.

## The failure modes these skills target

Agentic coding fails in recognisable ways, and each design choice below is a direct answer to one of
them. The [README](../README.md#-why-these-skills-exist) maps each failure mode to the skill that
kills it; the sections below explain _why_ the skills are shaped the way they are to make those
guarantees hold.

## Persistence lives in the skill, not a wrapper

Each `SKILL.md` bakes its own `.ai/` output paths into its procedure. There is no
`.claude/commands/` glue layer translating intent into a file location. Plans and reviews land on
disk automatically and travel with the installed plugin — surviving a `/clear`, a new session, or a
handoff to another agent. This is the core problem the catalog solves: a workflow whose plan only
ever lives in the model's context is one you cannot reliably resume or verify.

## `.ai/` is tracked, one folder per task, no central index

Artifacts are real work documents, committed alongside the code they describe — not throwaway
scratch. The layout is deliberate:

- **No shared index file.** A central registry becomes a merge-conflict magnet once tracked.
  Discovery is by directory name + per-file frontmatter, so two branches never contend for one file.
- **One self-contained folder per task** (`.ai/runs/<id>/`) with a unique slug — parallel branches
  and worktrees don't collide.
- **Branch-matched resume.** A run records its branch in frontmatter; resume globs runs, matches the
  current branch, and reports the first not-`done` step. Deterministic — no scrollback archaeology.
- **Sync is the commit column.** Each plan step carries its commit SHA; committed step ids never
  renumber.
- **Archive, not delete, on PR.** Verification notes outlive the review session.

## Technology-agnostic by construction

Skills are pure procedures — no stack knowledge is hardcoded. The commands a skill needs (test,
lint, run, db-console, server URL) are read _from the project_, in order:

1. a declared `## Commands` / `## Project specifics` block in `CLAUDE.md` / `AGENTS.md`,
2. then manifests and scripts (`package.json`, `Gemfile` + `bin/`, `Makefile`, `Procfile`, …),
3. then the code itself.

Stack is detected by which manifest is present, never branched on by name. Verification scenarios
are _typed_ (`db` / `http` / `cli` / `console` / `test`) — an agnostic taxonomy; the project
resolves each type to a concrete command. With no declared commands a skill auto-detects and states
its assumption, asking when ambiguous — it never guesses silently. Every command is grounded in
something that exists in the repo (a route, a schema column, a file opened by Read), so nothing is
fabricated. Stack-specific examples live in `references/`, marked as examples, never as skill logic.

## Thin harness, fat skills

A skill's weight tracks the complexity of its procedure, not a fixed line budget. The body holds the
process and its guards; bulky detail — templates, scenario taxonomies, per-stack examples — lives in
`references/` and loads on demand. Skills come in three weights: trigger-only,
procedural-with-references, and procedural-standalone. The harness stays thin; the intelligence
lives in the markdown, where every model upgrade improves it for free.

## Composable, not chained

Skills stay separate — different axes, different inputs, different guards (a multi-axis diff review
is not the same job as checking a change against the repo's existing patterns). They connect through
three light layers, none of them a forced sequence:

1. **Shared artifacts** in `.ai/verify/<branch-slug>/` — a skill reads its neighbors' outputs when
   they exist (verify reads explain's scenarios; risk reads review and conform). The strongest link,
   because it is deterministic and survives `/clear`.
2. **A "Next:" pointer** at the end of each skill body, plus optional in-body delegation.
3. **A thin router** — the README task-router table.

The catalog is also self-contained: it never _depends_ on external skills (they might change or be
absent). Composition with outside tools is optional, never required — which is why a full review
skill ships here even though other reviewers exist.

## Diagnosis vs treatment — the one writer in the quality pipeline

The quality skills are read-only on purpose. `dw-review`, `dw-conform`, `dw-explain`, `dw-verify`, and
`dw-risk` diagnose a change and record what they find under `.ai/verify/<branch-slug>/`; none of them
edits code. That separation is what keeps the artifacts honest — an auditor that also patched things
would be tempted to under-report what it couldn't fix, and its record would stop being a faithful
diagnosis.

`dw-fix` is the deliberate exception: the **single writer**, the treatment step. It reads the findings
the auditors recorded and applies them — never inventing work outside them — with the same per-change
discipline as `dw-build`: minimal slice, run the check, one commit per finding, mark it resolved. It
stays inside the catalog's thesis in three ways. It is **human-invoked, not a loop** — it treats the
findings in front of it and stops; it does not review-fix-review on its own. It **issues no verdict**:
re-running the auditor on the fixed code is what confirms the change is clean, so the thing that grades
the work is never the thing that wrote it. And it is **severity-gated** — `blockers` clears the
critical / high findings and stops for a re-audit, so `dw-conform` / `dw-explain` / `dw-verify` never
run against code a review already flagged as broken; the lower-severity findings are then fixed in one
batch on the stable picture, rather than re-derived by every later pass.

## Explicit-only skills

`dw-bootstrap`, `dw-handoff`, `dw-prune`, `dw-sync`, and `dw-setup-precommit` are invoked by name and
never auto-trigger — they scaffold a repo, install shared tooling, or compact or mutate state, or act
on an explicit drift signal, so the model should not reach for them unbidden. Everything else can be
model-invoked when the task fits.

## Loops vs persistence — why these skills don't auto-run

The field is drifting toward agents that prompt _themselves_ — loops that file a PR, review it,
address the comments, and trigger the next one with no human in the seat. This catalog deliberately
takes the other fork: **persistence plus a human gate**, not unattended autonomy. The reasoning is
narrow and practical. A loop that has taken a wrong turn doesn't just waste one step — it compounds,
multiplying both the error rate and the token burn for as long as it runs unwatched. The value these
skills are built to deliver is _reliable resumption and grounded verification_ — a plan that survives
`/clear`, a review tied to real `file:line`s, a "done" that was actually run — and none of that needs
the loop to close itself. The HARD STOP is the feature, not a gap waiting to be automated away.

That isn't a claim that loops never belong here. A bounded loop _could_ fit one day — but only as an
**opt-in, explicit-invoke conductor that reuses the existing skills** (spec → plan → build → review →
verify, each still gated), never a standing background process that merges on its own. If one is ever
added, it stays a thin conductor over the catalog, not a parallel implementation of it.

What it must **not** become is a zoo of personas. Predefining an `adversarial-reviewer`, a
`security-reviewer`, an `explorer` as separate persona skills misreads what agents are good at: the
model builds the context it needs _dynamically_, and hard-coding a cast of roles just freezes that
flexibility into markdown. That is why `dw-review` weighs all five axes — correctness, readability,
architecture, security, performance — in **one** skill rather than five persona skills handing a diff
between them. The unit here is the **job** (review a change, prove it runs, assess its blast radius),
not the **persona** doing it. One skill, one job — and the agent decides how to do it.
