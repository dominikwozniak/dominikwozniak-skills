---
name: dw-fix
description: >-
  Apply the findings the quality auditors recorded — read `review.md` / `conform.md` /
  `risk.md` under `.ai/verify/`, fix each one severity-ordered, one logical commit per
  fix, mark it resolved, and write a durable `fix.md` log. The single writer in the
  quality pipeline: the auditors only diagnose, dw-fix treats. Severity-gated —
  `blockers` fixes the critical / high findings first and stops for a re-audit, so
  downstream checks never run on broken code; the default pass fixes the whole worklist.
  Grounded: it only touches findings the artifacts already record, never invents work,
  and never issues a verdict (re-running the auditor does that). Reads the project's own
  test / lint commands and `## Git conventions`. Use after a review or conformance pass,
  or when someone says "fix the findings", "address the review", "apply the review
  fixes", "fix the drift", "remediate the findings", or invokes "dw-fix".
argument-hint: "empty = fix all open findings severity-ordered; 'blockers' = critical/high only"
---

# dw-fix — apply the quality findings, one commit per fix

The quality auditors are deliberately **read-only**: `dw-review`, `dw-conform`, `dw-explain`,
`dw-verify`, and `dw-risk` diagnose a change and record what they find, but none of them edits code.
That separation is what keeps their artifacts honest — an auditor that also patched things would be
tempted to under-report what it couldn't fix, and the record would stop being a faithful diagnosis.

`dw-fix` is the **treatment** step, and the **one writer** in the pipeline. It reads the findings the
auditors recorded and applies them — grounded in those findings, never inventing work outside them —
with the same per-change discipline as `dw-build`: minimal slice, run the check, one logical commit,
mark it resolved. It does not grade the change; **re-running the auditor** is what confirms the
verdict flipped clean. One finding at a time, blockers first.

## What it reads and writes

- **Reads:** the audit artifacts under `.ai/verify/<branch-slug>/` (`review.md`, `conform.md`,
  `risk.md`, `verify-run.md` — whichever exist), the real files each finding points at, and — **from
  the project, never hardcoded** — the test / lint commands and the commit convention
  (`## Git conventions`).
- **Writes:** the fix code; **one logical commit per finding**; each finding marked resolved (with its
  fix SHA) in the artifact that raised it; an appended `fix.md` log. The bookkeeping is the auditor's
  record updated in place — never amend the code commit to fold it in.

## Output location

Write `fix.md` to `.ai/verify/<branch-slug>/fix.md`. `.ai/` is tracked in git — the treatment log is
real work documentation, committed alongside the code.

- Branch: `git rev-parse --abbrev-ref HEAD`. Slugify it for the folder name
  (e.g. `ABC-123/password-reset` → `abc-123-password-reset`) — the **same slug** the rest of
  `dw-quality` uses, so `fix.md` lands beside the artifacts it acts on.
- `mkdir -p .ai/verify/<branch-slug>` before writing.

## Workflow

### 1. Locate the findings (no artifact → stop)

Resolve the branch-slug and read whichever of `review.md`, `conform.md`, `risk.md`, `verify-run.md`
exist in `.ai/verify/<branch-slug>/`. If the folder holds **no audit artifact**, there is nothing
grounded to fix — say so and stop:

> No audit to fix from in `.ai/verify/<branch-slug>/`. Run `dw-review` (and/or `dw-conform`) first,
> then `dw-fix` to apply what it finds.

Never fix from memory or a fresh read of the diff — `dw-fix` acts on **recorded findings**, so that
every change traces to a referent the author can see.

### 2. Collect and rank the worklist

Pull every open finding from the artifacts into one list, each carrying its **severity**, its
`file:line`, and its suggested fix:

- `review.md` — `critical` / `high` / `medium` / `low`.
- `conform.md` — drift at `high` / `medium` / `low`.
- `risk.md` / `verify-run.md` — any **in-code** must-fix they flagged (out-of-code / deploy items —
  migrations, flags, rollback — are confirm-not-fix; they hit the irreversible-action guard below).

**Dedup** across artifacts: the same `file:line` raised by both review and conform is **one** fix, not
two. **Skip** findings already marked resolved. Order the list **worst-first**:
critical → high → medium → low.

### 3. Mode — blockers, or the whole worklist (`$ARGUMENTS`)

- **`blockers`** → fix only the **critical / high** findings (a `request-changes` review, a `drifts`
  conform), then **stop** and point to re-running the audit that raised them. This is the
  short-circuit: clear what blocks the change before anything downstream runs.
- **Empty (default)** → fix the **full ranked worklist**, worst-first.

Read the mode from `$ARGUMENTS`: treat `blockers` as critical/high-only; anything else (including
empty) is the full pass.

