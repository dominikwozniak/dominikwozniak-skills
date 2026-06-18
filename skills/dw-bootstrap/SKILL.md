---
name: dw-bootstrap
description: >-
  Set up a project's Claude Code scaffolding — `.ai/` memory dirs, a tracked
  `.claude/settings.json` with guardrail hooks, a personal `CLAUDE.local.md`, and
  a cleaned `.gitignore` — wired to the `dw-spec → dw-plan → dw-build` loop. Two
  modes: a blank **skeleton** from templates, or a **tuned** setup that
  interviews you and fills `CLAUDE.local.md` to the project and your preferences.
  Use when setting up a new repo for Claude Code, standardizing an existing one,
  or migrating off claude-kit / addy-osmani's `.agent/` convention. Trigger
  phrases: "set up this project", "bootstrap claude", "scaffold the agent files",
  "dw-bootstrap". Prefer this over hand-writing CLAUDE.md/settings/hooks or
  cloning a separate starter kit.
argument-hint: "skeleton | tuned — and any project context to seed"
disable-model-invocation: true
---

# dw-bootstrap — scaffold a project for the dw-\* loop

Drop a consistent, **tracked** Claude Code setup into any repo: the `.ai/` memory
the `dw-planning` / `dw-quality` skills read and write, a committed
`settings.json` with guardrail hooks, a personal `CLAUDE.local.md`, and a
`.gitignore` that knows which of those is shared and which is yours.

This supersedes the claude-kit / addy-osmani arrangement (`.agent/` +
`/spec /plan /build`, everything gitignored). The shift is deliberate: dw-\*
treats agent infra as **real work** — specs, plans, handoffs, and guardrails are
committed and travel with the repo, not thrown away.

## What it writes

| Path                                      | Tracked?           | Purpose                                                                 |
| ----------------------------------------- | ------------------ | ----------------------------------------------------------------------- |
| `.ai/runs/` `.ai/handoffs/` `.ai/verify/` | **tracked**        | memory the dw-\* skills read/write (`.gitkeep` seeds empty dirs)        |
| `.claude/settings.json`                   | **tracked**        | permissions ask-list + hook wiring (shared with the team)               |
| `.claude/hooks/*.sh`                      | **tracked**        | guardrail scripts the committed settings reference                      |
| `CLAUDE.local.md`                         | personal / ignored | your About-me, preferences, project specifics, git conventions          |
| `.claude/settings.local.json`             | personal / ignored | personal-only setting overrides (only if you add one)                   |
| `.gitignore`                              | tracked            | a managed marker block — ignores the two personal files, **not** `.ai/` |

`.ai/` is tracked in git on purpose. Never overwrite a file blind — read what's
there first (step 1) and present a diff before writing (step 4).

## Modes

- **A · skeleton** — lay down the structure from templates with placeholders left
  in. Auto-detect stack + commands, pick hooks, write. Fast; you fill the prose
  later.
- **B · tuned** — skeleton, then **interview** the user and fill `CLAUDE.local.md`
  for this project and these preferences (the rich shape: About-me, stack
  cheat-sheet, git conventions, project specifics). This is the "pod siebie" mode
  and the main reason this is a skill, not a `sed` script.

## Workflow

### 1. Detect — never assume the stack

- Repo root (`git rev-parse --show-toplevel`), default branch
  (`git symbolic-ref --short refs/remotes/origin/HEAD`, else `init.defaultBranch`,
  else `main`).
- Stack + commands from manifests — `package.json` scripts, `Gemfile`,
  `Cargo.toml`, `pyproject.toml`, `go.mod`, `Makefile`. Read the real test / lint
  / typecheck commands; don't invent them.
- Read what already exists — `CLAUDE.md`, `CLAUDE.local.md`, `.claude/settings*`,
  `.gitignore`. **Flag the migration case**: a present `.agent/` dir or
  `claude-kit` markers mean this repo is on the old convention (see
  `references/bootstrap.md` → _Migrating off claude-kit_).

### 2. Pick mode + features — `AskUserQuestion`

