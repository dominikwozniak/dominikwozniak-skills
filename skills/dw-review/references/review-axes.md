# Review axes — the five lenses

The vocabulary behind `review.md`'s findings: what each axis looks for, and where its bugs hide. The
`dw-review` body holds the procedure; this file holds the checklist. Read it while you pass through
the diff. Every item you raise still has to point at a real `file:line` — these are prompts for
_where to look_, not a licence to invent.

## Correctness — does it do the right thing?

The axis that matters most: code that's plain but correct ships; code that's elegant but wrong does
not. Look for:

- **Logic** — wrong operator or condition, inverted boolean, off-by-one, the wrong branch taken.
- **Edge cases** — empty input, a single element, the maximum, zero, negative, duplicates, Unicode;
  the boundary the loop or slice is built around.
- **Error handling** — an unchecked error / ignored return, a swallowed exception, a rejected promise
  that's never awaited, a `catch` that hides the failure.
- **Null / absence** — a value that can be `null` / `nil` / `None` / `undefined` used as if it can't.
- **Concurrency** — a shared value mutated without a lock, a race between read and write, an `await`
  in a loop that was meant to run in parallel (or vice-versa).
- **Resources** — a file / connection / handle opened and not closed on every path, including the
  error path.
- **Contract** — does the change keep the promises its callers rely on (return shape, status codes,
  thrown errors)? Trace a caller with `Read` when the contract shifts.

## Readability — will the next person understand it?

Code is read far more often than it's written. Look for:

- **Naming** — names that mislead or say nothing (`data`, `tmp`, `d`); a boolean that reads
  backwards; a function named for _how_ it works rather than _what_ it does.
- **Complexity** — a function doing five things, deep nesting, a condition no one can hold in their
  head; an early return would often flatten it.
- **Dead / duplicated code** — a copy-paste that should be one helper, a branch that can't be
  reached, a left-behind `console.log` / `binding.pry`.
- **Comments** — a comment that contradicts the code (worse than none), a missing _why_ on a
  non-obvious choice, a magic number with no name.

## Architecture — does it fit the structure?

Whether the change works _with_ the codebase or _against_ it. Look for:

- **Layering** — business logic leaking into a controller / view / model that shouldn't hold it; a
  dependency pointing the wrong way (a low layer importing a high one).
- **Coupling** — a new hard dependency on a concrete thing where the project uses an interface;
  reaching across a module boundary instead of through its public API.
- **Abstraction fit** — a new abstraction that earns its keep, or one layer of indirection too many;
  re-implementing something the project already has a helper for.
- **Consistency** — the change follows the pattern its neighbours already use, rather than
  introducing a second way to do the same thing.

## Security — can it be made to hurt?

Assume the input is hostile and the caller is not who you expect. Look for:

- **Input validation** — untrusted input used unvalidated in a query, a path, a command, a redirect,
  or HTML output.
- **Injection** — SQL / NoSQL built by string concatenation; a shell command built from input;
  `eval` / dynamic templating on untrusted data; reflected or stored XSS.
- **AuthN / AuthZ** — a route / action / record reachable without the right check; an authorization
  check that's missing, runs after the side-effect, or trusts a client-supplied id.
- **Secrets** — a key / token / password / connection string committed in the diff; a secret written
  to a log line or returned in an error.
- **Data exposure** — over-broad serialization (returning the whole record), sensitive fields in
  logs, a stack trace leaked to the user.
- **Unsafe deserialization / SSRF** — untrusted data deserialized into objects; a server-side fetch
  to a URL the user controls.

## Performance — will it stay fast at real scale?

Measured against the real hot path and real data sizes, not micro-optimisation for its own sake. Look
for:

- **N+1 / queries in loops** — a DB or network call inside a loop that should be one batched call or
  a join.
- **Unbounded work** — loading an entire table / list into memory, growth that scales with all-time
  data instead of a window, a missing `LIMIT` / pagination.
- **Missing indexes** — a new query filtering or ordering on an unindexed column (cross-check the
  schema).
- **Blocking** — synchronous I/O on a request path; a heavy CPU loop on the event loop / main thread.
- **Repeated work** — recomputing inside a loop what could be hoisted out; an obvious cache that
  isn't there on a known-hot path.

## Per-stack smells (illustrative only — never logic)

The axes above are stack-agnostic; how a smell _surfaces_ depends on the project. These are
_examples_ of where to look — the real finding always comes from the diff in front of you.

- _Example (Rails):_ N+1 from `@orders.each { |o| o.user.name }` without `includes(:user)`; mass
  assignment without `params.require/permit`; raw SQL via string interpolation instead of a bound
  parameter.
- _Example (Node/TS):_ a floating promise (no `await`, no `.catch`); `any` smuggling an unchecked
  shape past the type checker on a boundary; `child_process.exec` built from request input.

Do not branch logic on these. They illustrate the referent → finding pattern, nothing more.
