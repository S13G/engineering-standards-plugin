# Programming Paradigms & Design

Choosing and combining paradigms — and the design principles that cut across all of them. The point is not tribal allegiance to OOP or FP; it's knowing which tool each problem wants, and applying the timeless laws (immutability, pure functions, explicit data flow) that make code in *any* paradigm correct and changeable. Draws on SICP (Abelson & Sussman), *Out of the Tar Pit* (Moseley & Marks), *Domain Modeling Made Functional*, Sandi Metz, and *A Philosophy of Software Design*.

> "Learn a new language." (*97 Things* #92) — every paradigm you internalize gives you another lens on the same problem. The best engineers are multi-paradigm and choose deliberately.

---

## The real enemy, restated: state × complexity

> *Out of the Tar Pit*: the largest source of complexity in software is **mutable state** and the **control flow** that manages it. Most paradigm advice is really about taming those two.

Every paradigm is a strategy for managing state and flow:
- **Procedural/imperative** — explicit steps mutating state. Direct, close to the machine; scales poorly as state interactions multiply.
- **Object-oriented** — bundle state with the behavior that guards it; manage complexity via encapsulation and polymorphism.
- **Functional** — minimize and isolate state; compute with pure functions over immutable data. Manage complexity by *eliminating* it rather than encapsulating it.
- **Declarative** (SQL, regex, build rules, React's render) — say *what* you want, let the engine decide *how*. Highest leverage when it fits the domain.

None is universally best. **"Heterogeneity wins" (#39):** real systems mix them — a functional core, an OO domain model, declarative queries, imperative glue at the edges.

---

## Immutability — the highest-leverage default

Prefer values that never change after creation. This single habit removes whole categories of bugs.

- **No shared-mutable-state races** (`concurrency.md`): immutable data is automatically thread-safe — nothing to lock because nothing changes.
- **No spooky action at a distance:** if you pass an immutable value, no callee can mutate it under you. Defensive copying disappears; reasoning becomes local.
- **Time-travel and auditability:** keep old versions for free (undo, history, event sourcing in `data.md`).
- **Change by producing new values**, not editing in place. Modern languages make this cheap with structural sharing (persistent data structures). Frontend state, mobile state, and domain events all want this (`frontend.md`, `mobile.md`).

```
// BAD — mutation: who else holds a reference to this list? what did they see, and when?
cart.items.add(item); cart.total += item.price;     // aliasing + invariant drift

// GOOD — produce a new value; the old one is untouched and still valid for anyone holding it
newCart = cart.withItem(item)                         // total recomputed, original intact
```

Reserve mutation for tight, local, performance-critical hot loops where a profiler justifies it — and contain it behind a pure interface.

---

## Pure functions and the functional core / imperative shell

A **pure function**: output depends only on inputs, and it causes no observable side effects. Same input → same output, always (**referential transparency** — the call can be replaced by its result without changing the program).

Pure functions are the most testable, composable, parallelizable, and cacheable code you can write — no setup, no mocks, no order dependence.

**The pattern that organizes a whole system:** *functional core, imperative shell.*
- The **core** is pure: business logic, decisions, transformations — no I/O, no clock, no randomness, no DB. Trivial to test exhaustively.
- The **shell** is thin and imperative: it reads input, calls the pure core, and performs the resulting effects (write DB, send email, render). It holds all the messiness in one small, explicit place.
- This is the same instinct as thin-handler/rich-service (`backend.md`) and dumb-screen/testable-logic (`mobile.md`): **push side effects to the edges, keep the center pure.**

```
// Shell: gathers inputs, runs pure decision, executes the effect it returns
function handleTransfer(req) {
  const state  = repo.load(req.accountId)        // effect (in)
  const result = decideTransfer(state, req.amount)  // PURE core — all the logic, fully testable
  repo.apply(result.events)                       // effect (out)
  return result.response
}
// Core: no I/O, no clock — given the same state+amount, always the same decision
function decideTransfer(state, amount) { /* pure */ }
```

---

## When OOP earns its keep — and how to do it well

OOP shines when you have **stateful entities with invariants** and **behavior that varies by type**. Done well it's encapsulation + polymorphism; done badly it's the anemic data bags and god-objects everyone rightly complains about.

- **Encapsulate to protect invariants.** An object's whole point is that you cannot put it in an invalid state from outside — the data is private, mutated only through methods that enforce the rules. A class with public fields and no invariants is just a struct; don't dress it up.
- **Tell, don't ask.** Send an object a message to *do* something; don't pull its data out to decide for it. `account.debit(x)` beats `if account.balance >= x: account.balance -= x` — the second leaks the invariant into every caller (Law of Demeter, `SKILL.md`).
- **Polymorphism over type-switching; composition over inheritance** (universal laws). Inheritance is for genuine, stable "is-a" with Liskov substitutability; everything else is composition. Deep inheritance hierarchies are a classic maintenance trap.
- **Keep objects small and single-responsibility.** A 2000-line class is a procedural program hiding in a class. Sandi Metz's rules of thumb (small classes, short methods, few parameters) exist to keep objects honest.

---

## When FP/declarative earns its keep

- **Data transformation pipelines** — map/filter/reduce over collections beats hand-rolled loops with mutable accumulators: less state, fewer off-by-ones, composable.
- **Concurrency and parallelism** — immutability + pure functions remove the need for most locks (`concurrency.md`).
- **Domain modeling with types** — make illegal states unrepresentable: a sum type (`Pending | Settled | Failed`) the compiler checks beats a string `status` + a pile of booleans that can contradict (`data.md`, *Domain Modeling Made Functional*).
- **Declarative where a good engine exists** — SQL for set operations, a rules engine for rules, a reactive framework for UI. Don't reimplement in imperative code what a declarative engine does better and safer.

---

## Cross-paradigm laws (true everywhere)

- **Make data flow explicit.** Inputs in, outputs out; avoid action-at-a-distance through hidden global/mutable state. The reader should trace where a value comes from and goes.
- **Isolate side effects.** I/O, clock, randomness, network — push them to identifiable edges so the core stays pure and testable. Hidden side effects are the hardest bugs to find.
- **Compose small pieces.** Whether functions, objects, or modules: build large behavior from small, well-named, independently-testable units (`SKILL.md` law #1, deep modules).
- **Prefer expressions and immutability to statements and mutation** where the language allows — fewer moving parts, easier to reason about.
- **Don't be dogmatic.** A pure-FP zealot writing contortions to avoid a local mutable loop, or an OO zealot wrapping every function in a class, is serving the paradigm instead of the problem. Serve the problem.

---

## Paradigm review checklist

- Is mutable state minimized and isolated; are values immutable by default, mutation reserved for justified hot paths?
- Is the business logic in a pure core (no I/O/clock/randomness) with side effects pushed to a thin imperative shell?
- Are pure functions used where possible (referentially transparent, trivially testable)?
- OOP: do objects encapsulate and protect invariants (no public mutable data bags, no god objects); tell-don't-ask; composition over inheritance?
- FP/declarative: pipelines over manual mutable loops; illegal states made unrepresentable via types; declarative engines used where they fit?
- Is data flow explicit (no action-at-a-distance via hidden global state)?
- Is the paradigm chosen to fit the problem, not imposed dogmatically?
