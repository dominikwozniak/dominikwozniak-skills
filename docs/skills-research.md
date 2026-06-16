# Research v4: reużywalne skills do agentic workflow dla `dominikwozniak-skills`

> **Kontekst.** Chcę, żeby `dominikwozniak-skills` trzymało te Claude Code skills, których _realnie_ używam
> w pracy z agentami (głównie `ahplus-rails`, też JS/TS — AirHelp web, później inne projekty). Obecna pętla —
> addyosmani/agent-skills `/spec → /plan → /build` — frustruje mnie z jednego głównego powodu: **plany nie są
> zapisywane na dysk**, więc wylatują z pamięci agenta i ciężko o weryfikację. Podoba mi się setup `.ai/` z
> Open-Mercato, testowałem OpenSpec (za ciężki / słaby multi-thread / token-costly), nie testowałem SpecKita.
>
> To jest **dokument badawczy (research)**, nie implementacja. Decyzje wbudowane przez review: `dw-` prefix,
> `.ai/` **trackowany** (nie ignored — to realna praca jak OM), kolekcje pluginów, katalog **self-contained**
> (nie pomijamy skilla tylko dlatego, że gdzieś indziej istnieje), port `session-handoff` z claude-kit,
> **skills w 100% technology-agnostic** — fakty o stacku czytane z projektu, nie zaszyte w skillu (v3).
>
> **v4 zamyka pętlę decyzji D1–D5** i dodaje dwa wyniki researchu: (a) **connector/kompozycja między skillami**
> (D3 — jak inni łączą skille: agent-skills, Open-Mercato, Matt Pocock); (b) **uzgodnienie filozofii
> „thin harness, fat skills”** z „chudymi” skillami Pococka (sekcja 4.7). Zmiany: `dw-utils` → **`dw-misc`**
> (D1), connector design (4.6), authoring philosophy (4.7), D1–D5 rozstrzygnięte (sekcja 8).

---

## 0. TL;DR (kompletna rekomendacja)

1. **Build własnych lekkich skills od zera** (nie fork, nie wrap agent-skills), wzorowane na run-folderze OM,
   z jedną kluczową zmianą: **persistence wbudowany w body SKILL-a, nie w command wrapper.** To zabija problem #1.
2. **Wszystkie artefakty w `.ai/` — TRACKOWANYM w git** (jak OM `.ai/`, NIE gitignored), **jeden samodzielny
   folder na task, BEZ współdzielonego index file.** Brak indexu jest teraz _ważniejszy_: przy trackowaniu
   współdzielony plik konfliktowałby przy merge; per-task foldery (unikalne slugi) nie konfliktują.
3. **Prefix `dw-`** (mirror `om-` z OM), krótkie verby. **3 kolekcje pluginów:**
   - **`dw-planning`:** `dw-spec`, `dw-plan`, `dw-build`, `dw-resume`, `dw-sync`.
   - **`dw-quality`:** `dw-review`, `dw-conform`, `dw-prune`, `dw-explain`, `dw-verify`, `dw-risk`.
   - **`dw-misc`** (zmiana nazwy z `dw-utils`, D1): `dw-handoff` (port z claude-kit) + bucket rozwojowy na
     przyszłe cross-cutting (np. `dw-git`, `dw-context`).
