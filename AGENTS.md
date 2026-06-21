# dominikwozniak-skills — agent instructions

A personal bucket of Claude Code skills, distributed as an installable plugin marketplace — not a
code project.

## Repository layout

- **`skills/`** — canonical home for every skill. Flat: `skills/<name>/SKILL.md`. Edit skills HERE,
  never via the symlink under `plugins/`.
- **`plugins/`** — Claude Code plugins exposed via `.claude-plugin/marketplace.json`. Each plugin's
  `skills/<name>` and its shipped `scripts/<script>.sh` are **git-tracked symlinks** (mode 120000) →
  the repo-root canon — `../../../skills/<name>` and `../../../scripts/runtime/<script>.sh` — plus
  `plugins/<name>/.claude-plugin/plugin.json`. `claude plugin install` **dereferences** these
  symlinks: each plugin gets its own real copy in the plugin cache (verified — the installed cache
  contains 0 symlinks), so a script is invoked from skill bodies via the unchanged
  `${CLAUDE_PLUGIN_ROOT}/scripts/<script>.sh`. Because install dereferences, one canonical script
  can be symlinked into several plugins (e.g. `slugify.sh` into both `dw-planning` and `dw-quality`)
  with no duplication. (A script used by **one** skill instead stays bundled in that skill:
  `skills/<name>/scripts/` invoked via `<this-skill-dir>/…`, e.g. `dw-doctor`.)
- **`scripts/`** — repo home for shell scripts, split by purpose:
  - **`scripts/runtime/`** — canonical home for every **plugin-level shipped** script (invoked at
    runtime via `${CLAUDE_PLUGIN_ROOT}/scripts/`, e.g. `slugify.sh`, `plan-status.sh`); symlinked
    into each consuming `plugins/<name>/scripts/`.
  - **`scripts/`** (top level) — repo CI/validation tooling, never shipped (e.g.
    `validate-manifests.sh` / `validate-artifacts.sh` backing `pnpm validate:*`, `lint.sh`).
  - **`scripts/tests/`** — bash self-tests for the runtime scripts (`<script>.sh` ↔
    `<script>.test.sh`), run via `pnpm validate:artifacts`.
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
     the explicit-only lists in README **How it works** _and_ `docs/DESIGN.md` — all three are
     enforced by `pnpm validate:docs`, so a missed one fails CI rather than drifting silently.
6. `pnpm lint && pnpm format && pnpm validate:manifests && pnpm validate:docs`.

Copy an existing skill (e.g. `dw-handoff`) as a starting point.

## When adding a plugin-level (shared) script

1. Put the real file once under `scripts/runtime/<script>.sh` (`chmod +x`).
2. For each plugin that ships it:
   `ln -s ../../../scripts/runtime/<script>.sh plugins/<plugin>/scripts/<script>.sh` AND
   `git add` the symlink (must be mode 120000, like the skill symlinks).
3. Invoke it from skill bodies as `${CLAUDE_PLUGIN_ROOT}/scripts/<script>.sh` — install
   dereferences the symlink to a real file in the plugin cache, so the path resolves.
4. Add the basename to the `RUNTIME_SCRIPTS` list in `scripts/validate-manifests.sh`, and — where
   it has testable logic — a `scripts/tests/<script>.test.sh` (anchored to the repo root via
   `git rev-parse --show-toplevel`, like `validate-ai-artifacts.test.sh`).

A script used by only **one** skill stays bundled in that skill's `scripts/` dir instead (invoked
via `<this-skill-dir>/…`), e.g. `dw-doctor` — no canon/symlink needed.

## CI

Runs on every PR + push to `main`:

- `pnpm lint` — `agnix` validates `CLAUDE.md`/`SKILL.md`/manifests.
- `pnpm format` — `prettier --check` (`proseWrap: preserve`).
- `pnpm validate:manifests` — `claude plugin validate` + marketplace↔plugin version sync.
- `pnpm validate:artifacts` — `.ai/` artifact schema + runtime-script self-tests under `scripts/tests/`.
- `pnpm validate:docs` — README/`docs/DESIGN.md` ↔ skills sync (dead links, undocumented skills,
  explicit-invoke `⭑` consistency).
- `trufflehog` secrets scan.
