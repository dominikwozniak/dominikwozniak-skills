# Skills Build Roadmap — `dw-*`

> **Po co ten dok.** `docs/skills-research.md` (v4) odpowiada na **co i dlaczego** (architektura, katalog,
> connector, agnostyczność, thin/fat). Ten dok odpowiada na **jak, w jakiej kolejności i kiedy „done"** — tak,
> żeby osobna sesja, dostawszy cienki wskaźnik („zbuduj następny skill wg roadmapy"), zbudowała skill
> end-to-end bez prowadzenia za rękę.
>
> **Launch sesji:** patrz [Sekcja 5 — Lean prompt](#5-lean-session-prompt-template). Pilot = `dw-handoff`.

---

## 1. Readiness — czy sesje mogą ruszyć

| Prerekwizyt                                                                                                    | Status                                                |
| -------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------- |
| `docs/skills-research.md` (design: katalog §5, szablony §6, connector §4.6, agnostyczność §4.5, thin/fat §4.7) | ✅                                                    |
| `AGENTS.md` — „When adding a new skill" (5-krokowy checklist)                                                  | ✅                                                    |
| wzór do sklonowania: `skills/dw-handoff/` + `plugins/dw-misc/` (example-skill usunięty w pilocie #1)           | ✅                                                    |
| `skill-creator` (Anthropic) — zainstalowany + model-invocable                                                  | ✅                                                    |
| acceptance: `pnpm lint && pnpm format:fix && pnpm validate:manifests`                                          | ✅                                                    |
| hooki znane (pnpm-only, block-dangerous-git, lint-on-edit)                                                     | ✅                                                    |
| **collection-plugin rule** (example = plugin-per-skill; `dw-*` = plugin-per-kolekcja → konflikt)               | ❌ → [Sekcja 3](#3-struktura-plugin-per-kolekcja)     |
| **definition-of-done** (rozsiane po §4/§5/§6 research)                                                         | ❌ → [Sekcja 2](#2-build-contract-definition-of-done) |
| **szablony §6** jako pliki                                                                                     | ❌ → powstają w sesji `dw-spec` (#2)                  |

**Werdykt: po tym doku — TAK.** Trzy luki domyka ten plik. Pojedynczy skill = jeden `SKILL.md` (+ ewentualnie
`references/`) + plumbing — dekompozycja już zrobiona (research §7 + §5), więc **`/planning-and-task-breakdown`
nie jest potrzebny per-skill** (własny flow `skill-creator` JEST breakdownem skilla).

---

## 2. Build contract — definition-of-done

Checklist, którą sesja wykonuje dla każdego `dw-*`:

1. **Frontmatter** — kebab-case `name` (= nazwa katalogu); `description` z trigger phrases; `disable-model-invocation: true`
   **tylko** dla explicit-only: `dw-handoff`, `dw-prune`, `dw-sync`.
2. **Body** — procedura + guardy. Ścieżki `.ai/...` **zaszyte w body** (persistence-in-body, research §4.3).
   **Technology-agnostic**: komendy (test/lint/run/db/console/server) **czytane z projektu**, nie z skilla
   (research §4.5). Waga skilla = złożoność procedury; detale (szablony, przykłady stacków, taksonomie) →
   `references/`, nie do body (thin/fat, research §4.7).
3. **`references/`** — gdy trzeba: szablony artefaktów; `examples-*.md` zawsze oznaczone „przykład", nie logika.
4. **Plumbing** — plugin-per-kolekcja, patrz [Sekcja 3](#3-struktura-plugin-per-kolekcja).
5. **Acceptance** — `pnpm lint && pnpm format:fix && pnpm validate:manifests` wszystko zielone.
   **Brak `pnpm test` / `pnpm typecheck`** — niezdefiniowane w `package.json`, **nie wołać**.
6. **Guardraile** — pnpm-only (`npm`/`yarn`/`bun` blokowane hookiem; `npx`/`pnpm dlx` OK). **Commit/push tylko
   gdy user wprost poprosi.** **NIE ruszać `CLAUDE.local.md` ani migracji `.agent`→`.ai`** — D2/D4 z research
   odroczone „do czasów wdrożenia".

---

## 3. Struktura plugin-per-kolekcja

`dw-*` używa **plugin-per-kolekcja**: `plugins/dw-planning`, `plugins/dw-quality`, `plugins/dw-misc`. Każdy
plugin trzyma N symlinków w swoim `skills/`. (Sprawdzony wzór z pilota #1: `plugins/dw-misc/` z symlinkiem do
`skills/dw-handoff` — skopiuj tę strukturę. `example-skill` był plugin-per-skill, usunięty w pilocie.)

- **Pierwszy skill w kolekcji tworzy plugin:**
  1. `skills/<name>/SKILL.md` (kanoniczny).
  2. `plugins/<kolekcja>/.claude-plugin/plugin.json` (`name` = nazwa kolekcji, `version`, `description`,
     `author`, `"skills": "./skills"`).
  3. `ln -s ../../../skills/<name> plugins/<kolekcja>/skills/<name>` + `git add plugins/<kolekcja>/skills/<name>`.
  4. Wiersz w `.claude-plugin/marketplace.json` (`name`/`version`/`source`/`keywords`/`category`/`tags`).
  5. Wiersz w README `## 🧩 Skills`.
- **Kolejny skill w istniejącej kolekcji:** tylko symlink (krok 3) + bump **patch** w `plugin.json` **i**
  `marketplace.json` + wiersz w README. (Wersje plugin.json ↔ marketplace.json **muszą być równe** — sprawdza
  `scripts/validate-manifests.sh`.)
- **README format:** `- **`<name>`** — <opis>.`

---

## 4. Build order

### Faza 0 — bootstrap (ręcznie: `skill-creator` + lean prompt; `dw-*` jeszcze nie istnieją do dogfoodu)

| #   | Skill                          | Kolekcja      | Nowy plugin?               | Czyta                               | Pisze / tworzy                                                            | Invoke         |
| --- | ------------------------------ | ------------- | -------------------------- | ----------------------------------- | ------------------------------------------------------------------------- | -------------- |
| 1   | **`dw-handoff`** (PILOT)       | `dw-misc`     | tak (tworzy `dw-misc`)     | port z claude-kit `session-handoff` | `.ai/handoffs/<YYYYMMDD-HHMM>.md` + back-pointer do aktywnego runu        | explicit-only  |
| 2   | **`dw-spec`** + szablony       | `dw-planning` | tak (tworzy `dw-planning`) | request; wzorce repo                | `.ai/runs/<id>/SPEC.md` + **`references/templates/{SPEC,PLAN,NOTES}.md`** | model+explicit |
| 3   | **`dw-resume`**                | `dw-planning` | nie                        | globuje `.ai/runs/*/PLAN.md`        | nic (read-only)                                                           | model+explicit |
| 4   | **`dw-plan`** + **`dw-build`** | `dw-planning` | nie                        | SPEC/PLAN; `## Git conventions`     | `PLAN.md` (status table) + kod/testy + flip done+SHA                      | model+explicit |

Pilot `dw-handoff` celowo pierwszy: port (źródło w claude-kit), self-contained, najniższe ryzyko →
wytrząsa **cały** pipeline (skill-creator → SKILL.md → plugin.json → symlink → marketplace.json → README →
`pnpm validate`) zanim wejdziemy w nowicjowe skille.

### Faza 1 — dogfood-capable (gdy `dw-spec`/`dw-plan` istnieją, można nimi spec/plan resztę)

| #   | Skill                                               | Kolekcja      | Nowy plugin?              |
| --- | --------------------------------------------------- | ------------- | ------------------------- |
| 5   | **`dw-explain`** → **`dw-verify`** → **`dw-risk`**  | `dw-quality`  | tak (tworzy `dw-quality`) |
| 6   | **`dw-review`** + **`dw-conform`** + **`dw-prune`** | `dw-quality`  | nie                       |
| 7   | **`dw-sync`**                                       | `dw-planning` | nie                       |

**Zależności twarde:** `dw-resume`/`dw-plan`/`dw-build` zależą od kształtu `PLAN.md` → **szablony muszą powstać
w #2**. Klaster `dw-quality` łączy się artefaktem `.ai/verify/<branch>/` (research §4.6) — kolejność
rekomendowana, nie wymuszona (connector = artefakt + „Next:" pointer, nie sztywny łańcuch).

### Metoda buildu per skill

§5 (lean prompt) to **uniwersalny builder** — buduje praktycznie każdy `dw-*`. Żaden skill nie potrzebuje
`scripts/` (wszystkie to markdown-procedury czytające komendy z projektu, research §4.5). Różnice = **timing**
i **scope**, nie metoda:

| Metoda                         | Skille                                              | Uwaga                                                                                                                                                                                                                      |
| ------------------------------ | --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **§5 czysty**                  | `dw-handoff`, `dw-review`, `dw-conform`, `dw-prune` | self-contained; `dw-handoff` = port (źródło w §5 prompt).                                                                                                                                                                  |
| **§5 (fat) + `references/`**   | `dw-explain`, `dw-verify`, `dw-risk`                | większe; scenariusze typowane / przykłady → `references/` (§4.7). W promptcie dorzuć: „fat skill, detale do references/".                                                                                                  |
| **§5, ale dopiero po #2**      | `dw-resume`, `dw-plan`, `dw-build`, `dw-sync`       | gate: czytają kształt `PLAN.md` ze wspólnych szablonów (#2). Build = autorowanie markdown (że runtime `dw-build` pisze kod — bez znaczenia dla metody buildu).                                                             |
| **§5 + addendum (inny scope)** | `dw-spec`                                           | **jedyny realnie inny** — tworzy też **wspólne** `references/templates/{SPEC,PLAN,NOTES}.md` (research §6), konsumowane przez #3/#4. Sesja = „1 skill + 3 szablony". explain/verify → przy dw-quality. Patrz wariant w §5. |

**Opcjonalny dogfood (Faza 1):** gdy `dw-spec`+`dw-plan` istnieją, skille Fazy 1 (`dw-explain`→…) można budować
**inaczej** niż surowym §5 — odpal `dw-spec` (zspecuj skill) → `dw-plan` (zaplanuj) → build. Harness buduje sam
siebie i testuje pętlę na żywo. Nie wymagane; bogatsze.

---

## 5. Lean session-prompt template

Szablon do odpalenia każdej sesji (user wypełnia `<…>`). **Krok 2 = jawne wywołanie `skill-creator`** —
autoruje BODY skilla; plumbingu repo skill-creator NIE zna, więc plumbing robisz ręcznie w kroku 3.

```
Zbuduj skill `dw-<name>` dla marketplace dominikwozniak-skills. Kroki:

1. Przeczytaj:
   - docs/skills-research.md §<sekcje>  (np. dw-handoff → §5.3; dw-explain → §5.2, §4.5, §4.7)
   - docs/skills-roadmap.md  (§2 definition-of-done, §3 plumbing plugin-per-kolekcja, §4 gdzie ten skill siedzi)
   - AGENTS.md  (When adding a new skill)
2. Wywołaj skill `skill-creator` (Anthropic) — wpisz `/skill-creator` — i autoruj BODY SKILL.md.
   [Jeśli port: źródło = <ścieżka w claude-kit, np. .../dominikwozniak-claude-kit/skills/session-handoff/SKILL.md>.]
   Pomiń eval/benchmark loop skill-creatora (overkill dla tych skilli). skill-creator NIE zna plumbingu repo.
3. Plumbing plugin-per-kolekcja wg roadmapy §3 + AGENTS.md:
   skills/<name>/SKILL.md, plugins/<kolekcja>/.claude-plugin/plugin.json, symlink, wiersz w marketplace.json, README.
4. Done = build contract roadmapy §2.
   Waliduj: pnpm format:fix && pnpm validate:manifests  (wszystko zielone).
   NIE commituj/pushuj bez mojej zgody. NIE ruszaj CLAUDE.local.md.
```

**Wariant dla `dw-spec` (#2) — dorzuć krok 2b** (tworzy wspólne szablony, których używa #3/#4):

```
2b. Oprócz body skilla stwórz wspólne szablony wg docs/skills-research.md §6:
    skills/dw-spec/references/templates/{SPEC,PLAN,NOTES}.md
    Te szablony konsumują dw-resume/dw-plan/dw-build (kolekcja dw-planning) — bez nich #3/#4 nie ruszą.
    NIE twórz tu explain/verify — to artefakty dw-quality, powstaną z dw-explain/dw-verify (research §6:
    „szablony w odpowiednich skillach"; dw-quality bywa instalowane bez dw-planning → self-contained).
```

Po wbudowaniu Fazy 0 launch reszty skraca się do: **„zbuduj następny niezbudowany skill wg
`docs/skills-roadmap.md`"** — sesja sama znajduje swoje miejsce w sekcji 4, czyta contract i plumbing, leci.

---

## 6. Stan postępu

| Skill        | Kolekcja      | Status          |
| ------------ | ------------- | --------------- |
| `dw-handoff` | `dw-misc`     | ✅ done (pilot) |
| `dw-spec`    | `dw-planning` | ✅ done         |
| `dw-resume`  | `dw-planning` | ✅ done         |
| `dw-plan`    | `dw-planning` | ✅ done         |
| `dw-build`   | `dw-planning` | ✅ done         |
| `dw-explain` | `dw-quality`  | ✅ done         |
| `dw-verify`  | `dw-quality`  | ✅ done         |
| `dw-risk`    | `dw-quality`  | ✅ done         |
| `dw-review`  | `dw-quality`  | ✅ done         |
| `dw-conform` | `dw-quality`  | ✅ done         |
| `dw-prune`   | `dw-quality`  | ✅ done         |
| `dw-sync`    | `dw-planning` | ✅ done         |

> Każda sesja po zbudowaniu skilla flipuje swój wiersz na ✅ (jedyna edycja tego doku, jaką robi sesja budująca).
