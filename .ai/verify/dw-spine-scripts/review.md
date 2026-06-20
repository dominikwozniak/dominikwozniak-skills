---
branch: dw-spine-scripts
base: main
input: branch # working-diff | branch | pr
created: 2026-06-20
sources: none — reviewed from the diff
---

# Review — RUN A: deterministic `.ai/` spine (slugify / new-run / find-active-run scripts)

Multi-axis review of this change — correctness, readability, architecture, security, performance.
Every finding points at a real `file:line`; a clean axis is "— none —", not an omission.
`dw-review` writes this before the change merges.

## Verdict

**request-changes** — two real bash defects in `find-active-run.sh`: a same-day multi-run tiebreak
that picks the wrong run, and a malformed/missing-Status-column table that silently reports "all
steps done" instead of erroring like its sibling `plan-status.sh`. Both confirmed by running the
scripts under the system bash 3.2.57. Everything else (slugify, new-run, the 12 skill rewirings,
version sync, no-bash-4 discipline, security) is solid.

<!-- request-changes ⇐ any critical/high · approve-with-comments ⇐ only medium/low · approve ⇐ none -->

## Findings

Grouped by axis, worst severity first within each. Location is `path:line` from the diff.

### Correctness

| Severity | Location                                               | Finding                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Suggested fix                                                                                                                                                                                                                        |
| -------- | ------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| high     | `plugins/dw-planning/scripts/find-active-run.sh:50-53` | Same-day "newest wins" tiebreak is wrong. Comment claims "run-id is date-prefixed, so a lexical sort orders by age", but when ≥2 runs share a day the date prefix is identical and the lexical sort falls through to the **description slug alphabetically**, not creation time. Verified: 3 runs on one branch/day → it picked `…-xyz-9-live-date` over the run that actually held the `PLAN.md`, then reported `step: none (no PLAN.md yet)`. Wrong run resolved.    | Tiebreak on real recency, not lexical id: `ls -dt "$runs_dir"/*/` mtime, or the SPEC frontmatter `created:`, or git-add order. At minimum stop _claiming_ lexical = age in the comment and surface all matches for the user to pick. |
| high     | `plugins/dw-planning/scripts/find-active-run.sh:68-94` | A PLAN table that exists but has **no `Status` column** (header regex at L68 requires both `[Ss]tatus` AND `[Cc]ommit`) never sets `hdr`, so awk reaches END with `found=0` and prints `step: none (all steps done)`. Verified: a `\| Step \| Title \| Commit \|` table → "all steps done". That is a false green that would make `dw-build` think work is finished. Its sibling `plan-status.sh:81` handles the same case as `ERROR\tno status table` + nonzero exit. | Detect "header never matched" vs "matched, all done" separately: track an `hdr_seen` flag; in END, if `hdr` never triggered emit a distinct `step: error (unparseable PLAN table)` and exit nonzero, mirroring `plan-status.sh`.     |
| medium   | `plugins/dw-planning/scripts/find-active-run.sh:38-40` | Behavior narrowed vs the prose it replaced. The script matches a run **only** by `SPEC.md` `branch:`; the old prose (and the still-present dw-resume/dw-build/dw-sync numbered lists) say "from `PLAN.md`, else `SPEC.md`". A run whose SPEC lacks/has a stale `branch:` but whose PLAN has the right one won't be found. Low real-world risk because `new-run.sh` always writes SPEC `branch:`, but it is a silent contract change.                                   | Either read PLAN's `branch:` as a fallback to match the documented rule, or update the four skills' prose to state SPEC-only matching so script and docs agree.                                                                      |
| medium   | `plugins/dw-planning/scripts/find-active-run.sh:84-89` | Ragged-row safety: if a body row has fewer `\|`-cells than the header (so `c[scol]` is unset), `s` becomes empty and the row is skipped via `if (s=="") next` — benign, but a row missing only the _trailing_ commit cell could shift columns and mis-read Status. Not reproduced, but the splitter trusts column positions without a field-count guard.                                                                                                               | After `split($0,c,"\|")`, guard `if (nf_body < scol) next` (capture `nf_body` from the split return) so short rows can't be mis-attributed.                                                                                          |

