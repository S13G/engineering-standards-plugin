# Backend Engineering

Server-side application code: request handling, business workflows, service boundaries, error handling, background work, and caching. Language-agnostic; examples pick whichever language shows the idea most clearly. For data/schema rules see `data.md`; for threads and distributed coordination see `concurrency.md`; for input/authz see `security.md`.

---

## The shape of a backend request

Keep the layers honest and one-directional:

```
Transport (HTTP/gRPC/queue)
   → Controller/Handler   parse, authenticate, authorize, validate shape
      → Service/Use-case  one business workflow, owns the transaction
         → Domain model   invariants, state transitions, pure logic
         → Repository     persistence, the only layer that knows the DB
```

- **Controllers/handlers are thin.** Parse the request, check auth, validate the *shape* of input, call one service, translate the result to a response. No business logic, no direct DB access.
- **Services own workflows.** Multi-step writes, lifecycle transitions, orchestration of side effects, the transaction boundary. One public entry point. Plain inputs, no hidden global state.
- **Domain models own rules.** Validations, enums, state machines, small domain helpers. A model method name reads like a business fact: `approve!`, `can_refund?`, `mark_settled`.
- **Repositories own persistence.** The only place that knows the storage engine. Everything above receives plain objects and IDs.

The win: each layer is testable alone, and a reader can predict where any given concern lives.

### Thin handler, rich service (language-neutral)

```
// BAD — fat handler: parsing, business rules, persistence, and notification tangled
function createTransfer(req, res) {
  const acct = db.accounts.find(req.params.id)
  acct.balance -= req.body.amount            // rule hidden in a handler
  db.accounts.save(acct)
  db.ledger.insert({ account: acct.id, delta: -req.body.amount })
  email.send(acct.owner, "debited")          // I/O mixed with the write
  res.json({ ok: true })
}

// GOOD — handler delegates; the service owns the workflow and its boundary
function createTransfer(req, res) {
  const result = TransferService.call({
    accountId: req.params.id,
    amountMinor: req.body.amount_minor,
    idempotencyKey: req.header("Idempotency-Key"),
  })
  res.status(result.status).json(result.body)
}
```

---

## Service objects and use-cases

- Name them for what they do: `Noun.Verb` or `VerbNounService` — `Transfer.Execute`, `Invite.Issue`, `Payment.Authorize`. The name is the spec.
- One public method (`call`/`execute`/`handle`). Everything else is private.
- **Return a result, don't raise for expected outcomes.** "Insufficient funds" is a normal business result, not an exception. Reserve exceptions for the genuinely unexpected.

```
// A small result type beats throwing for predictable outcomes
Result.ok(value)                              // success
Result.failure(code: "insufficient_funds",    // machine-readable
               message: "...",                // human-readable
               details: { balance, required })
```

- Keep services free of transport concerns. A service shouldn't know it was called by HTTP vs. a job vs. a CLI. That's how the same workflow gets reused.

---

## Error handling

> Errors are values. Handle them where you have the context to do something meaningful; let the rest travel up.

- **Never catch the broad base exception just to continue.** That masks real bugs. Catch specific, expected failures; re-raise or wrap the rest.
- **Translate at boundaries.** Internal errors become a clean, structured error at the API edge — never a stack trace, never a raw DB message that leaks schema.
- **No silent failures.** `catch (e) {}` and `rescue; nil` are how data quietly corrupts. If you truly intend to ignore, say so in a comment with the reason.
- Distinguish *expected* failure (validation, conflict, not-found) from *unexpected* (bug, dependency down). The first returns a result; the second logs with context and fails loud.

```go
// Go: wrap with context as the error travels up; the top layer decides the response
balance, err := repo.GetBalance(ctx, acctID)
if err != nil {
    return fmt.Errorf("load balance for %s: %w", acctID, err) // %w preserves the chain
}
```

---

## APIs as a product

> "An API is a UI for developers." Consistency and predictability are the whole game.

- **Uniform envelope.** If one endpoint wraps data and errors a certain way, all of them do. Surprise is a defect.
- **Structured errors** with a stable machine-readable `code` and a human `message`:

```json
{ "error": { "code": "insufficient_funds",
             "message": "Your balance is too low to complete this transfer.",
             "details": { "balance_minor": 5000, "required_minor": 10000 } } }
```

- **Hide internals.** DB column names, primary keys, and implementation details stay inside. Expose a deliberate contract, not your table layout.
- **Version from day one** (`/v1/`). Bumping a version is far cheaper than breaking every client at once.
- **Never return unbounded lists.** Default to pagination — cursor-based for large or time-series data (stable under writes), offset only for small admin views. (Query mechanics: `data.md`.)
- **Idempotency keys** on every state-mutating endpoint that can be retried (payments, transfers, sends). Store the key with its response; a repeat key returns the stored response instead of re-executing.

```
key = header("Idempotency-Key")  // required for mutations that move money/state
return Idempotency.run(key) {
    Payment.Create.call(params)   // body runs at most once per key
}
```

### Choosing the API style — a tradeoff, not a fashion

| Style | Fits when | Cost |
|---|---|---|
| **REST/JSON** | Resource-oriented CRUD, broad client reach, cacheable reads | Over/under-fetching; many round-trips for nested data |
| **GraphQL** | Clients need flexible, nested shapes; many consumers, one graph | Server complexity, caching is hard, query-cost/depth limits a must (a malicious deep query is a DoS) |
| **gRPC** | Internal service-to-service, low latency, streaming, strict contracts | Binary, less browser-native, needs tooling |

