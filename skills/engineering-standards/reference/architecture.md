# Software Architecture

The decisions that are expensive to reverse: boundaries, interfaces, technology choices, and the qualities the system must have. Architecture is not diagrams — it is the set of constraints that shape everything built afterward. Heavily informed by *97 Things Every Software Architect Should Know* (axioms cited as **#n**), *Fundamentals of Software Architecture* (Richards & Ford), *A Philosophy of Software Design* (Ousterhout), and *Building Evolutionary Architectures*.

> "Before anything, an architect is a developer." (**#63**) — if you design it, you should be able to code it (**#75**). Architecture divorced from implementation is fiction.

---

## Architecture is balancing tradeoffs — there are no right answers, only fits

> "Architecting is about balancing." (**#14**) · "Everything in software architecture is a tradeoff." (Richards/Ford's First Law) · "There is no one-size-fits-all solution." (**#12**)

- Every choice buys one quality at the cost of another: consistency vs. availability (`data.md`, `cloud.md`), simplicity vs. flexibility, performance vs. readability, build speed vs. operability. There is no free lunch — only a lunch whose price you understood or didn't.
- **Name the tradeoff explicitly.** "We chose X over Y; we gain A, we pay B; we accept B because C." An unstated tradeoff is a decision nobody can later evaluate.
- **"Prefer principles, axioms and analogies to opinion and taste." (#59)** When two engineers disagree, escalate to a principle, not to who's louder.
- **Use uncertainty as a driver (#24):** where you're unsure, defer the decision behind an interface, build a walking skeleton, or prototype — don't freeze a guess into the foundation.

---

## Quality attributes — the "-ilities" are the real requirements

Functional requirements say *what* the system does; quality attributes say *how well*, and they shape architecture far more. Make them explicit and measurable, or they won't happen.

- **Scalability, availability, reliability, performance** (latency/throughput), **security**, **maintainability**, **observability**, **testability**, **deployability**, **modifiability**, **portability**, **usability**.
- **Quantify them (#10):** "fast" is not a requirement; "p99 < 200ms at 1k rps" is. "Available" is meaningless; "99.95%, ≤ 5 min recovery" is testable. Unquantified qualities are wishes.
- They **conflict** — max security fights usability; max performance fights modifiability. Architecture is choosing the priority order *deliberately* and designing to it. **"Prepare to pick two." (#58)**
- **"It's never too early to think about performance" (#13)** and **"Application architecture determines application performance" (#5)** — you cannot bolt on a quality the structure precludes. A synchronous chain of ten services will never be low-latency no matter how you tune each one.

---

## Boundaries and interfaces are the whole job

> "An architect's focus is on the boundaries and interfaces." (**#50**) · "Engineer in the white spaces." (**#41**) — the interesting failures live *between* components, not inside them.

- **Design the seams first.** What are the modules/services, and what flows across each boundary? Get the boundaries right and the insides can be refactored freely; get them wrong and no amount of clean code inside saves you.
- **A boundary is a contract** — an interface, an API, a schema, a message format. It is the most expensive thing to change because every side depends on it. Version it, keep it backward-compatible, evolve it with expand/contract (`backend.md`, `data.md`).
- **High cohesion within a boundary, low coupling across it** (the universal law, made structural). Things that change together belong in the same module/service; a change that ripples across five services means your boundaries are wrong.
- **Conway's Law (#41's cousin):** your architecture *will* mirror your org's communication structure. Design team boundaries and module boundaries together, or they'll fight.
- **"For the end-user, the interface is the system." (#96)** — what the user touches *is* the architecture to them. Internal elegance the user never feels is not where the value is.

---

## Domain-Driven Design — model the business, not the database

When the domain is complex, structure the software around it (Eric Evans, *DDD*). **"Understand the business domain." (#30)** · "It is all about the data." (**#61**)

- **Ubiquitous language**: code, conversation, and docs use the *same* terms the domain experts use. When the business says "settlement," the class is `Settlement`, not `TxnFinalizer`. Translation layers between business language and code are where bugs hide.
- **Bounded contexts**: a model is valid only within a boundary. "Customer" in billing ≠ "Customer" in support — don't force one giant shared model. Separate contexts, with explicit translation at the seams. This is the single most useful tool for carving a monolith or sizing microservices.
- **Aggregates** define consistency boundaries: a cluster of objects that change together under one transaction and one invariant (`data.md`). The aggregate root is the only entry point.
- **"Control the data, not just the code." (#86)** — data outlives code. Schemas, formats, and ownership are architectural decisions, often more permanent than the services over them.

---

## Decompose deliberately — monolith vs. services is a tradeoff, not a fashion

- **Start with a modular monolith by default.** It's simpler to build, deploy, debug, and refactor; boundaries are cheap to move while you're still learning the domain. **"Simplicity before generality, use before reuse." (#18)** and **"Scope is the enemy of success." (#35)**
- **Reach for distribution to solve a real problem** — independent scaling, independent deploy cadence, team autonomy, fault isolation — *not* for résumé reasons. **"Don't put your résumé ahead of the requirements." (#1)** Microservices buy organizational scaling and pay for it in network failure, distributed transactions, and operational complexity (`cloud.md`, `concurrency.md`).
- **"Skyscrapers aren't scalable." (#38)** — you cannot incrementally grow a structure designed as a monolith into a distributed one for free; the right structure depends on the target.
- If you do split: each service owns its data (no shared database), communicates over explicit contracts, and is independently deployable. A "distributed monolith" (services that must deploy together) is the worst of both worlds.

---

## Evolutionary architecture — you can't future-proof, so design to change

> "You can't future-proof solutions." (**#93**) · "Time changes everything." (**#33**) · "Your system is legacy, design for it." (**#65**) · "Great software is not built, it is grown." (**#97**)

- Optimize for **changeability over prediction.** You will be wrong about the future; the win is making the eventual change cheap, not guessing it right.
- **Reversible decisions are cheap; irreversible ones deserve deliberation.** Spend your analysis budget on the one-way doors (data model, public API, core boundaries); move fast on the two-way doors (an internal helper, a swappable library).
- **Fitness functions**: encode the qualities you must preserve as automated checks (a perf budget test, an architecture-dependency lint, a coupling metric) so evolution can't silently violate them.
- **Walking skeleton (#60):** build the thinnest possible end-to-end slice that exercises every architectural element (UI → service → DB → deploy) *first*, then flesh it out. It validates the architecture against reality before you've poured the foundation.

---

## Record the rationale — the *why* is the asset

> "Record your rationale." (**#52**) · "Challenge assumptions — especially your own." (**#53**)

- **Write Architecture Decision Records (ADRs):** for each significant decision, one short doc — *context, the options, the choice, the consequences.* The decision matters less than the recorded reasoning; six months later nobody remembers *why*, and they either cargo-cult it or rip it out blindly.
- ADRs make assumptions visible so they can be challenged. The most dangerous assumptions are the unstated ones everyone "just knows."
- **"Understand the impact of change." (#67)** — before changing a boundary, trace who depends on it. A change that looks local at the code level can be global at the architecture level.

---

## Technical debt is a real liability — service it

> "Shortcuts now are paid back with interest later." (**#69**) · "Pay down your technical debt." (**#87**)

- Debt isn't always bad — a deliberate shortcut to hit a window can be the right call. The sin is **unacknowledged** debt and debt you never repay. Take it like a loan: knowingly, recorded, with a plan to pay it back.
- Track it visibly (a debt log, TODOs that link to tickets) and budget regular paydown. Debt compounds: the interest is every future change made slower by the shortcut.
- **"'Perfect' is the enemy of 'good enough'." (#70)** — gold-plating is its own debt. Ship the good-enough solution to a stable problem; don't burn the budget polishing what doesn't need it. **"Stable problems get high quality solutions." (#77)** — invest depth where the problem will stay put.

---

## Don't be clever; make the simple stuff simple

> "Don't Be Clever." (**#80**) · "Make sure the simple stuff is simple." (**#62**) · "A rose by any other name will end up as a cabbage." (**#76**) — naming and clarity are architecture too.

- Cleverness is a withdrawal from the maintainability account someone else pays back. The boring, obvious structure that a new engineer groks in a day beats the elegant one only you understand.
- The common path must be the easy path. If the simple 80% case requires understanding the complex 20%, the abstraction is inverted — make the simple thing simple, and the complex thing *possible*.

---

## Everything fails — design for it (the bridge to operability)

> "Everything will ultimately fail." (**#8**)

Hardware dies, networks partition, dependencies time out, disks fill, deploys go bad. Architecture's job is to ensure that *when* (not if) a component fails, the blast radius is bounded and recovery is fast. The mechanics — timeouts, retries, circuit breakers, bulkheads, graceful degradation, observability — live in `cloud.md`; the architectural mandate is: **make failure a designed-for case, never a surprise.**

---

## Architecture review checklist

- Are the significant tradeoffs named, with what's gained, what's paid, and why the cost is acceptable?
- Are the quality attributes (the -ilities that matter here) explicit and **quantified**, with the priority order chosen deliberately?
- Are module/service boundaries drawn around cohesion and change, with explicit, versioned, backward-compatible contracts across them?
- Does the decomposition (monolith vs. services) solve a real problem, with each service owning its data — no distributed monolith?
- Is the domain modeled in a ubiquitous language with bounded contexts, aggregates as consistency boundaries?
- Is the design optimized for change (reversible decisions favored, fitness functions guarding qualities, walking skeleton proven end-to-end)?
- Are significant decisions captured as ADRs with their rationale; are key assumptions written down and challenged?
- Is technical debt acknowledged, tracked, and budgeted for paydown — and is the solution "good enough," not gold-plated?
- Is failure designed for at every boundary (bounded blast radius, fast recovery)?
