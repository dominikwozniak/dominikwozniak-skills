# 🧩 dominikwozniak-skills

A personal bucket of Claude Code skills I actually use or share — distributed as an installable
plugin marketplace.

Each skill lives once in `skills/<name>/SKILL.md` and ships inside a plugin (collection) listed in
`.claude-plugin/marketplace.json`. Install the marketplace once, then add the plugins you want.

## 🚀 Quick start

```
claude plugin marketplace add git@github.com:dominikwozniak/dominikwozniak-skills.git
claude plugin install dw-misc
```

`dw-misc` bundles cross-cutting helpers (e.g. `dw-handoff`).

## 🧩 Skills

- **`dw-spec`** (plugin `dw-planning`) — write a persistent feature spec to `.ai/runs/` with an Open-Questions hard gate before planning or coding.
- **`dw-resume`** (plugin `dw-planning`) — read-only: reconstruct where work stands from the active `.ai/runs/` run (branch-matched) and report the first not-done step — your resume point after a `/clear`.
- **`dw-plan`** (plugin `dw-planning`) — turn the active run's ready `SPEC.md` into a persistent `PLAN.md` status table of thin vertical slices (acceptance + verify per step), gated on your approval before writing — the anchor `dw-resume` and `dw-build` read.
- **`dw-build`** (plugin `dw-planning`) — build the active run's `PLAN.md` one step at a time: take the first not-done row, run RED → GREEN → regression → commit, then flip it to `done` + short SHA and append `NOTES.md`. Reads test/lint/run commands and `## Git conventions` from the project; `auto` builds the whole plan.
- **`dw-handoff`** (plugin `dw-misc`) — compact the session into a handoff doc at `.ai/handoffs/` for the next agent.
- **`dw-review`** (plugin `dw-quality`) — multi-axis review (correctness, readability, architecture, security, performance) of a change's diff, with findings as `file:line` + severity and an overall verdict, written to `.ai/verify/`.
- **`dw-explain`** (plugin `dw-quality`) — explain what a change does and generate runnable, code-grounded verification scenarios in `.ai/verify/`, ready for `dw-verify` to run.
- **`dw-verify`** (plugin `dw-quality`) — run the verification scenarios from `explain.md` and record PASS/FAIL/INCONCLUSIVE + evidence to `.ai/verify/`.
- **`dw-risk`** (plugin `dw-quality`) — assess a change's blast radius, out-of-code impact (migrations/env/flags/infra/secrets), and follow-ups/rollback to `.ai/verify/`.

## 🤝 Contributing

Layout, conventions, the add-a-skill checklist, CI, and repo prep all live in
[`AGENTS.md`](AGENTS.md) (`CLAUDE.md` is a symlink to it).

## 📜 License

MIT