### 4. The severity gate — why blockers go first

A critical or high finding left in place poisons everything after it: `dw-conform`, `dw-explain`, and
`dw-verify` would run against code that is known-broken, and the **next** review just repeats the same
blocker. So when an audit's verdict is `request-changes` / `drifts`, fix the blockers, **re-run that
auditor** to confirm it's clean, and only then move on to the lower-severity batch. Fixing the rest on
the full, stable picture beats fixing each finding the moment it's raised — you patch once, on
complete information, instead of redoing work as later audits land.

### 5. Fix each finding — minimal, grounded, one commit (mirror `dw-build`)

For each finding in worst-first order, one cycle:

- **Read before write.** Open the real file at the finding's `file:line` and confirm the problem is
  still there. Never edit a file you haven't opened, and never edit a finding you can't see.
- **Apply the minimal change** the finding calls for — scoped to _that_ finding. Resist cleaning up
  adjacent code or folding two findings into one sprawling edit; that's scope creep and it muddies the
  commit. (Honour the same scope discipline the auditors used.)
- **Check it.** Run the project's relevant test / lint (resolved from the project, as `dw-build`
  does — declared `## Commands` block → manifests → the code) so the fix is proven and nothing
  regressed. State the assumption and ask if a command can't be found — never invent one.
- **Commit.** **One logical change**, message per the project's `## Git conventions` (e.g.
  `[TICKET] fix: <finding>`). Plain `git commit` — it auto-signs; never add `-S` or "fix" signing.
  Capture the short SHA with `git rev-parse --short HEAD`.
- **Mark it resolved.** Annotate the finding in its source artifact with the fix SHA — leave the
  bookkeeping staged or land it as a small follow-up commit; **never amend the code commit** to fold
  it in.

### 6. Stop-and-ask on irreversible actions (hard guard)

Some actions a `git revert` can't undo: schema migrations, `DROP` / `TRUNCATE`, data backfills,
deploys, force-pushes, anything touching production data or an external service. Before any of these —
**even mid-worklist** — stop, name the action, and ask. A finding that _recommends_ an irreversible
step is a proposal to confirm, not a licence to run it. (Same guard as `dw-build` and `dw-verify`.)

### 7. Don't grade your own work — point to the auditor

`dw-fix` writes; it never issues a verdict. Confirming that the verdict flipped clean is the
**auditor's** job — re-running it on the fixed code is what keeps diagnosis and treatment separate.
So `dw-fix` finishes by pointing back to the read-only pass, never by declaring the change approved.

### 8. Write fix.md and point forward

Write `fix.md` (shape below): every finding addressed → its fix SHA, plus a **Deferred** list for
anything left unfixed, each with a reason. Then point forward:

- After **`blockers`**:

  > `fix.md` saved to `.ai/verify/<branch-slug>/` — `n` blocker(s) fixed. **Next:** re-run `dw-review`
  > (or `dw-conform`) to confirm the verdict is clean, then continue the quality pass.

- After the **full pass**:

  > `fix.md` saved to `.ai/verify/<branch-slug>/` — `n` fixed · `n` deferred. **Next:** re-run the
  > audits you fixed from to confirm they're clean, then `dw-explain` → `dw-verify` to prove the change
  > still runs.

## The fix.md shape

`references/fix.md` is the exact shape to copy: light frontmatter
(`branch` / `base` / `created` / `sources`), a one-line **Summary**, an **Applied** table
(`severity · location · finding · fix commit`), a **Deferred** table (`severity · location · why`, or
"— none —"), and a closing **Next** note. Keep it lean — a treatment log the author skims, not a
report.

## Guardrails

- **Only fix recorded findings.** No artifact → nothing to fix; never patch from memory or a fresh
  eyeball of the diff. Every change traces to a finding the author can see.
- **Read before write.** Open the real file at each `file:line`; resolve commands and the commit
  convention from the project. Never edit an unopened file or invent a command.
- **Minimal, scoped change per finding** — no adjacent cleanup, no merging findings.
- **One logical commit per fix**, message per the project's `## Git conventions`; plain commit
  auto-signs (never `-S`, never reconfigure signing).
- **Blockers first.** Fix critical / high, re-audit, then batch the rest — don't fix the whole list
  before a known blocker is cleared.
- **Never issue a verdict.** `dw-fix` treats; the auditor (re-run) grades. Point to it; don't claim
  "approved" yourself.
- **Stop-and-ask on irreversible actions** — a hard guard, even mid-worklist.
- **Never silently guess.** Unfound command, an ambiguous finding, a fix that needs an irreversible
  step — name it and ask.

## References

- `references/fix.md` — the artifact template. Copy this shape every run.
