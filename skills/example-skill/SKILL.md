---
name: example-skill
description: >-
  Placeholder skill and copy-me template for this marketplace. Not meant to run —
  duplicate this directory to create a real skill. Use when scaffolding a new skill in this
  repo. Trigger phrases: "example skill", "skill template", "scaffold a new skill".
disable-model-invocation: true
---

# Example Skill

This is a **placeholder** that demonstrates the repo's skill layout. It does nothing on its own —
copy it to start a real skill.

## How to use this as a template

1. Copy `skills/example-skill/` to `skills/<your-skill>/` and rewrite this `SKILL.md` (kebab-case
   `name`, a `description` with trigger phrases).
2. Copy `plugins/example-skill/` to `plugins/<your-skill>/`, update `plugin.json`, and recreate the
   symlink:

   ```bash
   ln -s ../../../skills/<your-skill> plugins/<your-skill>/skills/<your-skill>
   git add plugins/<your-skill>/skills/<your-skill>
   ```

3. Add a row to `.claude-plugin/marketplace.json` (keep its version in sync with `plugin.json`).
4. Add a line to the README skill list.
5. Run `pnpm lint && pnpm format && pnpm validate:manifests`.

See `CLAUDE.md` for the full checklist.
