---
name: dw-review
description: >-
  Review a change across five axes — correctness, readability, architecture, security, and
  performance — and write a durable review.md to `.ai/verify/`: an overall verdict plus findings,
  each one a real `file:line`, a severity (critical / high / medium / low), and a concrete fix.
  Read-only and self-contained — it reviews the change itself rather than deferring to CI or another
  reviewer, grounds every finding in a line that exists in the diff, and never invents problems
  outside it. Resolves the change three ways (working diff, branch vs base, or a PR via
  `gh pr diff`) and reads the project's own conventions instead of imposing a generic standard.
  Use when a change is ready for review or about to merge, or when someone says "review this
  change", "review the diff", "review my PR", "code review", "any issues with this", "look over my
  change", or invokes "dw-review". Prefer this over an ad-hoc eyeball whenever a change needs
  reviewing.
argument-hint: "What should I review? (working diff, branch, or PR)"
---

# dw-review — multi-axis review of a change, grounded in real lines

A change is written, maybe about to go up as a PR — and the valuable next step before it merges is a
real review. Not "looks fine", but a deliberate pass across the axes where code actually goes wrong:
is it **correct**, is it **readable**, does it fit the **architecture**, is it **secure**, is it
**fast enough**? That thinking usually happens once, in a reviewer's head, and then evaporates — the
author, or the next person to touch this code, can't see what was weighed. This skill captures it as
a durable artifact, `review.md`, holding an overall verdict and a grounded list of findings.

The whole point is **grounded, not guessed**. A review that invents problems — or pads itself to
look thorough — is worse than none: it burns the author's trust and buries the findings that matter
under the ones that don't. So every finding here points at a real line in the change, and "no issues
on this axis" is a valid, honest result rather than a quota to fill. And it is **self-contained**:
`dw-review` _is_ the reviewer, not a dispatcher that defers to CI or "a human should look at this".
It does the reading itself.

## Output location

Write to `.ai/verify/<branch-slug>/review.md`. `.ai/` is tracked in git — a review is real work
documentation, committed alongside the code.

- Branch: `git rev-parse --abbrev-ref HEAD`. Slugify it for the folder name
  (e.g. `ABC-123/password-reset` → `abc-123-password-reset`) — the **same slug** the rest of
  `dw-quality` uses, so your `review.md` lands beside its siblings.
- `mkdir -p .ai/verify/<branch-slug>` before writing.

## Input — read your neighbours first (if they exist)

`dw-review` is **step 4** — usually the _first_ quality pass over a change, run right after
implementation. So the shared folder is often empty, and that's fine. But the pipeline is a
recommendation, not a fixed order, so check first:

- If **`explain.md`** (from `dw-explain`) is already there, read it for the change's _intent_ —
  knowing what the change is _for_ sharpens the correctness axis: you can judge the code against what
  it's meant to do, not just against itself.
- Any other sibling output (`verify-run.md`, …) is context, not a gate.

**Self-contained.** `dw-review` depends on no sibling having run. With an empty folder, review
straight from the diff. Either way, **always write `review.md`** — even "no findings, approve" is a
durable result worth recording. Never finish a run with no artifact.

## Resolve the change (three input shapes)

The request — which change to review — may arrive as `$ARGUMENTS`. You need the diff both to locate
the right branch-slug folder and to ground every finding. Accept any of three shapes; pick by what
the user pointed at, else default to the working diff:

