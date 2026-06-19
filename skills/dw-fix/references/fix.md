---
branch: my-feature-branch
base: main
created: YYYY-MM-DD
sources: review.md, conform.md # which artifacts these fixes came from
---

# Fix — [title of the change]

Treatment log: the findings the auditors recorded, and how each was addressed. `dw-fix` applies
findings severity-ordered, one commit per fix; it never issues a verdict — re-running the auditor
confirms the change is clean.

## Summary

[One line: `n` fixed (`n` blocker(s)), `n` deferred. Lead with whether the blockers are cleared.]

## Applied

Worst severity first. Location is `path:line` from the finding; the commit is the short SHA that fixed
it.

| Severity | Location      | Finding                                        | Fix commit  |
| -------- | ------------- | ---------------------------------------------- | ----------- |
| critical | `[path:line]` | [user input concatenated into the SQL string]  | `[abc1234]` |
| high     | `[path:line]` | [rejected promise swallowed — missing `await`] | `[def5678]` |
| medium   | `[path:line]` | [off-by-one on the empty-list edge case]       | `[9012abc]` |

## Deferred

Findings left unfixed, each with a reason (out of scope, needs a decision, an irreversible step the
author must confirm). "— none —" if everything was applied.

| Severity | Location      | Why deferred                                        |
| -------- | ------------- | --------------------------------------------------- |
| low      | `[path:line]` | [cosmetic rename — batched into a follow-up commit] |

## Next

[After `blockers`: re-run `dw-review` / `dw-conform` to confirm the verdict is clean. After a full
pass: re-run the audits these came from, then `dw-explain` → `dw-verify`.]