Pick for the consumer and the traffic, not the trend. Whatever the style: a versioned, backward-compatible contract; consistent envelope; bounded responses. For REST specifically — use HTTP verbs and status codes honestly (`GET` is safe and idempotent and never mutates; `PUT`/`DELETE` idempotent; `POST` creates; `409` for conflict, `422` for validation, `429` for throttle), and support conditional requests (`ETag`/`If-None-Match`) so clients cache.

---

## Rate limiting & abuse control

Every public or authenticated endpoint needs a limit; unauthenticated and auth endpoints need stricter ones. Unlimited endpoints are a free DoS and a brute-force playground (`security.md`).

```
throttle("ip",   limit: 60,  per: 1.minute)  { request.ip }       // coarse safety net
throttle("user", limit: 300, per: 1.minute)  { current_user.id }  // per-principal
throttle("auth", limit: 5,   per: 15.minutes){ request.ip }       // strict: login/reset/OTP
```

- Return **`429 Too Many Requests` with a `Retry-After` header** — never silently drop; tell the client when to come back.
- **Token-bucket / sliding-window**, backed by a shared store (Redis) so the limit holds across all instances — a per-instance counter is meaningless behind a load balancer.
- Layer it: a cheap per-IP net at the edge, a precise per-principal limit in the app, and tighter limits on expensive or sensitive operations (sending money, OTPs, search).
- Shed load gracefully under overload (reject early with 429/503) rather than letting every request degrade for everyone.

---

## Domain modeling in the backend (DDD-lite)

When the business logic is non-trivial, structure code around the **domain**, not the framework (full treatment: `architecture.md`).

- **Ubiquitous language**: the class is `Settlement` because the business says "settlement." Don't invent a parallel vocabulary the domain experts won't recognize.
- **Bounded contexts**: "User" in billing and "User" in support are different models — don't force one god-object across the whole app. Keep contexts separate with explicit translation at the seam.
- **Aggregates = transaction + invariant boundaries**: a cluster that changes together under one rule, mutated only through its root, persisted in one transaction (`data.md`). This is where "what's in one transaction?" gets answered.
- Keep the **domain logic free of framework and I/O** (the functional-core idea, `paradigms.md`) so the rules are testable without a database or web server.

---

## Background jobs

- **Pass IDs, not objects.** Objects serialized into a queue go stale; an ID re-fetches the current truth.
- **Make every job idempotent.** A queue will deliver twice. Guard with a state check at the top: `return if already_settled`.
- **Dedupe** jobs that must not run concurrently for the same resource (a uniqueness constraint on `{job, resource_id}` or a lock).
- **Retry transient failures** with exponential backoff and a cap; **discard permanent ones** (record gone, invalid state) instead of retrying forever.
- **No business decisions hidden in the job.** The job calls a service; the service holds the logic, so it's testable without the queue.

```
class SettlePayoutJob:
    retry_on(NetworkError, backoff="exponential", attempts=5)
    discard_on(RecordNotFound)

    def perform(payout_id):
        payout = Payout.find(payout_id)
        return if payout.settled?          # idempotency guard
        Settlement.Process.call(payout)    # logic lives in the service
```

---

## Side effects and transactions

- **Never do network I/O inside a database transaction** — no HTTP calls, no email, no queue publish. They hold the transaction open across an unreliable boundary and can't be rolled back. Commit first, then fire side effects via an `after_commit` hook or a transactional outbox. (Transaction mechanics: `data.md`.)
- A workflow that writes several records wraps them in one transaction: they succeed together or fail together.
- **The transactional outbox pattern** solves the dual-write problem (you must update the DB *and* publish an event, but a crash between them loses one): in the *same* transaction, write the business row **and** an `outbox` row describing the event; a separate poller reads the outbox and publishes, marking each sent. Now the event is published if and only if the data committed — no lost or phantom events. Consumers still dedupe (at-least-once delivery, `concurrency.md`).

---

## State machines, tokens, and invite/approval flows

These show up everywhere (onboarding, payments, invites, moderation) and are a common source of subtle bugs.

- Model allowed states as an explicit enum, and enforce valid transitions — ideally with a DB check constraint as the backstop, not just app code.
- Keep query scopes aligned to real states. A scope that filters on a state that no longer exists is a silent bug.
- **Token flows**: store only a *hash/digest* of the token in the DB; the plaintext lives only in the email/URL. Always check expiry and a "consumed" flag before honoring a token.
- **Resend** issues a *fresh* token and invalidates the old one — and must not leak whether an unrelated account exists (same response either way; see `security.md`).
- Make "expired" and "already used" distinct, user-safe outcomes, not a generic 500.

---

## Caching (backend view)

- Cache only what is expensive *and* safe to serve slightly stale. **Never cache** balances, auth/permission state, or anything where stale means wrong-and-dangerous.
- Always set an expiry; never cache forever. Pair every cached key with an explicit invalidation when the source changes.
- Guard hot keys against a **cache stampede** (many misses recomputing at once) — use a short lock or a "serve stale while one refreshes" window.
- Cache at the right layer: HTTP (`Cache-Control`/ETag) for responses, app-level for computed values, the DB's own caches for queries. Don't stack redundant layers you can't reason about.

---

## Backend review checklist

- Handler thin, service owns the workflow, repository owns persistence?
- Expected failures returned as results; unexpected ones logged with context and allowed to fail loud?
- Every mutation that can be retried idempotent and, where it moves money/state, idempotency-keyed?
- All multi-record writes in one transaction, with side effects moved to after-commit?
- Lists bounded and paginated; no N+1 (`data.md`)?
- Token flows store digests, check expiry + consumption, and don't leak resource existence?
- API envelope and error shape consistent with the rest of the surface; internals not exposed?
- Nothing secret in logs; every action authorized (`security.md`)?
