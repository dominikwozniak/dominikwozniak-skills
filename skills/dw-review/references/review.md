---
branch: my-feature-branch
base: main
input: working-diff # working-diff | branch | pr
created: YYYY-MM-DD
sources: explain.md # which neighbours fed this; "none — reviewed from the diff" if standalone
---

# Review — [title of the change]

Multi-axis review of this change — correctness, readability, architecture, security, performance.
Every finding points at a real `file:line`; a clean axis is "— none —", not an omission.
`dw-review` writes this before the change merges.

## Verdict

**[request-changes | approve-with-comments | approve]** — [one line: the must-fix items, or "no
blocking issues"].

<!-- request-changes ⇐ any critical/high · approve-with-comments ⇐ only medium/low · approve ⇐ none -->

## Findings

Grouped by axis, worst severity first within each. Location is `path:line` from the diff.

### Correctness

| Severity | Location      | Finding                                        | Suggested fix                          |
| -------- | ------------- | ---------------------------------------------- | -------------------------------------- |
| high     | `[path:line]` | [rejected promise swallowed — missing `await`] | [await the call; handle the rejection] |
| medium   | `[path:line]` | [off-by-one on the empty-list edge case]       | [guard `len == 0` before indexing]     |

### Readability

| Severity | Location      | Finding                                | Suggested fix           |
| -------- | ------------- | -------------------------------------- | ----------------------- |
| low      | `[path:line]` | [`d` is an opaque name for a duration] | [rename to `timeoutMs`] |

### Architecture

— none —

### Security

| Severity | Location      | Finding                                       | Suggested fix                                 |
| -------- | ------------- | --------------------------------------------- | --------------------------------------------- |
| critical | `[path:line]` | [user input concatenated into the SQL string] | [use a parameterised query / the ORM binding] |

### Performance

| Severity | Location      | Finding                                     | Suggested fix                        |
| -------- | ------------- | ------------------------------------------- | ------------------------------------ |
| medium   | `[path:line]` | [N+1: query inside the `for` over `orders`] | [load with a single `includes`/join] |

## Summary

[Lead with the verdict and the must-fix items. One short paragraph: what's solid, what blocks, and
the single most important thing to address first. Anything reviewed but deliberately left out of
scope — a pre-existing issue the diff only sits beside — goes here in one line, not in the tables.]
