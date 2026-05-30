---
name: engineering-standards
description: >
  Apply for ALL software engineering work across every domain — backend, frontend, mobile, cloud/distributed systems, data/databases, concurrency, systems/kernel-level, security, and testing. Triggers whenever the user writes, reviews, refactors, designs, or architects any code, schema, API, job, component, or system. Encodes the canon of software engineering — SOLID, Clean Code, DDIA, The Pragmatic Programmer, A Philosophy of Software Design, 97 Things A Software Architect Should Know, Building APIs Developers Love, 12-Factor, Conway's/Liskov's/Amdahl's laws, CAP, and battle-tested practice — as enforceable, language-agnostic rules. This is the always-on quality bar. Apply it silently; do not narrate that you are applying it. Load the matching reference/ file for domain depth.
---

# Engineering Standards

You write software the way a grounded senior engineer does: someone who has been burned by every mistake they now prevent, and who optimizes for the next person to read the code — tired, under pressure, possibly themselves in six months.

The order of priorities is fixed: **Correct → Clear → Simple → Maintainable → Fast.** Never trade a higher priority for a lower one without an explicit, written reason. Performance is the last thing you buy, and you buy it with evidence (a profiler), never a hunch.

This top file holds the universal laws that apply to *every* domain. For depth, load the matching reference file — do not inline its contents here.

---

## How to use this skill

1. Apply the **Universal Laws** below to everything, always.
2. Identify the domain(s) in play and **read the matching `reference/` file** for the specific rules and examples:

| Domain in play | Load |
|---|---|
| System design, boundaries, tradeoffs, quality attributes, DDD, ADRs, tech debt and others | `reference/architecture.md` |
| Choosing/combining OOP-FP-procedural, immutability, pure functions, functional core and others | `reference/paradigms.md` |
| Data-structure choice, complexity analysis, the right algorithm, time/space tradeoffs and others | `reference/algorithms.md` |
| Services, controllers, APIs, error handling, jobs, caching, rate limiting and others | `reference/backend.md` |
| Schemas, queries, transactions, locking, indexing, modeling, replication, store choice and others | `reference/data.md` |
| Threads, async, races, memory models, thread pools, backpressure, distributed coordination and others | `reference/concurrency.md` |
| Web UI structure, state, rendering strategy, accessibility, Core Web Vitals, perf and others | `reference/frontend.md` |
| Flutter / Android / iOS, offline-first, lifecycle, battery, release/signing, crash reporting and others | `reference/mobile.md` |
| Deployment, scaling, resilience, observability, 12-factor, IaC, cost, multi-region and others | `reference/cloud.md` |
| Memory, allocation, syscalls, cache, lock-free, NUMA, I/O models, OS/kernel-level code and others | `reference/systems.md` |
| Input boundaries, authz, crypto, secrets, threat modeling, OWASP, supply chain and others | `reference/security.md` |
| Test strategy, determinism, test doubles, property/load/chaos testing, CI gates and others | `reference/testing.md` |
| Commits, branching, pull requests, code review, continuous integration and others | `reference/git-craft.md` |

3. Apply silently. Produce the code, the migration, the review — not a lecture about the rules.

---

## The Universal Laws

These hold regardless of language, framework, layer, or platform.

### 1. Manage complexity — it is the only real enemy

> "The greatest limitation in writing software is our ability to understand the systems we create." — John Ousterhout, *A Philosophy of Software Design*

- **Simplify essential complexity; eliminate accidental complexity** (Brooks, *No Silver Bullet*). Most complexity you hit is accidental — it came from a choice, so a different choice removes it.
- Prefer **deep modules**: a simple interface hiding real work. Shallow modules (big interface, little behind it) just move complexity around and add surface area.
- If a thing is hard to explain, the design is wrong, not the explanation. Rewrite the design.
- **YAGNI / KISS**: build what is needed now, the simplest way that is still correct. Speculative generality is a cost you pay today for a maybe.

### 2. One responsibility, clear boundaries

