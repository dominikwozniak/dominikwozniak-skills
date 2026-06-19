# Skill anatomy

Every `skills/<name>/SKILL.md` in this repo follows one shape. It is not arbitrary house style — the
shape is what makes a skill resumable, groundable, and composable. New skills copy it; reviews check
against it. The canonical examples to read are [`dw-spec`](../skills/dw-spec/SKILL.md) and
[`dw-review`](../skills/dw-review/SKILL.md).

## Frontmatter

```yaml
---
name: dw-thing # kebab-case, MUST equal the directory name
description: >- # multi-line; this is what the model matches on
  One sentence on what it does and the artifact it writes. Then the trigger
  phrases — "Use when …", the things a user says ("spec this out", "review my
  PR"), or the explicit "dw-thing" invocation. End with a "Prefer this over …"
  line so the model picks it over an ad-hoc approach.
argument-hint: "What the skill expects as $ARGUMENTS" # short, optional for pure read-only skills
disable-model-invocation: true # ONLY for explicit-invoke-only skills (see below)
---
```

- **`name`** — kebab-case, equals the directory. Linted.
- **`description`** — the discovery surface. Pack the trigger phrases here; the model reads this, not
  the body, to decide whether to fire. Spec/review show the bar.
- **`argument-hint`** — a short hint string. Read-only skills that take no real argument may omit it
  (e.g. `dw-resume`).
- **`disable-model-invocation: true`** — set this _only_ on skills that compact or mutate state, or
  that act on an explicit drift signal, so the model never reaches for them unbidden:
  **`dw-bootstrap`, `dw-handoff`, `dw-prune`, `dw-sync`**. Everything else is model-invocable.

## Body order

A `# <name> — <tagline>` H1 and a short intro/rationale paragraph, then these sections in order
(skip the ones marked optional when they don't apply):

1. **Output location** — the baked-in `.ai/` path the skill writes, plus the line
   "`.ai/` is tracked in git". This is the persistence contract: the path lives _in the skill_, not
   in a wrapper. Two acceptable headings:
   - `## Output location` — for skills whose main job is to produce one artifact (`dw-spec`,
     `dw-review`, the `dw-quality` skills).
   - `## What it reads and writes` — for skills that both consume an upstream artifact and write one
     (`dw-plan`, `dw-build`, `dw-sync`).
   - **Read-only exception:** a skill that writes nothing (`dw-resume`) replaces this with
     `## What it reads` and states plainly that it writes nothing.
2. **Input — read your neighbours first** _(optional)_ — for skills that read sibling artifacts in
   the same `.ai/verify/<branch-slug>/` folder (`dw-conform`, `dw-explain`, `dw-verify`, `dw-risk`).
   State which siblings it reads and that their absence is fine — the skill is self-contained.
3. **Workflow** — numbered `### 1.`, `### 2.`, … steps. The procedure itself. Bake the HARD STOP
   gates here (see invariants).
4. **The `<artifact>` shape** _(optional)_ — points at the `references/` template to copy; lists the
   artifact's sections. Omit for read-only skills.
5. **References** _(optional)_ — present iff the skill has a `references/` folder; lists each file and
   when to read it.

## Cross-cutting invariants

These hold across every skill, regardless of section layout:

- **HARD STOP gates.** Before an assumption-laden or irreversible step, stop and ask — surface the
  unknown before it costs a rewrite (`dw-spec`'s Open Questions), and get explicit consent before
  mutating (`dw-prune`, `dw-sync`).
- **Anti-hallucination grounding.** Every finding, scenario, or claim points at a real referent —
  a `file:line`, a route, a schema column the skill confirmed with Read/grep. If it can't be
  grounded, it isn't reported (`dw-review`, `dw-explain`, `dw-risk`).
- **Always write the artifact.** A run never finishes without writing its output — even "no findings,
  approve" is a durable result worth recording. (Read-only skills are the explicit exception.)
- **Trailing "Next:" pointer.** End the body with a `**Next:**` line naming the skill a user would
  reasonably reach for next. This is the composable-not-chained link — a recommendation, never a
  forced sequence. (`dw-risk` legitimately closes the pipeline rather than pointing onward.)
- **Technology-agnostic.** No hardcoded stack. Read test/lint/run commands from the project
  (`## Commands` block → manifests → code). Stack-specific detail lives in `references/`, marked as
  examples. Full rationale in [`DESIGN.md`](DESIGN.md).
- **One job, not one persona.** A skill is a unit of work (review a change, prove it runs), not a
  role. `dw-review` weighs all five axes in one skill rather than splitting into persona skills — see
  [`DESIGN.md`](DESIGN.md), "Loops vs persistence."
