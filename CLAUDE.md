# dominikwozniak-skills — agent instructions

This is **not** a code project — it's a personal bucket of Claude Code skills, distributed as an
installable plugin marketplace. Scaffold and conventions copied from
[`claude-kit`](https://github.com/dominikwozniak/claude-kit).

## Repository layout

- **`skills/`** — canonical home for every skill. Flat: `skills/<name>/SKILL.md`. Edit skills HERE,
  never via the symlink under `plugins/`.
- **`plugins/`** — Claude Code plugins exposed via `.claude-plugin/marketplace.json`. Each plugin's
  `skills/<name>` is a **git-tracked symlink** (mode 120000) → `../../../skills/<name>`, plus
  `plugins/<name>/.claude-plugin/plugin.json`.
- **`scripts/`** — `validate-manifests.sh` (backs `pnpm validate:manifests`).
- **`.claude-plugin/marketplace.json`** — makes this repo installable as a Claude Code plugin
  source.

## Conventions

- Skills use YAML frontmatter; `disable-model-invocation: true` for explicit-invoke-only skills.
- Skill names: kebab-case, match the directory name.
- Canonical skill file: `skills/<name>/SKILL.md`. Each plugin pairs
  `plugins/<name>/.claude-plugin/plugin.json` with a symlink `plugins/<name>/skills/<name>` →
  `../../../skills/<name>`.
- `marketplace.json[].version` must match each `<source>/.claude-plugin/plugin.json.version`
  (enforced by `pnpm validate:manifests`).

## When adding a new skill

1. Create `skills/<name>/SKILL.md` (kebab-case `name`, `description` with trigger phrases).
2. Create `plugins/<name>/.claude-plugin/plugin.json` AND
   `ln -s ../../../skills/<name> plugins/<name>/skills/<name>` AND `git add` the symlink.
3. Add a row to `.claude-plugin/marketplace.json` (version in sync with `plugin.json`).
4. Update the README skill list.
5. `pnpm lint && pnpm format && pnpm validate:manifests`.

`example-skill` is a working template — copy it.

## CI

- `pnpm lint` — `agnix .` validates `CLAUDE.md`, `SKILL.md`, manifests (config: `.agnix.toml`;
  `.agent/` and `.claude/` excluded — local bootstrap drops).
- `pnpm format` — `prettier --check` on md/json/yaml (`.prettierrc.json`, `proseWrap: preserve`).
- `pnpm validate:manifests` — `claude plugin validate` + marketplace↔plugin version-sync.
- `secrets-scan` — `trufflehog` (SHA-pinned), full-history checkout.
- Workflows in `.github/workflows/` run on `pull_request` + `push` to `main`; actions SHA-pinned,
  runner `ubuntu-latest`.

## Repo prep (local, gitignored)

This repo dogfoods claude-kit's `bootstrap.sh`: `CLAUDE.local.md`, `.claude/settings.local.json`,
and `.claude/hooks/*.sh` are personal and **gitignored**. Re-running bootstrap is safe. No
husky/lint-staged here — CI + local hooks are the whole quality story (mirrors claude-kit).

## Future / not in scope

- `docs/` — omitted for v1; add if public-facing docs are needed.
- Re-hosting claude-kit's plugins — intentionally NOT here; they live in claude-kit.