1. **Working diff** (default): `git diff $(git merge-base HEAD <base>)` (base is usually `main`; read
   it from the project's git conventions if declared).
2. **Branch vs an explicit base**: `git diff <base>...HEAD`.
3. **PR**: `gh pr diff <number>` (or `gh pr diff` on the current branch's PR).

Read the actual diff. Every finding below is anchored in these hunks, not in your memory of the
change.

## Read the project's conventions (don't impose a generic standard)

A finding is only fair if it's measured against _this_ project's standards, not a generic ideal.
"This isn't how I'd write it" is noise; "this breaks the project's own convention at X" is signal.
Discover, read-only, in this order:

1. **Declared block** — `## Commands` / `## Project specifics` / coding conventions in `CLAUDE.md`,
   `CLAUDE.local.md`, or `AGENTS.md` (style, naming, the layers, the lint / format / typecheck
   tooling, the git base).
2. **Config & manifests** — the linter / formatter / type config (`.eslintrc`, `.rubocop.yml`,
   `ruff.toml`, `tsconfig.json`, …) and `package.json` / `Gemfile` / `go.mod`. Their presence also
   tells you the stack, so you apply the right idioms — a Ruby smell isn't a Go smell.
3. **The code itself** — the surrounding, unchanged code is the living style guide: match the
   conventions the neighbouring files already follow.

This is reading, not running — `dw-review` never executes the linter or the tests (that's
`dw-verify`, under its execution guard). If a convention is genuinely unclear, **state the assumption
you're reviewing against** rather than inventing a rule and grading the change against it.

## The five review axes

Read the diff once through each lens. Each axis asks a different question:

- **Correctness** — does it do the right thing, including at the edges and on failure?
- **Readability** — will the next person understand it without you in the room?
- **Architecture** — does it fit the existing structure, or fight it?
- **Security** — can untrusted input, a missing check, or a leaked secret hurt?
- **Performance** — will it stay fast enough at real scale, on the real hot paths?

`references/review-axes.md` holds the full checklist for each — what to look for, and where each axis
tends to hide its bugs. Read it while you review.

## Ground every finding — the anti-hallucination invariant

**No finding in `review.md` without a real referent.** Every finding points at a `file:line` that
exists in the diff — or a line you opened with `Read` to trace an effect (a caller, the other side of
a contract). If you can't point at the line, it isn't a finding. This is the line between a review the
author acts on and one that makes them defend their code against problems that aren't there. A vague
"consider error handling" with no location is not a finding; "`api/auth.ts:42` — the `await` is
missing, so a rejected promise is silently swallowed" is.

## Scope discipline — review the diff, not the repo

Review what the change **introduces, changes, or directly endangers** — not the whole codebase. A
pre-existing problem the diff merely sits next to is **out of scope**: at most note it once,
separately, and never let it crowd out the real findings. The opposite failure is just as real:
**don't manufacture findings to look thorough.** A clean axis is a legitimate result — write
"— none —" and mean it. A short, true review beats a padded one every time.

## Self-contained — you are the reviewer

`dw-review` does the review itself. It does not punt: not "CI will catch it", not "a linter would
flag this", not "someone should double-check the security here". Those are abdications, not findings.
You read the linter's _config_ to learn the project's rules (above) — you do not hand the judgement
to it. If something can only be settled by _running_ it, that's a `dw-verify` scenario, not a reason
to skip the review: note it and review the rest.

## Severity and the verdict

Every finding carries a severity, and the severities roll up into one verdict:

- **critical** — an exploitable security hole, data loss, or a break in core functionality; must not
  ship as-is.
- **high** — wrong behaviour on a real path, or a serious regression / maintainability risk.
- **medium** — fragile, unclear, or a narrow edge case; works today but will bite later.
- **low** — a nit: style, naming, a comment; no behavioural impact.

**Verdict** = the worst severity present:

- any **critical** or **high** → **request-changes**;
- only **medium** / **low** → **approve-with-comments**;
- none → **approve**.

`references/severity-rubric.md` has the full definitions, the tie-breakers (when a finding sits
between two levels), and why severity is _your_ call, not the linter's.

## What goes in review.md

A light frontmatter, the **Verdict**, then **findings grouped by axis** — each finding a row of
`severity · file:line · what's wrong · suggested fix` (or "— none —" for a clean axis) — and a
one-paragraph **Summary** that leads with the verdict and the must-fix items. Keep it lean: it's a
review a busy author reads top-to-bottom, not a report.

## Workflow

### 1. Locate the input and read neighbours

Resolve the branch-slug and look in `.ai/verify/<branch-slug>/`. If `explain.md` is there, read it
for intent. Its absence is normal — `dw-review` usually runs first.

### 2. Resolve the diff and read the project's conventions

Pick the input shape, read the diff, and read the project's style / lint / structure conventions
(read-only). This is your referent set _and_ the standard you grade against, for everything below.

### 3. Review across the five axes

Pass through the diff once per lens (correctness → readability → architecture → security →
performance), using `references/review-axes.md`. Note each candidate finding with its `file:line`.

### 4. Assign severity and ground every finding

Give each finding a severity from the rubric, and confirm each one points at a real line. Drop
anything you can't ground — that's the invariant, not a formality.

### 5. Derive the verdict

Roll the severities up: any critical / high → request-changes; only medium / low →
approve-with-comments; none → approve.

### 6. Write review.md

Copy the shape from `references/review.md`. Fill the verdict and the per-axis findings; ground every
row; mark clean axes "— none —".

### 7. Finalize and point to the next step

Tell the user where the artifact landed and what the verdict is, then point forward — a pointer, not
a dependency:

> `review.md` saved to `.ai/verify/<branch-slug>/` — verdict: **`<verdict>`**. **Next:** address the
> findings, then consider `dw-conform` to check the change against its existing siblings.

Lead with the must-fix items (the critical / high findings) so the author knows the one thing to do
first.

## The review.md shape

`references/review.md` is the exact shape to copy: light frontmatter
(`branch` / `base` / `input` / `created` / `sources`), a **Verdict** line, a findings table **per
axis** (`Severity · Location · Finding · Suggested fix`, or "— none —"), and a short **Summary**.
Keep it lean — findings the author can act on, not prose.

## References

- `references/review.md` — the artifact template. Copy this shape every run.
- `references/review-axes.md` — read while reviewing (step 3): the per-axis checklist — what each of
  the five lenses looks for, and where its bugs tend to hide. Per-stack smells are illustrative
  examples, never logic.
- `references/severity-rubric.md` — read when assigning severity (step 4): the definitions of
  critical / high / medium / low, the verdict mapping, the tie-breakers, and why the severity is your
  judgement and not a linter's.
