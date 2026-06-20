# dominikwozniak-skills — agent instructions

A personal bucket of Claude Code skills, distributed as an installable plugin marketplace — not a
code project.

## Repository layout

- **`skills/`** — canonical home for every skill. Flat: `skills/<name>/SKILL.md`. Edit skills HERE,
  never via the symlink under `plugins/`.
- **`plugins/`** — Claude Code plugins exposed via `.claude-plugin/marketplace.json`. Each plugin's
  `skills/<name>` is a **git-tracked symlink** (mode 120000) → `../../../skills/<name>`, plus
  `plugins/<name>/.claude-plugin/plugin.json`. A script **shared by more than one skill in the same
  plugin** lives once under `plugins/<name>/scripts/` (a real file, not a symlink) and is invoked
  from skill bodies as `${CLAUDE_PLUGIN_ROOT}/scripts/<script>.sh` — the env var Claude Code
  substitutes to the installed plugin's dir. (A script used by **one** skill stays bundled in that
  skill: `skills/<name>/scripts/` invoked via `<this-skill-dir>/…`, e.g. `dw-doctor`.) Installs copy
  the plugin into the plugin cache (outside the repo tree), so a skill can't reach a sibling skill's
  dir by relative path — hence the plugin-level home for shared scripts.
- **`scripts/`** — repo CI/validation tooling only (e.g. `validate-manifests.sh`, backing
  `pnpm validate:manifests`) — not skill runtime assets.
- **`.claude-plugin/marketplace.json`** — makes this repo installable as a Claude Code plugin
  source.

## Conventions

- Skills use YAML frontmatter; `disable-model-invocation: true` for explicit-invoke-only skills.
- Skill name: kebab-case, matches the directory name.
- Canonical file is `skills/<name>/SKILL.md` — edit there, never via the plugin symlink.
- `marketplace.json` version must match the plugin's `plugin.json` version (checked by
  `pnpm validate:manifests`).

## When adding a new skill

1. Create `skills/<name>/SKILL.md` (kebab-case `name`, `description` with trigger phrases),
   following the shape in [`docs/SKILL-ANATOMY.md`](docs/SKILL-ANATOMY.md).
2. Create `plugins/<name>/.claude-plugin/plugin.json` AND
   `ln -s ../../../skills/<name> plugins/<name>/skills/<name>` AND `git add` the symlink.
3. Add a row to `.claude-plugin/marketplace.json` (version in sync with `plugin.json`).
4. Bump the plugin's patch version in **both** `plugins/<name>/.claude-plugin/plugin.json` and the
   matching `.claude-plugin/marketplace.json` entry — they must stay in sync (CI enforces it via
   `validate-manifests.sh`).
5. Update the docs that name skills — more than just the README Plugins + task-router. Grep the
   skill name across `README.md` and `docs/DESIGN.md` to catch every hit; the usual ones:
   - README **Plugins** section and **task-router table** row (trigger phrase + output shape).
   - README **workflow diagram** if the skill joins the core spec→ship loop, and the **Quick
     start** install-comment if a plugin's skill list changes.
   - If explicit-invoke (`disable-model-invocation: true`): the `⭑` in the task-router table, plus
     the explicit-only lists in README **How it works** _and_ `docs/DESIGN.md`.
6. `pnpm lint && pnpm format && pnpm validate:manifests`.

Copy an existing skill (e.g. `dw-handoff`) as a starting point.

## CI

Runs on every PR + push to `main`:

- `pnpm lint` — `agnix` validates `CLAUDE.md`/`SKILL.md`/manifests.
- `pnpm format` — `prettier --check` (`proseWrap: preserve`).
- `pnpm validate:manifests` — `claude plugin validate` + marketplace↔plugin version sync.
- `trufflehog` secrets scan.
