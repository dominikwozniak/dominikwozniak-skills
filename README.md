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
- **`dw-handoff`** (plugin `dw-misc`) — compact the session into a handoff doc at `.ai/handoffs/` for the next agent.
- **`dw-explain`** (plugin `dw-quality`) — explain what a change does and generate runnable, code-grounded verification scenarios in `.ai/verify/`, ready for `dw-verify` to run.

## 🤝 Contributing

Layout, conventions, the add-a-skill checklist, CI, and repo prep all live in
[`AGENTS.md`](AGENTS.md) (`CLAUDE.md` is a symlink to it).

## 📜 License

MIT
