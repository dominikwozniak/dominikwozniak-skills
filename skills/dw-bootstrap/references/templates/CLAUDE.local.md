# {{PROJECT_NAME}} — local agent memory

Personal Claude Code memory for this project. Gitignored. `dw-bootstrap` dropped
this file — edit freely.

## About me — dev profile & preferences

Context for the agent. Read before starting a task. _(dw-bootstrap fills this in
**tuned** mode; in **skeleton** mode it stays as prompts — fill them yourself.)_

- **Background**: _(your primary stack; what you're newer at on this project)_
- **Communication language**: _(e.g. English; or "Polish mixed with English, technical
  terms in EN". Code, names, identifiers, commits, PRs — always EN.)_
- **Learning mode**: _(minimal / verbose; when to add analogies from a stack you know)_
- **Anything else the agent should assume about you** on this repo.

## Workflow

- Loop: `/dw-spec → /dw-plan → /dw-build`, then `/dw-review` · `/dw-verify` before a PR.
- Artifacts land in **`.ai/`** — **tracked in git**, committed alongside the code:
  - specs/plans/notes → `.ai/runs/<id>/` · verification → `.ai/verify/<branch-slug>/`
- `/dw-resume` picks up the active run for this branch after a `/clear`.
- `/dw-handoff` compacts the session into `.ai/handoffs/<YYYYMMDD-HHMM>.md` for the next agent.
- `/dw-sync` re-aligns the plan with the code after drift (consent-gated).

## Tools active in this session

- **gh CLI** — preferred over MCP for GitHub ops.
- _(add the rest you actually use: rtk, caveman, claude-mem, Linear/Atlassian/Notion via MCP,
  Sentry/Playwright via CLI. Check `claude mcp list`; drop bullets you don't use.)_

## Git conventions

Read by the `dw-git` skill. Overrides global defaults.

- **Commit format**: `[TICKET-XXX] type: description` if the branch encodes a ticket, else
  `type: description` — [Conventional Commits 1.0](https://www.conventionalcommits.org/en/v1.0.0/).
- **Default branch**: {{DEFAULT_BRANCH}}
- **Branch naming**: loose. Common when a ticket exists: `XYZ-123-short-slug` or `XYZ-123/short-slug`.
- **PR title**: same format as the commit subject.
- _(state your trailer policy, e.g. NO `Co-Authored-By`, NO "Generated with Claude Code" footer.)_
- **Rebase by default**: `git pull --rebase`, `git fetch origin && git rebase origin/{{DEFAULT_BRANCH}}`.
- **Modern verbs**: `git switch` / `git restore` over `git checkout`.
- **One logical change per commit.** Split when session work spans multiple concerns.

## Project specifics

- **Stack**: {{STACK}}
- **Test command**: {{TEST_COMMAND}}
- **Lint command**: {{LINT_COMMAND}}
- **Typecheck command**: {{TYPECHECK_COMMAND}}
- **Domain**: _(one-line gist, or a pointer to `CLAUDE.md` / docs)_
- **Key directories**: _(where the business logic lives)_
- **Deployment target**: _(how/where it ships)_
- **Gotchas**: _(local-only traps — add as you hit them)_

## Hooks installed

{{HOOKS_INSTALLED}}

Hook scripts live in `.claude/hooks/` and are **tracked** (so teammates get the same guardrails).

## Keep this file current

This file is the source of truth for the agent _and_ the hooks. If any of these change, update the
matching line here in the same commit:

- Test / lint / typecheck command → `## Project specifics` (the hooks read those names).
- Default branch renamed → `## Git conventions` (`dw-git` reads it).
- Stack, key directories, deployment target shifts → `## Project specifics`.
- New tool installed (MCP server, CLI) or one removed → `## Tools active in this session`.
- New hook wired in `.claude/settings.json` → add a line under `## Hooks installed`.

Stale placeholders silently break the linter, typecheck, and PR/commit flow.
