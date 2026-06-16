---
branch: my-feature-branch
base: main
input: working-diff # working-diff | branch | pr
created: YYYY-MM-DD
---

# Explain — [title of the change]

## A. Intent

- **What:** [1–2 sentences: what this change does, from the caller's point of view]
- **Why:** [the value, or the problem it solves]

## B. How it works

[The mechanism, grounded in the diff. The path a request/value takes through the
changed code; key functions/modules touched, by path; any non-obvious decision a
future reader would otherwise reverse-engineer. Cite real paths
(`path/to/file.ext`), confirmed via Read or present in the diff.]

## C. Prove it works

Runnable scenarios. Each command is the project's real command; each row is
grounded in a referent that exists. `dw-verify` walks this table row by row.

| #   | Type   | Pri | Command                      | Expected                                 | Referent                     |
| --- | ------ | --- | ---------------------------- | ---------------------------------------- | ---------------------------- |
| 1   | [type] | P0  | `[project-resolved command]` | [observable result: row / status / line] | [route / column / file:line] |
| 2   | [type] | P1  | `[command]`                  | [expected result]                        | [referent]                   |
| 3   | [type] | P2  | `[command]`                  | [expected result]                        | [referent]                   |

- **Type** — `db` · `http` · `cli` · `console` · `test` · `browser`.
- **Pri** — `P0` core path · `P1` important behaviour / main edge · `P2` secondary.
- **Expected** — the concrete thing that proves it: the value, the status code, the
  assertion that passes. No "should work".
- **Referent** — what grounds this row (the route in the router, the column in the
  migration, the file you read). If you can't fill this column, the row belongs in E.

## D. Edge cases

- [boundary / failure mode the change must handle — empty input, auth failure,
  concurrent write, null, limit — grounded the same way as C]

## E. Open questions

- [a scenario you couldn't ground — name the missing referent]
- [a command you couldn't resolve from the project — name the assumption you'd need]
- [any assumption made while writing the above]

---

**Next:** consider `dw-verify` — it reads these scenarios and runs them, recording
actual vs expected in the same folder.
