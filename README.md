# 🧩 dominikwozniak-skills

A personal bucket of Claude Code skills I actually use or share — distributed as an installable
plugin marketplace.

Each skill lives once in `skills/<name>/SKILL.md` and is exposed as a plugin via
`.claude-plugin/marketplace.json`. Install the marketplace once, then add the skills you want.

## 🚀 Quick start

```
claude plugin marketplace add git@github.com:dominikwozniak/dominikwozniak-skills.git
claude plugin install example-skill
```

`example-skill` is a placeholder/template — replace it with real skills over time.

## 📁 Layout

```
.
├── skills/                    # Canonical SKILL.md files (flat: skills/<name>/SKILL.md)
├── plugins/                   # Plugin manifests. Each has a git-tracked symlink:
│                              #   plugins/<name>/skills/<name> → ../../../skills/<name>
├── scripts/                   # validate-manifests.sh (backs pnpm validate:manifests)
└── .claude-plugin/            # marketplace.json
```

Every skill's canonical file lives in `skills/<name>/SKILL.md`. Each plugin's `skills/<name>` is a
git-tracked symlink (mode 120000) back to it — edit in `skills/`, never via the symlink. Windows
clones need `git config --global core.symlinks true`.

## ➕ Add a skill

Copy `example-skill` as the template:

1. `skills/<name>/SKILL.md` — kebab-case `name`, a `description` with trigger phrases.
2. `plugins/<name>/.claude-plugin/plugin.json` + the symlink:
   ```bash
   ln -s ../../../skills/<name> plugins/<name>/skills/<name>
   git add plugins/<name>/skills/<name>
   ```
3. Add a row to `.claude-plugin/marketplace.json` (keep the version in sync with `plugin.json`).
4. Add a line here in the README.
5. `pnpm lint && pnpm format && pnpm validate:manifests`.

`CLAUDE.md` has the full checklist.

## ✅ Quality bar

- `pnpm lint` — [`agnix`](https://github.com/agnix-dev/agnix) validates `CLAUDE.md`, `SKILL.md`, and
  the marketplace + plugin manifests (`.agnix.toml`).
- `pnpm format` — `prettier --check` on md/json/yaml (`proseWrap: preserve` so SKILL.md trigger
  tokens aren't rewrapped).
- `pnpm validate:manifests` — `claude plugin validate` on every `marketplace.json` and
  `plugin.json`, plus a version-sync check between marketplace entries and plugin manifests.

All three run in CI on `pull_request` and `push` to `main`; actions SHA-pinned, runner
`ubuntu-latest`. A `trufflehog` secrets scan runs alongside.

## 🔧 Repo prep

This repo dogfoods [`claude-kit`](https://github.com/dominikwozniak/claude-kit): its `bootstrap.sh`
drops local, gitignored agent files (`CLAUDE.local.md`, `.claude/settings.local.json`,
`.claude/hooks/`). Those are personal and never committed.

## 📜 License

MIT