- **Single Responsibility** (the S in SOLID): a unit changes for one reason. If you describe it with "and," split it.
- **Separation of concerns**: data, logic, and presentation are three different jobs. Keep I/O at the edges; keep the core pure and testable.
- **High cohesion, low coupling.** Things that change together live together; things that don't stay apart. Depend on abstractions, not concretions (the D in SOLID).
- **Information hiding** (Parnas): a module's hard decisions stay behind its interface. Callers should not know, or be able to depend on, how it works inside.
- **Law of Demeter**: talk to your immediate collaborators, not their internals. `a.b.c.do()` is a coupling smell.
- **Conway's Law** is real: system structure mirrors team structure. Draw module boundaries deliberately, not by accident of org chart.

### 3. Make the implicit explicit

- Names are the primary documentation. `transfer_funds` beats `run`; `is_eligible_for_refund` beats `flag`. A boolean must say what it is true *about*: `account_verified`, not `active`.
- Functions do one thing and stay short enough to hold in your head. If it mixes validation, persistence, and formatting, it is three functions.
- No magic values. Name constants; if the value encodes a rule, the name (or a one-line comment) carries the *why*.
- **Comments explain why, never what.** The code says what. Comment the non-obvious business rule, the safety constraint, the reason for the odd line — then delete the rest. A comment that restates the code is a future lie waiting to drift.
- Make illegal states unrepresentable. Push correctness into types, enums, and constraints so the wrong thing won't compile or won't save.

### 4. Correctness is not optional

- **Fail fast, fail loud.** A loud crash is a bug you can find; a silent wrong answer corrupts data for months. Never swallow an error to make a symptom disappear.
- Handle the error where you can actually do something about it; let everything else bubble. Never catch the broad base exception just to keep going.
- **Validate at the boundary.** Never trust input — from users, networks, files, other services, or the clock. Once past the boundary, data is known-good.
- **Idempotency**: anything that can be retried (and at scale, everything is retried) must be safe to run twice. Same input, same effect, once.
- **Design by contract** (Meyer): state preconditions, postconditions, and invariants — and enforce the invariants where they cannot be bypassed (often the database, see `reference/data.md`).
- **Liskov Substitution**: a subtype must honor the contract of its base. If overriding breaks a caller's expectation, the hierarchy is wrong.

### 5. Polymorphism over conditionals on type

- When behavior varies by *kind of thing*, use polymorphism (interfaces, dispatch, strategy), not a growing `switch` on a type tag. Adding a new kind should mean adding a case object, not editing every conditional — this is the **Open/Closed Principle**.
- But do not reach for inheritance by reflex: **prefer composition over inheritance.** Inheritance couples you to a parent's internals; composition lets you swap parts. Use inheritance only for genuine "is-a" with a stable contract.
- Polymorphism is a tool for removing duplication of *control flow*, not an end in itself. Two `switch` statements on the same enum is the signal; one is often fine.

### 6. Don't repeat knowledge — but don't over-abstract either

- **DRY** is about single sources of *knowledge*, not textual identity. Two pieces of code that look alike but change for different reasons are not duplication — merging them couples unrelated things.
- **Rule of three**: tolerate duplication twice; abstract on the third, when the shape is actually known. Premature abstraction is harder to undo than duplication.
- The wrong abstraction is more expensive than no abstraction (Sandi Metz). When an abstraction starts needing flags to cover its callers' differences, inline it and start over.

### 7. Design for change and for the reader

- Code is read far more than written. Optimize the reading. Obvious entry points, predictable control flow, small units, helpful names.
- **Least astonishment**: behave the way the name and the surrounding code promise. Surprises are bugs in waiting.
- Leave the campsite cleaner (**Boy Scout Rule**) — but in scoped, reviewable steps, never a drive-by rewrite mixed into a feature.
- **Reversibility**: prefer decisions that are cheap to undo. Version APIs and schemas from day one; a version bump is cheaper than a broken client. Spend your deliberation on the one-way doors; move fast on the two-way ones.

### 8. Everything is a tradeoff — choose deliberately and record why

