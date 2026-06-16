# Examples by stack

> **These are illustrative, not logic.** `dw-explain` never hardcodes a stack. The
> commands below are shown only so you recognise the **referent → scenario →
> expected** pattern. In a real run, the stack is detected and every command is
> resolved from the project in front of you (declared block → manifest → code),
> never copied from here. Rails and Node appear because they're common — the
> pattern is identical for Go, Python, Elixir, or anything else.

## Example 1 — Rails: add a `password reset` endpoint

**The change (referents from the diff):**

- migration `db/migrate/20260616_add_reset_digest_to_users.rb` adds
  `users.reset_digest` (string) and `users.reset_sent_at` (datetime).
- `config/routes.rb` adds `post "password_resets" => "password_resets#create"`.
- `app/controllers/password_resets_controller.rb#create` generates a token,
  stores the digest, emails the user.

**Section C, grounded in those referents:**

| #   | Type    | Pri | Command                                                                     | Expected                                         | Referent                             |
| --- | ------- | --- | --------------------------------------------------------------------------- | ------------------------------------------------ | ------------------------------------ |
| 1   | http    | P0  | `curl -i -X POST localhost:3000/password_resets -d 'email=a@b.com'`         | `302` redirect to root, flash "email sent"       | route in `config/routes.rb`          |
| 2   | db      | P0  | `bin/rails runner 'p User.find_by(email: "a@b.com").reset_digest.present?'` | `true` — digest stored                           | `reset_digest` col in the migration  |
| 3   | console | P1  | `bin/rails console` → `User.find_by(email: "a@b.com").reset_sent_at`        | a recent timestamp (not `nil`)                   | `reset_sent_at` col in the migration |
| 4   | http    | P1  | `curl -i -X POST localhost:3000/password_resets -d 'email=nope@x.com'`      | `302`, no error leak that the account is unknown | controller `create` branch           |
| 5   | test    | P2  | `bin/rails test test/controllers/password_resets_controller_test.rb`        | the named case goes green                        | test file (write if absent)          |

- The run command (`bin/rails`, `localhost:3000`) and test runner are read from the
  project, not assumed.
- An unknown-email path (#4) is a P1 **edge**; a leak there would be a finding.

## Example 2 — Node/Express + Prisma: add `GET /invoices/:id/pdf`

**The change (referents from the diff):**

- `prisma/schema.prisma` adds `Invoice.pdfUrl String?`.
- `src/routes/invoices.ts` adds `router.get("/:id/pdf", requireAuth, getInvoicePdf)`.
- `src/controllers/invoices.ts#getInvoicePdf` returns `302` to `pdfUrl`, or `404`
  if absent.

**Section C, grounded in those referents:**

| #   | Type | Pri | Command                                                                              | Expected                                  | Referent                          |
| --- | ---- | --- | ------------------------------------------------------------------------------------ | ----------------------------------------- | --------------------------------- |
| 1   | http | P0  | `curl -i localhost:8080/invoices/inv_1/pdf -H "Authorization: Bearer $TOK"`          | `302` to the `pdfUrl`                     | route in `src/routes/invoices.ts` |
| 2   | http | P0  | `curl -i localhost:8080/invoices/inv_1/pdf` (no token)                               | `401` — `requireAuth` blocks it           | `requireAuth` on the route        |
| 3   | db   | P1  | `npx prisma studio` / a `SELECT "pdfUrl" FROM "Invoice" WHERE id='inv_1'`            | column exists; value is the URL or `NULL` | `pdfUrl` field in `schema.prisma` |
| 4   | http | P1  | `curl -i localhost:8080/invoices/inv_2/pdf -H "Authorization: Bearer $TOK"` (no pdf) | `404`                                     | `getInvoicePdf` absent-branch     |
| 5   | test | P2  | `[project test runner] src/controllers/invoices.test.ts`                             | the `getInvoicePdf` cases pass            | test file (write if absent)       |

- The test runner is left as `[project test runner]` on purpose: read it from
  `package.json` (`vitest`? `jest`? `node --test`?) — do not guess.
- The auth-missing case (#2) is P0, not P1: an unprotected money endpoint is the
  thing most worth proving.

## What both examples have in common

- Every row points at a **referent that exists in the diff** (a route, a column, a
  branch in a controller). Nothing is invented.
- Run/db/test commands are the **project's** — the examples flag where they're read
  rather than assumed.
- Expected results are **observable** (`302`, `401`, `true`, "column exists"), never
  "should work".
- Anything that couldn't be grounded — say, the project's exact test command if no
  manifest declared it — would go to section E, not be faked here.
