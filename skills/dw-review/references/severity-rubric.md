# Severity rubric — critical / high / medium / low, and the verdict

Every finding ends in exactly one severity, and the severities decide the verdict. The rubric exists
so the call is consistent and honest — especially the line between "this blocks the merge" and "this
is a nit", which is where a review loses the author's trust if it drifts.

## critical

Must not ship as-is. An exploitable security hole, data loss or corruption, or a break in core
functionality — the change is actively dangerous or fails at its main job. One critical finding is
enough to block.

## high

Wrong on a real path, or a serious risk. Incorrect behaviour a user will actually hit (not just a
rare edge), a significant regression, a missing check on an important path, or a maintainability
problem bad enough that the next change here is likely to break. Should be fixed before merge.

## medium

Works today, but fragile. An unclear or brittle construct, a narrow edge case, a smaller
maintainability or readability problem, a performance issue off the hot path. Worth fixing; doesn't
block on its own.

## low

A nit. Style, naming, a comment, a tidy-up with no behavioural impact. Record it so it isn't lost,
but it never blocks — and never pad the review with these to look thorough.

## The verdict

The verdict is the **worst severity present** — findings don't average:

- any **critical** or **high** → **request-changes**
- only **medium** / **low** → **approve-with-comments**
- no findings at all → **approve**

A clean review is a real outcome. `approve` with an empty findings list is the right result for a
solid change — don't invent a `low` just to have a row.

## Tie-breakers

- **Between two levels, lean higher when it touches a user-facing path, a security boundary, or
  data** — and lower when the impact is purely stylistic. Severity tracks _impact_, not how subtle
  or clever the bug is.
- **"Might be a problem" is not a finding.** If you can't ground it in a real line and a real
  consequence, it's an open question for the Summary, not a severity row.
- **Scope before severity.** A pre-existing issue the diff only sits beside isn't a finding at any
  severity; note it once in the Summary instead.

## Severity is your call, not the linter's

The severity reflects _your_ reading of the impact in _this_ codebase — not what an external tool
might say. Don't downgrade a real bug to `low` because "the linter would catch it" (it didn't — you
did), and don't upgrade a harmless style choice to `high` because a strict ruleset dislikes it. You
read the project's lint config to learn its conventions; you assign the severity yourself.

## Decision flow (example)

    can you ground it in a real file:line + a real consequence?
      no  → not a severity row; raise it as an open question in the Summary
      yes → does it touch security / data / core function?
              yes, and it breaks      → critical
              yes, wrong on a real path → high
              no → does it change behaviour, or block the next change here?
                     yes → high / medium (by how likely it is to bite)
                     no  → low