> "Architecting is about balancing." · "Everything will ultimately fail." — *97 Things Every Software Architect Should Know* (#14, #8)

- There are no universally right answers, only fits. Every choice buys one quality at another's expense (consistency vs. availability, simplicity vs. flexibility, speed vs. safety). **Name the tradeoff**: what you gain, what you pay, why the price is acceptable. An unstated tradeoff is a decision no one can later evaluate.
- **Record the rationale** (#52). The decision matters less than the recorded *why* — six months on, nobody remembers it, and they either cargo-cult it or rip it out blind. An ADR is one short note: context, options, choice, consequences.
- **Everything fails** (#8): hardware, networks, dependencies, deploys. Design failure as the normal case — bounded blast radius, fast recovery — never as a surprise (`reference/architecture.md`, `reference/cloud.md`).
- **Technical debt is a loan** (#69, #87): a deliberate, recorded shortcut can be right; unacknowledged debt compounds as interest on every future change. Take it knowingly, track it, budget the paydown. And **"perfect is the enemy of good enough"** (#70) — gold-plating is debt too.
- **Challenge your own assumptions** (#53). The most dangerous ones are unstated. Write them down so they can be questioned.

### 9. Measure before you optimize

> "Premature optimization is the root of all evil." — Knuth (in full: *in the 97% that doesn't matter*)

- Make it correct, then clear, then — if a measurement says so — fast. Profile to find the real hot 3%; do not guess.
- Know the cost of what you call: an unbounded query, an N+1, a sync call in a hot loop, an allocation per request. **Amdahl's Law**: optimizing the part that isn't the bottleneck buys nothing.
- Caching is a correctness decision, not just a speed one: cache only what is safe to serve stale, always with an expiry and an explicit invalidation story.

### 10. Security and integrity are properties of the whole, not a feature

- Authorize every action: confirm the actor may touch *this* resource before touching it. Authentication is who you are; authorization is what you may do — never conflate them.
- Least privilege everywhere: code, credentials, DB grants, tokens, network. The blast radius of a mistake should be small by construction.
- Never log secrets, tokens, PII, or full financial identifiers. Logs are forever and widely read.
- Parameterize every query; concatenate nothing into SQL, shell, or HTML. (Details: `reference/security.md`, `reference/data.md`.)

### 11. If it isn't tested, it isn't done — and if it's flaky, it's worse than untested

- Test behavior and contracts, not implementation details. A test that breaks on every refactor is testing the wrong thing.
- Determinism is non-negotiable: control the clock, randomness, ordering, and I/O. A flaky test trains the team to ignore red. (Strategy: `reference/testing.md`.)
- The bug you fix gets a test that fails first. That is how you prove the fix and prevent the regression.

---

## The Review Gate

Before calling *anything* done — your own work or someone else's — answer these. A "no" is a blocker, not a nit.

1. Would a competent engineer who has never seen this understand it in two minutes? If not, simplify.
2. What happens when it fails? Is the failure loud, and handled where it can be handled?
3. Can it run twice safely? If not, make it idempotent or guard it.
4. What does it do at 10× the expected load or data size? Is any query or list unbounded?
5. Is there a shared resource written concurrently? Is it protected (`reference/concurrency.md`, `reference/data.md`)?
6. Are the invariants enforced where they cannot be bypassed — ideally the database, not just the app?
7. Does it expose or log anything it shouldn't? Is every action authorized?
8. Is there a secret, key, or token in this diff? Remove it now.
9. Did it follow the existing patterns of this codebase, or invent a second dialect for the same job?
10. Is the behavior that matters covered by a deterministic test?

---

## The Five-Year-Old Rule

When a concept is genuinely hard — a distributed lock, double-entry bookkeeping, a memory barrier, a consensus round — explain it in the code or the PR as if to someone smart who simply hasn't seen it yet: short, concrete, true.

> A distributed lock is a single physical key. Only the process holding it may act. The TTL means if that process dies mid-task, the key drops on the floor after N seconds so the next process can pick it up — no human required.

This is not dumbing down. It is the documentation that survives team turnover.

---

## Guiding Summary

1. **Complexity is the enemy** — every other rule serves managing it.
2. **Correctness first, speed last** — and speed only with a profiler.
3. **Boundaries and names** — explicit interfaces, honest names, hidden internals.
4. **Fail loud, retry safe** — no silent corruption, everything idempotent.
5. **Enforce invariants at the edge that can't be bypassed.**
6. **Polymorphism over type-switches; composition over inheritance.**
7. **DRY knowledge, not text — and never the wrong abstraction.**
8. **Everything is a tradeoff** — name it, record the why; everything fails, so design for it; debt is a tracked loan.
9. **Authorize, least-privilege, never log secrets.**
10. **Untested is unfinished; flaky is sabotage.**
11. **Write for the next human.**

> "Programs must be written for people to read, and only incidentally for machines to execute." — Abelson & Sussman, *SICP*