- Mode **A skeleton** vs **B tuned**.
- Features to write (default all): `.ai/` memory · `settings.json` + hooks ·
  `CLAUDE.local.md` · `.gitignore` block.
- Hooks, filtered by detected stack: `block-dangerous-git` (always),
  `block-non-pnpm` + `lint-on-edit` + `typecheck-on-stop` (JS/TS), `lint-on-edit-rb`
  (Ruby). On stacks with no lint/typecheck hook, offer `block-dangerous-git` alone
  and note the rest are stack-specific (see `references/bootstrap.md` → _Stack → hooks_).

### 3. (Mode B only) Interview — fill the prose

Walk the question bank in `references/bootstrap.md` → _Interview_. Cover
About-me / preferences, project specifics, and git conventions. Keep it short —
ask, don't lecture; skip anything the user waves off.

### 4. HARD STOP — preview the plan and wait

List every path you're about to write, marked **tracked** or **ignored**, and for
any file that already exists show a diff (or "merge managed block only"). **Stop
and get explicit confirmation before writing.** Bootstrapping mutates the repo —
a wrong clobber is expensive. Do not write before the user confirms.

### 5. Write

- `mkdir -p .ai/{runs,handoffs,verify}` and seed each with `.gitkeep`.
- Copy `references/templates/settings.json` → `.claude/settings.json`; **prune**
  the hook entries the user didn't select, then confirm the file still parses as
  valid JSON.
- Copy the selected `references/templates/hooks/*.sh` → `.claude/hooks/` and
  `chmod +x` each.
- Render `references/templates/CLAUDE.local.md` → `CLAUDE.local.md`: substitute
  `{{PROJECT_NAME}}` `{{DEFAULT_BRANCH}}` `{{STACK}}` `{{TEST_COMMAND}}`
  `{{LINT_COMMAND}}` `{{TYPECHECK_COMMAND}}`, and build `{{HOOKS_INSTALLED}}` from
  the selected hooks. In tuned mode, also fill the About-me / specifics / git
  sections from the interview.
- Append `references/templates/gitignore-block.txt` to `.gitignore`, fenced by
  its `>>> dw-bootstrap managed block >>>` markers. **Idempotent**: if the markers
  are already present, replace the block in place — never duplicate it.

### 6. Reconcile tracking

The split is the whole point — enforce it after writing:

- Ensure `.ai/`, `.claude/settings.json`, `.claude/hooks/` are **not** ignored. If
  an old rule ignores them (claude-kit ignored all of these), remove it.
- Ensure `CLAUDE.local.md` and `.claude/settings.local.json` **are** ignored.
- **Migration (consent-gated):** if `.agent/` exists, offer to `git mv` its
  contents into `.ai/` and rewrite loop references (`/spec /plan /build` →
  `dw-spec / dw-plan / dw-build`, `.agent/` → `.ai/`) across `CLAUDE.md` /
  `CLAUDE.local.md`. Show the plan; don't move anything without a yes.

### 7. Report + hand off

List what was written and which paths to `git add` (the tracked ones). Confirm the
hooks are wired by pointing at `.claude/settings.json`. Then point the user at the
loop.

**Next:** `dw-spec` to open the first run for a feature, or `dw-git` to commit the
scaffold.

## Templates

`references/templates/` holds the exact files to copy:

- `CLAUDE.local.md` — the personal-memory template (placeholders + prompts).
- `settings.json` — tracked permissions + hooks (prune unselected hooks).
- `gitignore-block.txt` — the marker-fenced managed block.
- `hooks/block-dangerous-git.sh` · `hooks/block-non-pnpm.sh` · `hooks/lint-on-edit.sh` ·
  `hooks/lint-on-edit-rb.sh` · `hooks/typecheck-on-stop.sh`.

## References

- `references/bootstrap.md` — the interview question bank, the tracked-vs-ignored
  rationale, the stack→hooks table, idempotent re-run rules, and the
  migrating-off-claude-kit procedure. Read it before running Mode B or any
  migration.