### Readability

| Severity | Location                                               | Finding                                                                                                                                                                                                                                                                                                  | Suggested fix                                                                                                                                 |
| -------- | ------------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| low      | `plugins/dw-planning/scripts/find-active-run.sh:50`    | The comment "a lexical sort orders by age" is actively misleading (see the high finding) — it asserts a correctness property the code does not have. A reader trusting it would not catch the same-day bug.                                                                                              | Reword to the truth ("lexical sort orders by run-id; within a day that is description-alphabetical, NOT recency") once the tiebreak is fixed. |
| low      | `plugins/dw-planning/scripts/slugify.sh:18` + `tr` L22 | `LC_ALL=C` + `tr 'A-Z' 'a-z'` means non-ASCII is folded byte-by-byte to `-`: `café déjà vu` → `caf-d-j-vu`. Deterministic and arguably intended, but undocumented and surprising for unicode descriptions. (shellcheck SC2018/SC2019 also flag the `tr` form — benign here, the C locale is deliberate.) | One line in the header comment noting non-ASCII is dropped, so future readers don't "fix" the `tr`.                                           |

### Architecture

| Severity | Location                              | Finding                                                                                                                                                                                                                                                                                                                                                                                                                                           | Suggested fix                                                                                                                                                                                               |
| -------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| medium   | `scripts/validate-manifests.sh:36-47` | CI only asserts `plan-status.sh` present+executable; the three new shared scripts are unchecked, and — critically — the two byte-identical `slugify.sh` copies are **not** checked for identity. The whole point of this PR is killing derivation drift, yet a future edit to one slugify copy would silently diverge with zero CI signal: the exact bug class, reintroduced one layer down. (Confirmed both copies share blob `508fb0c…` today.) | Extend the validator: assert each new script is present+executable, and `diff plugins/dw-planning/scripts/slugify.sh plugins/dw-quality/scripts/slugify.sh` (or compare git blob hashes) fails CI on drift. |

### Security

— none —

(Adversarially checked: every expansion built from a branch name, ticket arg, or file content is
double-quoted; `slug()` strips to `[a-z0-9-]` before any value reaches a path; `new-run.sh` uses a
heredoc with no command substitution from user data; no `eval`; the only `mktemp` lives in the
unchanged `plan-status.sh`. The `run_dir`/`spec` globs and `dirname`/`basename` calls are quoted.
Run-ids cannot contain `/`, `..`, or whitespace, so no path traversal via ticket/desc.)

### Performance

— none —

(All scripts are O(number-of-runs) single-pass awk over small markdown files; no concern.)

## Summary

Request changes. The design is sound and the bash is genuinely careful — no bash-4 features slipped
in (verified: no `mapfile`, `${arr[-1]}`, `${v^^}`, or associative arrays; all four scripts run
clean under the system `bash 3.2.57`), `set -euo pipefail` is respected (the `[ -n "$t" ] && parts+=`
idiom and `${SLUG_DATE:0:4}` substring both behave under `set -e` on 3.2), security is clean, the 12
skill rewirings all call the correct subcommands/flags with consistent `${CLAUDE_PLUGIN_ROOT}`, no
stale derivation prose was left behind, version bumps are in sync (`dw-planning 0.1.7`,
`dw-quality 0.1.8`, `pnpm validate:manifests` green), and the two `slugify.sh` copies are byte-identical.

The single most important thing to fix first is the **same-day tiebreak** in `find-active-run.sh:50-53`
— it is the most likely to bite (multiple runs per branch per day is normal) and it resolves the
_wrong run_ silently, which is precisely the "drift" failure mode this PR set out to eliminate. Right
behind it: the **missing-Status-column false "all done"** (find-active-run.sh:68-94) should error like
`plan-status.sh` does rather than claim completion. Both are testable in a few lines of bash — given
the scripts are otherwise untested, a small `tests/` harness (run-id determinism, multi-run tiebreak,
malformed-table) would lock this spine down and is worth adding before merge. Out of scope but noted:
the CI validator should grow a slugify-copy identity check so the duplicated file can't drift later.
