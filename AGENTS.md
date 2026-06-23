# dw-skills — agent instructions

A personal bucket of Claude Code skills, distributed as an installable plugin marketplace — not a
code project.

## Repository layout

- **`skills/`** — canonical home for every skill. Flat: `skills/<name>/SKILL.md`. Edit skills HERE,
  never via the symlink under `plugins/`.
- **`plugins/`** — Claude Code plugins exposed via `.claude-plugin/marketplace.json`. Each plugin's
  `skills/<name>` is a **git-tracked symlink** (mode 120000) → the repo-root canon
  `../../../skills/<name>`, plus `plugins/<name>/.claude-plugin/plugin.json`. A shipped script lives
  **inside its consuming skill** as `skills/<name>/scripts/<script>.sh` (a symlink → the runtime
  canon `../../../scripts/runtime/<script>.sh`) and is invoked **skill-relative** from the body as
  `<this-skill-dir>/scripts/<script>.sh`. `claude plugin install` **deep-dereferences** the skill
  dir: each plugin gets its own real copy in the cache (verified — the installed cache contains 0
  symlinks), and the same skill-relative path also resolves under Codex's `.codex/skills/` — so skill
  bodies carry **no `${CLAUDE_PLUGIN_ROOT}`** (Claude-only) and run unchanged in either agent. One
  canon can be symlinked into several skills (e.g. `slugify.sh` into all that need it) with no
  duplication and no drift.
- **`scripts/`** — repo home for shell scripts, split by purpose:
  - **`scripts/runtime/`** — canonical home for every **shipped** script (invoked skill-relative
    via `<this-skill-dir>/scripts/`, e.g. `slugify.sh`, `plan-status.sh`); symlinked into each
    consuming `skills/<name>/scripts/`.
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
2. Create `plugins/<name>/.claude-plugin/plugin.json` AND its **two** skill symlinks — the plugin
   one `ln -s ../../../skills/<name> plugins/<name>/skills/<name>` (Claude Code) AND the Codex one
   `ln -s ../../skills/<name> .codex/skills/<name>` (Codex in-repo discovery) — then `git add` both
   (each mode 120000). The `.codex/` link is what makes the skill discoverable to Codex working
   inside this repo; `validate-manifests.sh` checks it stays in sync.
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

## When adding a shared (multi-skill) script

1. Put the real file once under `scripts/runtime/<script>.sh` (`chmod +x`).
2. For each skill that invokes it:
   `ln -s ../../../scripts/runtime/<script>.sh skills/<name>/scripts/<script>.sh` AND
   `git add` the symlink (must be mode 120000, like the skill symlinks).
3. Invoke it from the skill body as `<this-skill-dir>/scripts/<script>.sh` — install deep-derefs the
   skill dir into real files in the plugin cache, and the same path resolves under Codex
   `.codex/skills/`. Never `${CLAUDE_PLUGIN_ROOT}` (Claude-only — `validate-manifests.sh` rejects it).
4. Add the basename to the `RUNTIME_SCRIPTS` list in `scripts/validate-manifests.sh`, and — where
   it has testable logic — a `scripts/tests/<script>.test.sh` (anchored to the repo root via
   `git rev-parse --show-toplevel`, like `validate-ai-artifacts.test.sh`).

A script used by only **one** skill stays bundled in that skill's `scripts/` dir as a real file
(invoked the same way, `<this-skill-dir>/…`), e.g. `dw-doctor` — no runtime canon needed.

## Running these skills under Codex (and other agents)

The skills are plain `SKILL.md` — the open skill format Codex CLI also reads — so they run under
Codex with no conversion, frontmatter and all (`name`, `description`, `disable-model-invocation`).
Two install paths:

- **In this repo**: committed `.codex/skills/<name>` symlinks → `skills/<name>`, so Codex picks the
  skills up when working inside this repo.
- **Machine-wide**: `bash scripts/install-codex.sh` symlinks every `skills/*` into `~/.codex/skills/`.

Scripts resolve because skill bodies call them skill-relative (`<this-skill-dir>/scripts/<s>.sh`),
which works through the `.codex/skills/<name>` symlink regardless of the working directory.

**Claude-only, does not carry over**: the `.claude/` hooks (`block-dangerous-git.sh`, …) are Claude
Code session guardrails and do **not** fire under Codex; the `.claude-plugin/` marketplace is
Claude-only too (Codex installs by directory placement, not a marketplace). This `AGENTS.md` is what
Codex and other AGENTS.md-readers load; `CLAUDE.md` is a symlink to it, so both agents read one guide.

## CI

Runs on every PR + push to `main`:

- `pnpm lint` — `agnix` validates `CLAUDE.md`/`SKILL.md`/manifests.
- `pnpm format` — `prettier --check` (`proseWrap: preserve`).
- `pnpm validate:manifests` — `claude plugin validate` + marketplace↔plugin version sync.
- `pnpm validate:artifacts` — `.ai/` artifact schema + runtime-script self-tests under `scripts/tests/`.
- `pnpm validate:docs` — README/`docs/DESIGN.md` ↔ skills sync (dead links, undocumented skills,
  explicit-invoke `⭑` consistency).
- `trufflehog` secrets scan.
