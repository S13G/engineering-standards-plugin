# Data & Database Engineering

Schema design, queries, transactions, locking, indexing, and data modeling. Storage-engine-agnostic where possible; SQL examples are illustrative. Draws on *Designing Data-Intensive Applications* (Kleppmann), *Database as a Fortress* (Chak), and relational theory. For coordination across processes/nodes see `concurrency.md`; for injection/grants see `security.md`.

---

## The database is the last line of defense

Application code is one of *many* writers over a schema's lifetime — migrations, admin consoles, scripts, the next service, a future you at 3am. Any invariant enforced only in app code *will* eventually be violated by a writer that skips it. **Put the rules where they cannot be bypassed: in the schema.**

App validations are friendly guardrails (good error messages, early feedback). DB constraints are the fortress wall. You want both, and you never rely on the guardrail alone.

### Constraints to reach for by default

- `NOT NULL` wherever null is meaningless. A nullable column is a question every reader must answer ("what does null mean here?"); remove the question when you can.
- **Foreign keys** on every reference. The ORM will not save you from an orphaned row; the constraint will.
- **Unique constraints** for anything that must be unique — email, idempotency key, `(account_id, slug)`. This is also your concurrency backstop (see "uniqueness as a lock" below).
- **Check constraints** for ranges and enums the DB supports: `amount_minor > 0`, `status IN (...)`.
- **Defaults** that keep a row valid the moment it exists.

```sql
-- A row that cannot be invalid, enforced by the engine itself
ALTER TABLE transactions
  ADD COLUMN amount_minor   bigint NOT NULL,
  ADD COLUMN status         text   NOT NULL DEFAULT 'pending',
  ADD CONSTRAINT positive_amount CHECK (amount_minor > 0),
  ADD CONSTRAINT valid_status     CHECK (status IN ('pending','settled','failed'));

CREATE UNIQUE INDEX idx_txn_idempotency ON transactions (idempotency_key);
```

---

## Modeling

- **Model the domain, then the storage** — but respect normal forms first, denormalize only with a measured reason. Third normal form is the default; every column depends on the key, the whole key, and nothing but the key.
- Store money as integer **minor units** (cents) or a fixed-precision decimal — never a float. Floating point is for physics, not ledgers.
- Store time as UTC with an explicit type (`timestamptz`); convert at the edges. "Naive" local timestamps are a bug generator.
- Name booleans for what they assert (`is_email_verified`), and prefer an explicit enum/state column over a pile of correlated booleans that can contradict each other.
- A column means exactly one thing. Overloaded columns ("this is a user id, unless negative, then it's a group id") are a debugging tax forever.

---

## Transactions — atomicity is non-negotiable

If two writes must both happen or neither, they live in one transaction. Partial success is corrupted state.

```
-- BAD: a crash between these two lines leaves money missing
debit(sender, amount)
credit(receiver, amount)

-- GOOD: both or neither
BEGIN
  debit(sender, amount)
  credit(receiver, amount)
  ledger_entry(sender, receiver, amount)
COMMIT
```

**ACID, briefly and concretely:**
- **Atomicity** — all-or-nothing (the example above).
- **Consistency** — every commit leaves invariants true; this is *why* constraints live in the DB.
- **Isolation** — concurrent transactions don't corrupt each other; the *level* you pick decides which anomalies are possible (below).
- **Durability** — once committed, it survives a crash.

**Rules:**
- Keep transactions **short**. A long transaction holds locks and starves everyone else; throughput dies under contention.
- **Never do network I/O inside a transaction** — no HTTP, email, or queue publish. It can't roll back and it holds locks across an unreliable wait. Commit, then fire side effects (after-commit hook or transactional outbox).
- Don't span a transaction across a user's "think time" (an open form). Read, let them edit, then write with a concurrency check (see optimistic locking).

### Isolation levels — know what you're getting

The anomalies, from weaker to stronger isolation:

| Anomaly | What goes wrong | Prevented at |
|---|---|---|
| Dirty read | You read another txn's uncommitted write | Read Committed and above |
| Non-repeatable read | A row changes between two reads in your txn | Repeatable Read and above |
| Phantom | New rows appear matching your `WHERE` mid-txn | Serializable (or range locks) |
| Lost update | Two txns read-modify-write, one is silently clobbered | Optimistic/pessimistic lock, or Serializable |