4. **Skills w 100% technology-agnostic.** Workflow (spec→plan→build→review→explain→verify→risk) to czyste
   procedury — **żadna wiedza o stacku nie jest zaszyta w skillu.** Komendy (test/lint/run/db/console/server)
   skill **czyta z projektu**: blok komend w CLAUDE.md/AGENTS.md → manifesty (package.json scripts, Gemfile +
   `bin/`, Makefile, Procfile) → sam kod. Dokładnie wzorzec claude-kit `git-workflow` (czyta `## Git
conventions`, fallback do defaults). Rails/Node tylko jako _ilustracyjne przykłady_ w `references/`, nigdy
   jako gałęzie logiki skilla. (Szczegóły + edge case'y: 4.5.)
5. **Katalog self-contained.** Nie zależy od zewnętrznych skills (qa-analyst, ci-diagnosis, understand-diff,
   `verify`) — bo te mogą zniknąć / mogę ich nie używać. Opcjonalna kompozycja, nie zależność. Dlatego
   `dw-review` (krok 4) JEST w katalogu, mimo że istnieją inne reviewery.
6. **`git-workflow` zostaje w claude-kit** (infra, działa, czyta CLAUDE.local.md); `dw-build` czyta te same
   `## Git conventions`. `session-handoff` → przebudowany jako `dw-handoff` w `dw-misc`, piszący do
   `.ai/handoffs/` i linkujący aktywny run.
7. **Kolejność buildu:** `dw-spec` + szablony + `dw-resume` (zabija amnezję) → `dw-plan` + `dw-build` →
   klaster `dw-quality` (`dw-explain`/`dw-verify`/`dw-risk` = największa unikalna wartość) → reszta.
8. **Connector między skillami = artefakt + lekki „Next:” pointer, NIE sztywne łańcuchy** (D3, sekcja 4.6).
   Skille zostają **osobne** (różne osie), a łączy je trzy-warstwowy connector: (1) **wspólny artefakt** w
   `.ai/verify/<branch>/` — najsilniejszy, jak OM `specs/`→`runs/`→PR; (2) **„Next:” pointer + opcjonalna
   delegacja w body** (jak agent-skills „Following X” / Pocock „hand off to /Y”); (3) **cienki router** =
   `README`/katalog kolekcji (jak OM Task Router / agent-skills Lifecycle Sequence), bez wymuszania kolejności.
9. **Filozofia autorska: „thin harness, fat skills” — ale waga skilla = złożoność procedury** (sekcja 4.7).
   Pocock NIE przeczy tej zasadzie: jego skille są _bimodalne_ — chude triggery (7–15 linii) i tłuste
   procedury (80–131 linii) z offloadem szczegółów do `references/`. Harness cienki, procedura w skillu.
   Nasze `dw-*` tak samo: `dw-resume` chudy, `dw-explain`/`dw-build` tłuste, detale do `references/`.

---

## 1. Problem — precyzyjnie

Trzy strukturalne słabości obecnej pętli:

- **Brak trwałego planu.** agent-skills _potrafi_ zapisać (`SPEC.md`, `tasks/plan.md`, `tasks/todo.md`), ale
  tylko przez wrappery `.claude/commands/*.md`, z zahardkodowanymi ścieżkami. Przenośne body `SKILL.md`
  **celowo nie** narzucają lokalizacji (żeby działały w Cursor/Gemini/itd.). Efekt: persistence kruchy, ląduje
  w złym miejscu (root / `tasks/`, nie w Twoim folderze) i kończy się ręczną prośbą „zapisz do…” za każdym razem.
- **Brak deterministycznego resume.** Po `/clear` / w nowej sesji agent odtwarza kontekst ze scrollbacku. Brak
  kotwicy „pierwszy nie-zrobiony krok”.
- **Weryfikacja wymyślana od nowa.** Kroki 6/7 (wytłumacz zmianę + scenariusze SQL/console/curl + odpal) to
  czysta wartość, ale żyją tylko w konwersacji — nigdy jako artefakt do otwarcia w sesji review.

---

## 2. Twój workflow rozłożony → skill (z prefiksem `dw-`)

| #   | Twój krok                                                           | Reużywalne?               | Skill                                              | Kolekcja      |
| --- | ------------------------------------------------------------------- | ------------------------- | -------------------------------------------------- | ------------- |
| 1   | Plan + implementacja (`/spec→/plan→/build`)                         | ✅ core                   | `dw-spec` + `dw-plan` + `dw-build` (+ `dw-resume`) | `dw-planning` |
| 2   | Luki w logice → re-do / re-sync planu do kodu                       | ✅                        | `dw-sync`                                          | `dw-planning` |
| 3   | Twój eyeball review logiki (nie głęboko w Ruby)                     | ❌                        | **akt ludzki — brak skilla**                       | —             |
| 4   | Osobna sesja review                                                 | ✅ (teraz budujemy)       | `dw-review`                                        | `dw-quality`  |
| 5   | Porównanie do wzorców w projekcie; re-review przy drifcie           | ✅ **luka**               | `dw-conform`                                       | `dw-quality`  |
| 5.1 | Odchudzenie nadmiarowych/błędnych testów                            | ✅ **luka**               | `dw-prune` (explicit-only)                         | `dw-quality`  |
| 6   | „Wytłumacz co się stało” + **uruchamialne scenariusze weryfikacji** | ✅ **luka kluczowa**      | `dw-explain`                                       | `dw-quality`  |
| 7   | Odpal SQL/console/curl; sprawdź logi/output; sonduj edge case'y     | ✅ **luka**               | `dw-verify`                                        | `dw-quality`  |
| 8   | Pre-deploy safety: side-effects, zmiany poza kodem, follow-upy      | ✅ **luka**               | `dw-risk`                                          | `dw-quality`  |
| —   | Handoff sesji                                                       | ✅ (port z claude-kit)    | `dw-handoff`                                       | `dw-misc`     |
| —   | Git (commit/push/PR/sync wg konwencji)                              | ✅ (zostaje w claude-kit) | `git-workflow` (claude-kit)                        | —             |

Krok 3 = jedyny nie-skill (ludzki osąd). Krok 4 — _teraz w katalogu_ (punkt: nie pomijamy bo istnieje gdzie indziej).

---

## 3. Analiza landscape (skrót — pełna w v1 historii)

- **agent-skills** — dobra _dyscyplina_ (vertical slicing, RED→GREEN→commit, anti-rationalization), ale
  persistence _celowo_ odsprzężony do `.claude/commands/` z zahardkodowanymi ścieżkami → nie podróżuje z
  pluginem, ląduje źle. **Connector:** meta-skill `using-agent-skills` (drzewo dyskryminacyjne) + niewymuszona
  **Lifecycle Sequence** (16 kroków) + odwołania po nazwie w prozie („Following `incremental-implementation`”) +
  handoff przez artefakt (spec → tasks → kod → testy → review), bez zahardkodowanych ścieżek. Przepisać prozę
  jako referencję, nie uzależniać się.
- **Open-Mercato `.ai/`** (złoty wzorzec) — `runs/<slug>/` z `PLAN.md` (status table `Phase|Step|Title|Status|
Commit`, niezmienne step id po commicie) + `HANDOFF.md` + `NOTIFY.md`; `om-spec-writing` z **Open-Questions
  HARD STOP** w body; AGENTS.md Task Router. **`.ai/` jest trackowany** — artefakty to realna dokumentacja
  pracy. **Connector (najsilniejszy z trzech):** Task Router + jawna, _obowiązkowa_ choreografia
  (`om-spec-writing` → `om-pre-implement-spec` → `om-implement-spec` → `om-code-review`) + wieloetapowy handoff
  przez artefakt (`specs/` → report → `runs/<slug>.md` plan → linia `Tracking plan:` w PR → `om-auto-continue-pr`
  wznawia) + jawna delegacja („Follow X skill workflow”). Odciąć dla solo: 3-folderowy split, `specs/README.md`
  master index (magnes na konflikty), 14-sekcyjny template, tiers/compliance, _obowiązkowość_ choreografii.
- **Matt Pocock** — _docs/glossary/setup pomijamy (Q1)_, ALE jego setup to **kluczowa referencja dla 4.6/4.7**.
  Skille **bimodalne**: chude triggery (`zoom-out` 7 linii, `handoff` 15) i tłuste procedury (`diagnose` 117,
  `tdd` 109, `triage` 103) z offloadem detali do `references/` (`LOGIC.md`, `tests.md`, `ADR-FORMAT.md`).
  **Connector (najluźniejszy):** hub-prerequisite (`setup-matt-pocock-skills` wymagany przez ~6 skilli) +
  _opcjonalne_ krawędzie handoff w body („run `/grill-with-docs`”, „hand off to `/improve-codebase-architecture`”),
  brak jawnego routera „next”. README: skille „small, easy to adapt, **composable**”.
- **spec-kit / OpenSpec / BMAD** — ukradzione pomysły: _constitution_ (lekko / pomijamy), _delta/no-merge_
  (każdy run terminalny — nic nie mergeuje z powrotem), _story sharding_ (samodzielne jednostki kontekstu).
  OpenSpec ubodł przez kanoniczny `specs/` merge (wolny + konflikty branchy) → fix: **nigdy nie mergeuj**.
- **claude-kit** — `session-handoff` (czysty, pisze `.agent/handoffs/<YYYYMMDD-HHMM>.md`, template Goal/State/
  Open-Q/Next/Pointers/Gotchas) i `git-workflow` (czyta CLAUDE.local.md `## Git conventions`, guardraile,
  explicit-only). Oba dobre; handoff portujemy + alignujemy do `.ai/`, git zostaje.
- **Community** — HANDOFF pattern; context-engineering (Anthropic: kontekst = skończony zasób, ładuj
  just-in-time, per-task foldery); PR-contract (Addy Osmani: intent→proof→risk→focus); test quality
  (behavior-vs-implementation, mutation-test heuristic); blast-radius / change-impact.

---

## 4. Kluczowe decyzje architektoniczne

### 4.1 Strategia: **build od zera** (nie fork, nie wrap)

Fork ✗ (dziedziczy 20+ skills + multi-IDE command duplication + upstream do rebase; zaśmieca kurowany
marketplace). Wrap ✗ (nadal wymaga agent-skills wszędzie; i tak musi przekształcić output do kształtu
run-folder; dwa skille na jedną intencję; nie naprawi STOP gate'a). **Build ✓** (persistence w body, podróżuje
z pluginem, jeden kontrakt `.ai/` end-to-end; klonujesz `example-skill`; prozę OM/agent-skills przepisujesz).

### 4.2 Struktura na dysku: `.ai/` — **TRACKOWANY**, jeden folder na task, bez współdzielonego index

Zasady: (1) jeden task = jeden samodzielny folder; (2) **brak centralnego index file** — `find`/`ls` po
nazwach folderów + frontmatter per-plik (krytyczne przy trackowaniu: index = magnes na merge-konflikty);
(3) id kluczowane po branchu/worktree; (4) **trackowane & trwałe** — commitowane razem z kodem; sync przez
commit SHA w tabeli _oraz_ same artefakty w historii (jak OM).

```
.ai/
├── runs/
│   └── <YYYYMMDD>-<ticket-or-slug>/      # jedyna jednostka pracy
│       ├── SPEC.md                       # co + dlaczego + boundaries + Open-Questions STOP   (dw-spec)
│       ├── PLAN.md                       # status table (Phase|Step|Title|Status|Commit)      (dw-plan/dw-build)
│       ├── NOTES.md                      # append-only: decyzje, blokery, env quirks
│       └── verify.md                     # uruchamialne SQL/console/curl/rspec + wyniki        (dw-explain/dw-verify)
├── verify/
│   └── <branch-slug>/                    # artefakty klastra dw-quality, kluczowane po branchu
│       ├── review.md                     # (dw-review)
│       ├── conform.md                    # (dw-conform)
│       ├── explain.md                    # (dw-explain) — change explanation + scenariusze
│       ├── verify-run.md                 # (dw-verify)  — wyniki uruchomienia
│       └── risk.md                       # (dw-risk)    — blast radius / poza-kod / follow-upy
├── handoffs/
│   └── <YYYYMMDD-HHMM>.md                 # (dw-handoff, port z claude-kit)
└── archive/
    └── <YYYYMMDD>-<slug>/                 # zakończone runs przeniesione tu przy otwarciu PR
```

- **Nazewnictwo runu:** `<YYYYMMDD>-<ticket-slug>` (np. `20260616-ABC-123-password-reset`). Data sortuje,
  ticket/slug greppable + unikalny per-worktree.
- **Lifecycle:** `created` (wszystko `todo`) → `in progress` (wiersze → `done` + SHA) → `PR opened`
  (`mv runs/<id> archive/<id>` — **archive, nie delete**; `verify.md`/`NOTES.md` przeżywają sesję review).
- **Sync do kodu = kolumna Commit.** `dw-resume` znajduje pierwszy wiersz `Status ≠ done` = punkt wznowienia.
  Deterministycznie. Zacommitowane step id niezmienne.

### 4.3 Persistence w body (kluczowy fix)

Każdy `SKILL.md` _sam_ narzuca ścieżki `.ai/...`. Bez warstwy `.claude/commands/`. Plany trwałe, lądują
automatycznie, podróżują z instalacją pluginu — wprost zabija problem #1.

### 4.4 Multi-thread / worktree (przy trackowanym `.ai/`)

Per-task foldery z unikalnymi slugami → merge dwóch branchy nie konfliktuje (różne foldery). `dw-resume`
dopasowuje run po aktualnym branchu (`branch` we frontmatter), auto-wybierając właściwy task. Brak indexu =
brak powierzchni konfliktu — to strukturalna własność, której OpenSpec nie ma (jego kanoniczny `specs/`
merge-back to bottleneck). **Uwaga zespołowa:** trackowanie `.ai/` w repo zespołowym (ahplus-rails) wrzuca
artefakty planów do historii/PR-ów (model OM) — patrz Decyzja D2.

### 4.5 Technology-agnostic — przemyślane do końca (odpowiedź: tak, ale wzmacniamy)

Twoja intuicja jest słuszna i _ostrzy_ poprzednie sformułowanie. „Stack profiles w skillu” z v2 nadal
przemycało wiedzę o Rails DO skilla (tabela komend per-stack rosłaby z każdym stackiem → skill „wie” o
konkretnych technologiach). **Prawdziwa agnostyczność: skill = czysta procedura; fakty o stacku pochodzą z
PROJEKTU, nie ze skilla.** To ten sam wzorzec, który już masz w claude-kit `git-workflow` (czyta
`## Git conventions`, fallback do defaults) — przenosimy go na komendy build/verify.

**Skąd skill bierze komendy (kolejność źródeł):**

1. **Zadeklarowany blok w projekcie** — `## Commands` / `## Project specifics` w CLAUDE.md/CLAUDE.local.md/
   AGENTS.md (test / lint / typecheck / run / db-console / server-url / run-snippet). Twój bootstrap już tworzy
   Test/Lint/Typecheck — reuse, zero nowego setupu.
2. **Manifesty / skrypty** — `package.json` scripts, `Gemfile` + `bin/`, `Makefile`, `Procfile`,
   `composer.json`, `pyproject.toml`…
3. **Sam kod** — anti-hallucination: każda komenda osadzona w czymś, co istnieje w TYM repo (route w routerze,
   kolumna w schemacie/migracjach, plik wzorca otwarty przez Read).

**Detekcja stacku** = obecność manifestu (Gemfile→Ruby, package.json→Node, go.mod→Go…), nie hardcode w skillu.
**Scenariusze pozostają typowane** (`db`/`http`/`cli`/`console`/`test`/`browser`) — to agnostyczna _taksonomia_;
komendę pod dany typ rozwiązuje projekt, nie skill. Rails/Node = przykłady w `references/examples-*.md`,
oznaczone „przykład”, nie logika.

**Czy przemyślane? edge case'y:**

- _Projekt bez zadeklarowanych komend_ → skill auto-wykrywa z manifestów i **podaje swoje założenie**; pyta gdy
  niejednoznaczne (jak fallback `git-workflow`). Nigdy nie zgaduje po cichu.
- _Polyglot / monorepo_ → typowane scenariusze + per-typ rozwiązanie komendy; każdy scenariusz bierze właściwe
  narzędzie dla swojego pakietu.
- _Czy agnostyczność osłabia anti-hallucination?_ → nie; grounding jest w kodzie, niezależnie od stacku.
- _Czy to wymaga setupu (sprzeczność z Q1)?_ → nie; blok komend opcjonalny, reuse istniejącego „Project
  specifics”. Brak = auto-detekcja.
- _Gdzie żyją przykłady Rails/`:2310`/`rspec`?_ → tylko w `references/`, ilustracyjnie. Skill ich nie potrzebuje
  do działania na innym stacku.

`dw-verify` generalizuje wprost: „odpal scenariusze (typowane) komendami projektu + złap evidence”, niezależnie
od tego czy to Ruby, Node czy cokolwiek.

### 4.6 Connector / kompozycja między skillami (D3 — rozstrzygnięte)

**Decyzja: skille zostają OSOBNE, łączy je trzy-warstwowy connector — bez sztywnych, wymuszonych łańcuchów.**
Twoja intuicja („rozwiązują trochę inne problemy… warto osobno LUB zadbać o łącznik”) trafia w sedno. Research
trzech setów pokazał dokładnie te same trzy mechanizmy łączenia, w różnych proporcjach:

| Mechanizm                          | agent-skills                           | Open-Mercato                                                      | Matt Pocock                             |
| ---------------------------------- | -------------------------------------- | ----------------------------------------------------------------- | --------------------------------------- |
| **(1) Artefakt (A pisze→B czyta)** | spec → tasks → kod (bez ścieżek)       | **silny:** `specs/`→`runs/<slug>.md`→`Tracking plan:` w PR→resume | brak (skille standalone)                |
| **(2) „Next:”/delegacja w body**   | „Following `skill-x`” (rekomendacja)   | „Follow X skill workflow” (jawna delegacja)                       | „hand off to `/Y`” (opcjonalna krawędź) |
| **(3) Router / sekwencja**         | meta-skill drzewo + Lifecycle Sequence | AGENTS.md Task Router + _obowiązkowa_ choreografia                | hub-prerequisite `setup-*`, brak „next” |
| **Sztywność**                      | luźna (człowiek wybiera)               | sztywna dla nietrywialnych                                        | najluźniejsza                           |

**Dlaczego osobne, nie scalone (`dw-conform` ≠ oś w `dw-review`):**

- **Różne osie i różny invoke.** `dw-review` = wieloosiowa jakość _wewnątrz_ diffa (correctness/readability/
  arch/security/perf). `dw-conform` = zgodność z _zewnętrznymi, wcześniej istniejącymi_ wzorcami repo. Inny
  input (diff vs rodzeństwo z `git log`), inny guard, inna częstość uruchamiania. Scalenie = tłusty skill o
  dwóch sercach (anty-wzorzec wobec 4.7).
- **Kompozycyjność.** Osobne skille składasz w dowolnej kolejności i wołasz selektywnie (sam `dw-conform` po
  ręcznym refaktorze, bez pełnego review). Scalone tracą tę granulację.

**Nasz connector (lekki, 3 warstwy — bierzemy najlepsze z każdego setu, odrzucamy obowiązkowość OM):**

1. **Wspólny artefakt = podstawowy łącznik.** Wszystkie `dw-quality` piszą do `.ai/verify/<branch>/`. Każdy
   skill _czyta sąsiednie outputy w tym samym folderze_, jeśli istnieją (`dw-verify` czyta scenariusze z
   `explain.md`; `dw-risk` czyta `review.md`/`conform.md` jako wejście do blast-radius). To wzorzec OM
   (`specs/`→`runs/`→PR), ograniczony do solo: brak indexu, klucz = branch. **Najsilniejszy, bo deterministyczny
   i przeżywa `/clear`.**
2. **„Next:” pointer + opcjonalna delegacja w body.** Każdy `dw-quality` kończy linią „**Next:** rozważ
   `dw-<kolejny>`” (jak agent-skills „Following X” / Pocock „hand off to /Y”). `dw-review` _może_ zawołać
   `dw-conform` jako oś conformance — **delegacja opcjonalna, nie zależność** (spójne z 5.4 self-contained).
3. **Cienki router = README/katalog kolekcji.** Jeden blok „pipeline jakości” w README (i/lub w
   `dw-planning`/`dw-quality` `plugin.json`/SKILL trigger-prozie) listuje rekomendowaną sekwencję
   `implement → dw-review → dw-conform → dw-prune → dw-explain → dw-verify → dw-risk` — **rekomendacja, nie
   bramka** (model agent-skills Lifecycle Sequence, nie obowiązkowość OM).

**Czego NIE robimy:** obowiązkowej choreografii OM (za sztywna dla solo, multi-thread), ani hub-prerequisite
Pococka (`dw-*` muszą działać bez „setup” skilla — patrz 5.4). Connector jest **opcjonalny i artefaktowy**:
jeśli sąsiedni plik istnieje, skill go użyje; jeśli nie — działa sam.

### 4.7 „Thin harness, fat skills” — uzgodnione z chudymi skillami Pococka

Pytanie z tła (Twoje wiki `thin-harness-fat-skills.md` argumentuje za „tłustymi” skillami, a Pocock pisze
„chude”). **Research pokazał, że to nie jest sprzeczność — to ta sama zasada, źle odczytana.**

- **Co naprawdę mówi „thin harness, fat skills”** (Twoje wiki, Garry Tan): _harness_ (program odpalający LLM,
  ~200 linii) ma być cienki; **inteligencja/proces idą W GÓRĘ do skilla** (markdown ≈ 90% wartości), egzekucja
  W DÓŁ do deterministycznego tooling. „Fat” odnosi się do **harnessa jako punktu odniesienia**, nie do
  bezwzględnej długości skilla. Skill = „method call”: ta sama procedura, różne parametry → różne zdolności.
- **Co naprawdę robi Pocock:** skille **bimodalne**. Czyste triggery bez procedury są chude (`zoom-out` 7
  linii) — bo nie ma czego kodyfikować. Skille z realnym wieloetapowym procesem są tłuste (`diagnose` 117,
  `tdd` 109) i **offloadują detale do `references/`** (`LOGIC.md`, `tests.md`, `ADR-FORMAT.md`), żeby SKILL.md
  został proceduralny-nie-encyklopedyczny. To dokładnie „fat skill, thin harness”: harness (`npx skills add`)
  jest cienki, procedura żyje w skillu.

**Reguła autorska dla `dw-*` (rozstrzyga, jak gruby ma być każdy skill):**

- **Waga skilla = złożoność jego procedury, nie sztywny limit linii.** `dw-resume` (read-only, jeden algorytm:
  glob → match branch → pierwszy nie-done) = chudy. `dw-explain`/`dw-build`/`dw-verify` (wieloetapowe, z
  guardami) = tłuste, ale **detale (szablony, taksonomia scenariuszy, przykłady stacków) → `references/`**, nie
  do body. Body trzyma proces + guardy; `references/` trzyma encyklopedię.
- **To spina się z 4.5 (agnostyczność) i Resolver pattern z Twojego wiki:** body = procedura (latent judgment),
  `references/` = ładowane on-demand fakty (przykłady Rails/Node), komendy = czytane z projektu. Każdy upgrade
  modelu automatycznie ulepsza skill (proces w markdown), warstwa deterministyczna (komendy projektu) zostaje
  niezawodna. **Trzy poziomy chudości:** trigger-only (np. ewentualny `dw-context`), proceduralny-z-referencjami
  (większość `dw-quality`), proceduralny-standalone (`dw-resume`).
- **Anty-wzorzec:** wpychać przykłady stacków, długie szablony i taksonomie do body SKILL.md (puchnie, gubi
  uwagę modelu — dokładnie problem `CLAUDE.md` na 20k linii z wiki Resolver). Zamiast tego: `references/`.

---

## 5. Katalog skills (kompletne rozwiązanie, 3 kolekcje)

Wszystkie zgodne z konwencją repo: `skills/<name>/SKILL.md` (kebab-case `name`, `description` z trigger
phrases, opcjonalnie `disable-model-invocation: true`) + `plugins/<collection>/` (symlinki + `plugin.json`) +
wiersze w `marketplace.json` (wersja zsynchronizowana) + README, walidowane `pnpm lint && pnpm format &&
pnpm validate:manifests`. **Pakowanie: jeden plugin per kolekcja** (`dw-planning`, `dw-quality`, `dw-misc`) —
kanoniczny skill nadal jeden-na-skill w `skills/`, plugin grupuje symlinkami.

### 5.1 Kolekcja `dw-planning` (5 skills)

| Skill                  | Czyta                                                           | Pisze                                                | Body narzuca                                                                                                       |
| ---------------------- | --------------------------------------------------------------- | ---------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------ |
| `dw-spec`              | request; wzorce repo; `.ai/runs/` (kolizja id); CLAUDE.local.md | `.ai/runs/<id>/SPEC.md`                              | pytania → szkielet + **Open-Questions HARD STOP** → wypełnij → potwierdź. Ścieżka w body.                          |
| `dw-plan`              | `SPEC.md` aktywnego runu; kod (read-only)                       | `.ai/runs/<id>/PLAN.md` status table                 | vertical slices, ≤5 plików/krok, każdy krok ma acceptance + verify, niezmienne id, prezentacja do akceptacji       |
| `dw-build`             | `PLAN.md` (pierwszy nie-done); SPEC; repo; `## Git conventions` | kod + testy; flip wiersza `done`+SHA; dopisuje NOTES | RED→GREEN→regression→commit→mark-done; jedna zmiana/commit; stop-and-ask przy nieodwracalnych. `auto` = cały plan. |
| `dw-resume`            | globuje `.ai/runs/*/PLAN.md` + frontmatter; dopasowuje branch   | nic (read-only)                                      | raport Goal / done / pierwszy nie-done / blokery. **Branch-matched, bez indexu.**                                  |
| `dw-sync` _(explicit)_ | `PLAN.md` + git diff/log; kod                                   | dopisuje/flipuje wiersze + changelog w NOTES         | re-align planu do kodu po ręcznych edycjach/drifcie; nigdy nie renumeruje zacommitowanych kroków (krok 2)          |

### 5.2 Kolekcja `dw-quality` (6 skills)

Wspólne: akceptują **3 kształty inputu** (working diff vs merge-base · branch/`--base` · PR przez `gh pr diff`);
piszą do `.ai/verify/<branch-slug>/`; **invariant anty-halucynacyjny — żadnej linii bez zweryfikowanego
referenta** (route w routerze, kolumna w schemacie/migracjach, plik wzorca przez Read); **komendy czytane z
projektu, nie zaszyte w skillu** (4.5).

| Skill        | Krok         | Invoke            | Output (`.ai/verify/<branch>/`)                                                                                                                      | Główny guard                                                                                                                     |
| ------------ | ------------ | ----------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- |
| `dw-review`  | 4            | model+explicit    | `review.md` — multi-axis (correctness/readability/architektura/security/perf), findings `file:line` + severity                                       | self-contained (nie zależy od zewn. reviewerów); cytuje realne linie; nie wymyśla problemów spoza diffa                          |
| `dw-conform` | 5            | model+explicit    | `conform.md` — drift vs **istniejące wcześniej** rodzeństwo (potwierdzone `git log`)                                                                 | wzorzec = realny, wcześniej istniejący plik; nigdy nie akceptuj świeżego błędu z tego PR-a; brak rodzeństwa → powiedz            |
| `dw-prune`   | 5.1          | **explicit-only** | tabela keep/merge/delete → edycje za zgodą                                                                                                           | **regression-safety gate**: delete tylko gdy nazwany _zachowany_ test łapie zachowanie; coverage prod nie spada                  |
| `dw-explain` | 6 (keystone) | model+explicit    | `explain.md`: A intent · B jak-działa · **C uruchamialne scenariusze (typowane db/http/cli/console/test, P0/P1/P2, expected)** · D edge'y · E open-Q | każda komenda osadzona w realnych referentach; nieosadzalna → E, nigdy fabrykowana                                               |
| `dw-verify`  | 7            | model+explicit    | `verify-run.md`: per-scenariusz komenda/actual/expected/PASS-FAIL-INCONCLUSIVE + evidence                                                            | read-only auto-run; **mutujące wymagają potwierdzenia** (txn rollback/sandbox); nigdy PASS bez outputu; INCONCLUSIVE first-class |
| `dw-risk`    | 8            | model+explicit    | `risk.md`: **(a)** blast radius + tiers · **(b)** poza-kod (migracje/env/flagi/infra/secrets) · **(c)** follow-upy + rollback                        | migration-safety / one-way-door z realnego kodu; niesprawdzona sekcja = „NOT VERIFIED”, nie cichy pass                           |

Kompozycja (rekomendacja, nie bramka — connector w 4.6): `implement → dw-review → dw-conform (fix drift, re-run)
→ dw-prune (Ty) → dw-explain → dw-verify → dw-risk → ship`. **Łącznik = wspólny artefakt** `.ai/verify/<branch>/`
(każdy skill czyta sąsiednie outputy jeśli istnieją) **+ „Next:” pointer w body**. Każdy persistuje per-branch →
świeża sesja podejmuje bez re-derywacji. (`dw-review` _może_ opcjonalnie wołać `dw-conform` jako oś conformance —
delegacja opcjonalna, nie zależność.)

### 5.3 Kolekcja `dw-misc` (cross-cutting / bucket rozwojowy; seed: 1 skill)

| Skill        | Źródło                              | Output                            | Uwaga                                                                                              |
| ------------ | ----------------------------------- | --------------------------------- | -------------------------------------------------------------------------------------------------- |
| `dw-handoff` | port `session-handoff` z claude-kit | `.ai/handoffs/<YYYYMMDD-HHMM>.md` | align do `.ai/` + back-pointer do aktywnego runu; template Goal/State/Open-Q/Next/Pointers/Gotchas |

`dw-misc` (zmiana nazwy z `dw-utils`, D1 — „misc lepsze”) = **bucket rozwojowy** na cross-cutting helpers, które
nie pasują do `dw-planning`/`dw-quality`. Na start: `dw-handoff`. Kandydaci rozwojowi: `dw-git` (D1 — jeśli
kiedyś zechcesz wciągnąć git do workflow zamiast trzymać tylko w claude-kit), `dw-context` (ładowanie kontekstu
repo). Bucket świadomie luźny — rośnie ad-hoc, gdy realnie czegoś zabraknie.

### 5.4 Self-contained by design (punkt 3)

Katalog **nie zależy** od zewnętrznych skills — bo te mogą zniknąć / mogę ich nie używać. Zewnętrzne narzędzia
(`code-review`, `qa-analyst`, `ci-diagnosis`, `understand-diff`, `verify`, `agent-skills:review`) to
**opcjonalna kompozycja, nie zależność**: jeśli są, `dw-*` może je zawołać; jeśli nie ma — `dw-*` działa sam.
Dlatego `dw-review` jest pełnoprawnym skillem w katalogu, nie delegacją.

---

## 6. Szablony (artefakty)

- **`SPEC.md`** — frontmatter `run/ticket/status/created/branch`; TLDR · **Open Questions (HARD STOP)** · Scope
  (in/out) · Approach (wzorce do naśladowania) · Boundaries (Always/Ask-first/Never) · Success criteria.
- **`PLAN.md`** — frontmatter `run/spec/status`; status table (`Phase|Step|Title|Status|Commit`, Status ∈
  todo/doing/done/blocked, pierwszy nie-done = resume, id niezmienne po commicie) · Architecture decisions ·
  Risks · Verification checkpoints.
- **`explain.md`/`verify.md`** — What changed (prosto) · Prove it works (typowane scenariusze z **expected**) ·
  Edge cases · Side effects / blast radius.
- **`NOTES.md`** — append-only, timestamped.
- **`handoffs/<…>.md`** — Goal / Current state / Open questions / Next steps / Suggested skills / Pointers /
  Gotchas (z claude-kit, sprawdzony template).

> Dołącz jako `references/templates/*.md` w odpowiednich skills → agent kopiuje dokładne kształty (taniej,
> spójniej; spójne z 4.7 — body trzyma proces, `references/` encyklopedię); referencje podróżują przez symlink
> pluginu.

---

## 7. Kolejność buildu (sekwencja — nie implementacja)

1. **`dw-spec` + szablony SPEC/PLAN/NOTES/verify** — fundament.
2. **`dw-resume`** — najmniejszy, najwyższa dźwignia; read-only; zabija amnezję po `/clear`.
3. **`dw-handoff`** (port z claude-kit, trywialny) — szybka wygrana, dopina resume/handoff.
4. **`dw-plan` + `dw-build`** — domknięcie pętli planowania (czyta `## Git conventions`).
5. **`dw-explain` → `dw-verify` → `dw-risk`** — klaster najwięcej unikalnej wartości (kroki 6/7/8).
6. **`dw-review` + `dw-conform` + `dw-prune`** — reszta `dw-quality`.
7. **`dw-sync`** — drift fixer.

Wydanie 1–3 naprawia persistence + resume + handoff; 4 domyka pętlę; 5 dostarcza zróżnicowaną wartość.
Waliduj na **dwóch różnych stackach** — `ahplus-rails` (Ruby) i repo JS/TS (AirHelp web) — po każdym klastrze,
żeby udowodnić agnostyczność (ten sam skill, komendy z projektu, zero zmian w skillu).

---

## 8. Decyzje — rozstrzygnięte i pozostałe

**Rozstrzygnięte (wcześniejsze review):**

- Prefix = `dw-`. Folder = `.ai/`, **trackowany**. Pakowanie = 3 kolekcje.
- Lifecycle = **archive, nie delete** przy PR. Glossary/docs-setup = **pominięte** (skupiamy się na workflow).
- `git-workflow` zostaje w claude-kit; `session-handoff` → port jako `dw-handoff`.
- Katalog **self-contained**; `dw-review` w katalogu mimo istnienia innych reviewerów.

**Rozstrzygnięte w v4 (Twoje decyzje D1–D5):**

- **D1 — bucket `dw-misc` (zmiana z `dw-utils`).** „misc lepsze” → kolekcja nazwana **`dw-misc`**, traktowana
  jako **bucket rozwojowy** (rośnie ad-hoc). `dw-git` zostaje na razie w claude-kit (`dw-build` czyta te same
  `## Git conventions`); `dw-git` w `dw-misc` = przyszły kandydat, nie teraz. (sekcja 5.3)
- **D2 — `.ai/` + `CLAUDE.local.md` migrują, ale dopiero przy wdrożeniu.** Tak — przechodzimy na `.ai/`
  (trackowany), `CLAUDE.local.md` też się dostosuje. **Decyzja: nie ruszamy teraz** — zmiana wchodzi „do czasów
  wdrożenia” (gdy realnie zaczniemy build). Research tego nie implementuje.
- **D3 — connector zamiast scalenia (rozpisane w 4.6).** `dw-review` i `dw-conform` **osobne** (różne osie,
  różny input/guard), łączy je 3-warstwowy connector (artefakt `.ai/verify/<branch>/` + „Next:” pointer +
  cienki router README). Zweryfikowane jak robią to agent-skills / OM / Pocock — bierzemy artefakt+pointer,
  odrzucamy obowiązkowość OM i hub-prerequisite Pococka.
- **D4 — aktualizacja `CLAUDE.local.md`: TAK (przy buildzie).** `.agent/` → `.ai/`; usunąć „gitignored / never
  commit” i „delete spec on PR” → „archive on PR”; handoffs → `.ai/handoffs/`. **Hooki blokujące komendy
  (block-dangerous-git / block-non-pnpm / lint-on-edit) zostają bez zmian** — to osobna warstwa, OK.
- **D5 — blok komend: czytaj zadeklarowany, inaczej auto-detekcja (bez wymuszonego setupu).** Rekomendacja
  (potwierdzona, choć nie byłeś pewien): skill czyta `## Commands`/`## Project specifics` jeśli istnieje (reuse
  bootstrapu), w przeciwnym razie auto-wykrywa z manifestów i **podaje założenie**. Zero nowego setupu, zero
  hardcode w skillu (spójne z 4.5). To wzorzec fallbacku `git-workflow`.

**Brak otwartych blokerów.** Wszystkie decyzje projektowe zamknięte; pozostała część to implementacja (build),
nie research — startuje na Twój sygnał, wg kolejności z sekcji 7.

---

## 9. Źródła i referencje

**Mamy sporo realnej referencji — kluczowe są 3 projekty, które oznaczyłeś w `research.md` (lokalne klony,
przeczytane dogłębnie, nie tylko z GitHuba):**

1. **Open-Mercato** `/Users/dominik.wozniak/workspace/private/open-mercato` — _złoty wzorzec_ struktury `.ai/`
   (trackowany) + `AGENTS.md` Task Router + choreografia skilli (`om-spec-writing`/`om-pre-implement-spec`/
   `om-implement-spec`/`om-code-review`) + wieloetapowy handoff przez artefakt. Główne źródło dla 4.2, 4.4, 4.6.
2. **Addy Osmani agent-skills** `/Users/dominik.wozniak/workspace/private/agent-skills` — dyscyplina (vertical
   slicing, RED→GREEN→commit) + meta-skill `using-agent-skills` + Lifecycle Sequence (luźny connector). Źródło
   problemu #1 (persistence w `.claude/commands/`) i wzorca „Next:” pointer (4.6).
3. **Matt Pocock skills** `/Users/dominik.wozniak/workspace/private/skills` — bimodalne skille (chude triggery vs
   tłuste procedury + `references/`) + luźny connector (hub-prerequisite, krawędzie handoff). Główne źródło dla
   4.7 (thin/fat) i 4.6 (najluźniejszy connector).

**Pozostałe lokalne:** claude-kit `/Users/dominik.wozniak/workspace/private/byarcadia-packages/dominikwozniak-claude-kit`
(`session-handoff` → `dw-handoff`; `git-workflow` zostaje, wzorzec czytania konwencji z projektu); `ahplus-rails`
(Rails 8, RSpec+FactoryBot, `standard`, Postgres, dry-\*, GitHub Actions — stack walidacyjny #1); to repo —
`example-skill` + `AGENTS.md` + `CLAUDE.local.md`. **Twoje wiki:**
`dominikwozniak-wiki/wiki/concepts/thin-harness-fat-skills.md` (+ `skill-file.md`, `harness.md`, `resolver.md`,
`portable-context.md`) — podstawa filozofii autorskiej z 4.7.

**Zewnętrzne:** GitHub spec-kit (constitution); Fission-AI OpenSpec (delta merge); BMAD-METHOD (story sharding);
Anthropic „Effective context engineering for AI agents”; Addy Osmani (PR contract); community HANDOFF pattern;
blast-radius / change-impact.
