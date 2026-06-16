# Scenario taxonomy

Section C of `explain.md` is built from typed scenarios. The **type** is a fixed,
technology-agnostic vocabulary; the **command** that realises a type is always
resolved from the project (see the SKILL "Read the project's commands" section).
Every scenario must satisfy the anti-hallucination invariant: it names a referent
that exists in the change or the repo, or it moves to section E.

## The grounding rule, restated

A scenario has three parts — type, command, expected — and one precondition: a
**referent**. The referent is the thing in the codebase that makes the scenario
real:

- you read it in the diff, or
- you opened it with `Read`, or
- you resolved its command from a declared block / manifest / the code.

No referent → not a scenario → section E. This is non-negotiable because the
artifact's only value is that the next pass can run it without re-deriving it.

## Types

### `db` — database state and queries

- **Covers:** schema changes, new/changed columns, data a migration backfills,
  query results that should change.
- **Referent:** a column or table in a migration in the diff, or in the schema
  file. If the column isn't there, the scenario is fabricated.
- **Command shape (project-resolved):** a db console / SQL runner — e.g. a
  `psql -c "SELECT [cols] FROM [table] WHERE [...]"`, an ORM console snippet, or
  the project's documented `db-console`.
- **Expected:** the concrete row(s) / value / count returned, or the constraint
  that now rejects a bad write.

### `http` — request/response behaviour

- **Covers:** new or changed endpoints, status codes, payload shapes, auth gates.
- **Referent:** the route in the router / routes file. Confirm the method + path
  exist before writing a request against them.
- **Command shape:** an HTTP client against the project's run command / server URL
  — e.g. `curl -i [METHOD] [server-url]/path -d '[...]'`, or the project's API test
  helper.
- **Expected:** the status code and the part of the body that proves the behaviour
  (a field, an error message, a header).

### `cli` — command-line entrypoints

- **Covers:** scripts, generators, rake/make/npm tasks, binaries the change adds
  or alters.
- **Referent:** the task/script definition (in `package.json` scripts, a
  `Makefile` target, `bin/`, a rake task) present in the repo.
- **Command shape:** the project's invocation of that entrypoint with realistic
  arguments.
- **Expected:** exit code, the output line(s) that prove success, the file/side
  effect produced.

### `console` — interactive REPL / language console

- **Covers:** library functions, service objects, pure logic best exercised by
  calling it directly rather than through HTTP.
- **Referent:** the function/class/method in the diff or read from the file.
- **Command shape:** the project's REPL (`rails console`, `node`, `bin/console`,
  `python -i`, …) with a snippet calling the real symbol.
- **Expected:** the return value, the raised error, the state mutation observed.

### `test` — the project's automated tests

- **Covers:** behaviour already (or newly) covered by the suite; the fastest way
  to re-prove a unit of logic.
- **Referent:** a test file/case in the repo, or one the change adds. Name the
  file. If you propose a test that doesn't exist yet, say so (it's a P1/P2 "write
  this test", not a runnable P0).
- **Command shape:** the project's test runner, scoped to the relevant file/case
  (read the test command from the project — never assume `jest` vs `vitest` vs
  `rspec`).
- **Expected:** the assertion(s) that pass; the named test goes green.

### `browser` — user-facing UI (when relevant)

- **Covers:** rendered output, interactions, visible states for UI changes.
- **Referent:** the component/page/route in the diff.
- **Command shape:** the run command + a URL to open, or the project's e2e/browser
  tooling if it has one.
- **Expected:** what the user sees / can do — the element renders, the action
  succeeds, the state updates.

## Priority rubric

Assign each scenario a priority so `dw-verify` runs the load-bearing ones first.

- **P0 — core path.** If this fails, the change is broken. The primary thing the
  change set out to do. There should be at least one P0; usually only one or two.
- **P1 — important behaviour or main edge.** Strongly expected to work; a real user
  would hit it. Auth gates, the main error path, the obvious boundary.
- **P2 — secondary.** Nice to confirm; rarer edges, cosmetic, defensive.

Prioritise by **blast radius and likelihood**, not by how easy the scenario is to
write. A neighbour `review.md` / `conform.md` flagging an area is a strong signal to
raise that area's priority.

## Expected-output discipline

"Expected" is the difference between a runnable scenario and a vibe. For every row:

- Write the **observable** result, not an intention. Good: "201, body `{ id: ... }`".
  Bad: "should create the record".
- Prefer a result a human (or `dw-verify`) can compare **without judgement** — an
  exact status, a specific value, a named assertion.
- If the exact value is data-dependent, describe the **invariant** ("count
  increases by 1", "row exists with `status = 'sent'`").
- If you can't state an expected result, you don't understand the scenario well
  enough to assert it — demote it to section E.

## How many scenarios

Enough to convince a skeptic, not a compliance checklist. A small change might be
one P0 + one edge. A larger one spans a few types. Cover the core path (P0), the
main edge or auth gate (P1), and note real risks in D. Resist padding C with P2s
that prove nothing — every row should pull its weight, because every row is work
`dw-verify` will spend time running.