Most engines default to **Read Committed** — which still allows lost updates. For read-modify-write on shared state, *you* must add protection. Don't assume the default is safe for money.

---

## Locking — preventing the lost update

The classic bug: two requests read a balance of 100, each subtracts 30, each writes 70. One debit vanished.

### Pessimistic locking — "I'll hold the row"

Take the lock first; nobody else can touch the row until you commit. Use when contention is real or correctness is critical (balances, inventory, seats).

```sql
BEGIN
  SELECT balance FROM accounts WHERE id = :id FOR UPDATE;  -- row locked here
  -- compute, validate balance >= amount
  UPDATE accounts SET balance = balance - :amount WHERE id = :id;
COMMIT  -- lock released
```

### Optimistic locking — "I'll check nobody changed it"

No lock held; you carry a version and the write fails if the row moved under you. Use when contention is low and you don't want to serialize readers.

```sql
UPDATE accounts SET balance = :new, version = version + 1
WHERE id = :id AND version = :version_i_read;   -- 0 rows updated ⇒ retry
```

### Uniqueness as a lock (and the atomic-update trick)

- A **unique constraint** is a free distributed lock: two concurrent inserts of the same idempotency key — one wins, the other gets a violation you can catch. Lean on it instead of "check then insert" (which races).
- For a pure decrement, an **atomic conditional update** can replace an explicit lock — and the check constraint is the safety net if logic ever slips:

```sql
UPDATE accounts SET balance = balance - :amount
WHERE id = :id AND balance >= :amount;          -- 0 rows ⇒ insufficient funds
-- plus: CHECK (balance >= 0) so corruption is impossible even on a bug
```

**Never** write `balance = balance - ?` without either a lock, a conditional `WHERE`, or both. And always keep deadlocks at bay by **acquiring locks in a consistent order** across the codebase. (Deadlock theory: `concurrency.md`.)

---

## Indexing — make reads fast without making writes slow

An index is a read accelerator you pay for on every write. Add them deliberately.

- **Index every foreign key** (the engine usually won't for you) and every column in a hot `WHERE`, `JOIN`, or `ORDER BY`.
- **Composite index order matters.** `(status, created_at)` serves "pending, newest first" and also plain "by status"; it does *not* serve "by created_at alone." Put the equality column first, the range/sort column second.
- **Partial indexes** for skewed queries: `WHERE status = 'pending'` indexes only the live rows — smaller, faster, cheaper to maintain.
- **Covering indexes** let an index satisfy a query without touching the table; great for hot read paths.
- Don't over-index: each one slows writes and costs storage. Index the queries you actually run.
- **Read the plan.** `EXPLAIN ANALYZE` before shipping anything heavy. A sequential scan on a large table in a hot path is a latent outage.

---

## Query discipline

- **Never an unbounded result set.** Always `LIMIT`; paginate everything user-facing. Prefer **keyset/cursor pagination** (`WHERE id < :last ORDER BY id DESC LIMIT 25`) over `OFFSET` — offset gets linearly slower and skips/duplicates rows under concurrent writes.
- **Kill N+1.** One query in a loop becomes 1+N queries. Eager-load or batch. This is the single most common silent performance killer in app code.
- **Project only the columns you need.** `SELECT *` ships dead weight and breaks when the schema grows.
- Push work to the database when the DB does it better (aggregation, filtering, sorting on indexed columns) — and pull it into app code when the logic is genuinely application logic. Don't shuttle 100k rows to the app to count them.

---

## Migrations — change schema without downtime

- **Reversible.** Every migration has a clean down path, or an explicit, documented reason it's one-way.
- **Expand/contract for anything breaking.** To rename or retype a column on a large, live table: add the new column → backfill in batches → write to both → switch reads → stop writing the old → drop it. Several deploys, never one.
- **Never remove a column in the same deploy that stops using it.** Old app instances are still running during a rollout and will query it.
- **Add indexes concurrently** (`CREATE INDEX CONCURRENTLY` / `algorithm: inplace` equivalents) on big tables so you don't lock writes for the duration.
- **Backfill in batches** with pauses; a single `UPDATE` over millions of rows locks the table and floods replication.

---

## Choosing the store — SQL is the right default; reach past it for a reason

> "It is all about the data." (*97 Things* #61) · "Control the data, not just the code." (#86) — the store outlives the app over it; choose deliberately.

- **Relational (Postgres/MySQL) is the default.** ACID transactions, constraints, joins, and a mature ecosystem solve most problems. Don't leave it without a concrete need — "NoSQL is web-scale" is not a reason.
- **Document (Mongo, etc.)** — schema-flexible, denormalized aggregates read as a unit. Good for varied/evolving shapes; you trade away joins and (often) cross-document transactions, so model around your access pattern.
- **Key-value (Redis, DynamoDB)** — O(1) lookups, caching, sessions, counters, queues. Blazing for known-key access; not for ad-hoc queries.
- **Wide-column (Cassandra)** — massive write throughput, multi-region availability; you design tables per query and give up flexible querying and strong consistency.
- **Graph (Neo4j)** — when relationships *are* the data (social, fraud rings, recommendations) and you traverse many hops.
- **Search (Elasticsearch)** — full-text and faceted search; a read-optimized index fed *from* your source of truth, never the source of truth itself.
- **Time-series (Timescale, Influx)** — metrics/events at high ingest with time-window queries.

**Polyglot persistence** is normal: Postgres as the source of truth, Redis for cache, Elasticsearch for search — each fed from the authoritative store. Pick per workload; keep one system the source of truth.

## Replication, sharding, and the consistency you actually get

- **Replication** (one primary, many read replicas) scales reads and gives failover. The catch: **replication lag** — a replica is *eventually* consistent, so "read your own write" can return stale data right after a write. Route reads that must see the latest write to the primary; everything else can use replicas.
- **Sharding/partitioning** scales writes by splitting data across nodes by a **shard key**. Choosing the key is the whole game: a bad key creates hot shards (everything lands on one) and makes cross-shard queries and transactions painful. Shard only when one node genuinely can't hold the write load — it adds permanent complexity.
- **CAP, concretely** (`cloud.md`): under a network partition you get Consistency **or** Availability, not both. A distributed store is **CP** (refuse writes to stay correct — pick for money/inventory) or **AP** (accept writes, reconcile later — pick for likes/feeds). Know which yours is, per workload.
- **Consistency is a spectrum**, not a switch: **strong** (every read sees the latest write — single-node SQL, or a CP store), **eventual** (replicas converge given time), and middles like **read-your-writes** and **monotonic reads**. Pick the *weakest* model the workflow can tolerate — stronger consistency costs latency and availability.

## Connection pooling & operational data hygiene

- **Pool connections.** A DB connection is expensive to open and the DB caps how many it allows. Use a bounded pool (app-side, or PgBouncer); never open a connection per request. An exhausted pool manifests as mysterious latency and timeouts under load.
- **Size the pool to the DB's limit, not the app's optimism.** 50 app instances × 20 connections each = 1000 connections — past most DBs' ceiling. Total connections across all instances must fit the server's max.
- **Set statement timeouts** so one runaway query can't pin a connection forever. Keep transactions short (above) — a long-held transaction holds its connection and its locks.

## Event sourcing & CQRS (when the audit trail *is* the requirement)

- **Event sourcing**: store the sequence of *events* (immutable facts: `MoneyDeposited`, `MoneyWithdrawn`) as the source of truth; derive current state by replaying them. You get a perfect audit log, time-travel, and natural fit for ledgers and compliance — at the cost of more complexity and eventual-consistency read models.
- **CQRS** (Command Query Responsibility Segregation): separate the write model (optimized for validating commands and enforcing invariants) from the read model (denormalized, optimized for queries). Powerful for read-heavy systems with complex reporting — and overkill for simple CRUD. Don't adopt either reflexively; they earn their complexity only when audit/scale/reporting demands it (`paradigms.md` immutability connection).

---

## Data review checklist

- Every invariant that must always hold enforced by a DB constraint, not just app code?
- Money as integer/decimal, time as UTC with an explicit type?
- All multi-write workflows wrapped in one short transaction, side effects deferred to after-commit?
- Every read-modify-write on shared state protected (pessimistic lock, optimistic version, or atomic conditional update)?
- Locks acquired in a consistent order to avoid deadlocks?
- FKs and hot-path columns indexed; composite index column order matches the query; plan checked with `EXPLAIN`?
- Queries bounded and paginated (keyset, not offset, for large sets); no N+1; no `SELECT *` in hot paths?
- Migration reversible, index built concurrently, column drops deferred a deploy, big backfills batched?
