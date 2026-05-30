# Testing & Quality

Tests exist to let you change code with confidence. A test suite that's slow, flaky, or coupled to implementation does the opposite — it gets ignored or deleted. The goal is a fast, deterministic, behavior-focused suite that fails for exactly one reason: the behavior broke. Draws on the test pyramid (Cohn), *Working Effectively with Legacy Code* (Feathers), and *Growing Object-Oriented Software, Guided by Tests*.

---

## Test behavior, not implementation

> Test what the code *does* (its contract), never *how* it does it.

- A good test survives a refactor: you can rewrite the internals and it stays green because the observable behavior is unchanged. A test that breaks every time you rename a private method or reorder calls is testing the implementation — it's a maintenance tax with no safety value.
- **Assert on outputs and observable effects**, not on internal calls. Heavy mock-and-verify ("was `save` called exactly once with these args?") couples the test to the structure; prefer checking the *result* (the record exists, the response is correct).
- Black-box the unit: feed inputs at its public boundary, assert on what comes out. Reach inside only when the effect is genuinely invisible from outside.

---

## The pyramid — shape the suite by cost

```
        ╱ E2E ╲          few   — slow, brittle, high-fidelity; only critical user journeys
      ╱─────────╲
    ╱ Integration ╲      some  — real boundaries (DB, queue), moderate speed
  ╱─────────────────╲
 ╱   Unit tests       ╲  many  — fast, isolated, the bulk of your coverage
```

- **Unit (the base)** — fast, isolated, no real I/O. These run in milliseconds, so you run them constantly. The bulk of your tests live here, covering logic, branches, and edge cases.
- **Integration (the middle)** — exercise real boundaries: actual database, real queue, real HTTP between your components. Slower, fewer, but they catch what unit tests with mocks can't — wrong SQL, serialization mismatches, wiring bugs.
- **E2E (the tip)** — full system through the real UI/API. Highest fidelity, slowest, flakiest. Reserve for a handful of **critical journeys** (sign-up, checkout, the money path). An E2E-heavy suite (the "ice cream cone" anti-pattern) is slow and perpetually red.

(For browser E2E on web workflows, the `qa-testing-playwright` skill drives real flows.)

---

## Determinism is non-negotiable

A flaky test is worse than no test: it trains the team to ignore red, and a real failure hides in the noise. Every source of non-determinism must be controlled.

- **Time** — never call the real clock in a test. Inject it; freeze it. Tests that depend on `now()`, timezones, or "tomorrow" fail at midnight, at year-end, and in other regions.
- **Randomness** — seed it or inject it. A test that's green 99 runs and red the 100th is unowned randomness.
- **Ordering & isolation** — each test sets up and tears down its own state; none depends on running after another or on leftover data. Tests must pass in any order and in parallel. Shared mutable fixtures are the #1 flake source.
- **External services** — don't hit the real network in unit/integration tests. Use a fake/stub or a hermetic local instance. The test must not fail because someone's API was down.
- **Concurrency** — stress concurrent paths and run race detectors (`-race`, ThreadSanitizer) in CI; a race that's 1-in-10,000 in a test is a nightly outage in prod (`concurrency.md`).

---

## What to actually test

- **The branches and the edges, not the happy path twice.** Boundary values (0, 1, max, max+1, empty, null), the error paths, the "impossible" inputs. Bugs cluster at boundaries; that's where coverage earns its keep.
- **The bug you fix gets a test that fails first.** Reproduce it as a red test, then make it green. This proves the fix is real and nails the regression shut forever. (Regression testing.)
- **Contracts at boundaries.** When two components agree on an interface, test that agreement (contract/consumer tests) so one side can't drift and silently break the other.
- **Property-based tests** for logic with a wide input space (parsers, encoders, math, invariants): instead of a few hand-picked cases, assert a *property* holds across thousands of generated inputs ("decode(encode(x)) == x", "the total is always conserved"). They find the edge case you wouldn't have thought to write.

---

## Coverage is a flashlight, not a goal

- Coverage shows you what's *untested* — useful. It does **not** show you what's *well*-tested: 100% coverage with weak assertions catches nothing. Chasing a coverage number breeds tests that execute lines without verifying behavior.
- Aim coverage at risk: the money path, the auth path, the gnarly algorithm — not at trivial getters to inflate a percentage.
- **Mutation testing** is the real measure of test *strength*: it deliberately introduces bugs and checks your tests catch them. If a mutant survives, your tests run that code but don't actually assert on it.

---

## Tests as documentation and design pressure

- **Name tests as behavioral facts**: `transfer_fails_when_balance_below_amount`, not `test_transfer_2`. The suite read top to bottom should describe what the system does — executable documentation that can't go stale.
- **Arrange–Act–Assert**, one logical assertion per test. A test that checks five unrelated things gives a useless failure message; a focused test names exactly what broke.
- **Hard-to-test code is badly designed code.** When something is painful to test — needs ten mocks, can't be instantiated without the world — that's the design telling you it has too many dependencies or mixed concerns (`SKILL.md` law #2). Listen to it: fix the design, and the test gets easy. This is the deepest value of TDD — not the tests, but the design pressure.

---

## CI as the quality gate

- The suite runs on **every change**, automatically, before merge. A test that isn't in CI doesn't protect anything.
- **Fast feedback**: unit tests in seconds, the full suite in a few minutes. A 40-minute suite gets bypassed under deadline. Parallelize; split slow E2E into a separate stage.
- **Red means stop.** A failing build blocks merge — no merging on red, no "I'll fix it after." The moment red is negotiable, the suite is decoration.
- **Quarantine flakes loudly**, then fix or delete them fast. A tolerated flaky test erodes trust in every other test.

---

## Test doubles — name them precisely (Meszaros / Fowler)

"Mock" is used loosely to mean five different things; using the right double for the right reason keeps tests honest.

- **Dummy** — a placeholder passed to fill a parameter, never actually used.
- **Stub** — returns canned answers to calls (`repo.find → a fixed user`). Use to *provide* indirect input. State verification.
- **Fake** — a working but simplified implementation (an in-memory DB, a hash-map repository). Great for fast integration-ish tests without the real dependency.
- **Spy** — a stub that also records how it was called, so you can assert afterward.
- **Mock** — pre-programmed with *expectations*; the test fails if the expected calls don't happen. Behavior verification.

**Prefer state verification (assert the result) over behavior verification (assert which calls happened).** Heavy mocking couples the test to implementation — it asserts *how* the code works, so it breaks on every refactor (the anti-pattern in "test behavior, not implementation" above). Reach for mocks only when the effect is genuinely invisible from outside (e.g., "an email *was* sent"). **Don't mock what you don't own** — wrap a third-party API in your own thin interface and fake *that*; mocking the vendor's SDK directly bakes in assumptions about code you don't control.

## Beyond correctness — the other test types

Functional tests prove it's *right*; these prove it *holds up*:

- **Load / performance testing** — does it meet its latency/throughput targets (`architecture.md` quality attributes) at expected and peak traffic? Run before launch, not after the outage. Test against quantified goals ("p99 < 200ms at 1k rps").
- **Stress testing** — push *past* the limit to find the breaking point and confirm it fails *gracefully* (sheds load, returns 429/503, recovers) rather than catastrophically (cascades, corrupts, never recovers). **"Stretch key dimensions to see what breaks." (#74)**
- **Soak testing** — run at load for hours/days to surface leaks, unbounded growth, and slow degradation a short test misses.
- **Chaos engineering** — deliberately inject failure in production-like environments (kill a node, add latency, sever a dependency) to verify resilience (`cloud.md`) is real, not theoretical. "Everything will ultimately fail" (#8) — so prove your handling of failure *before* it happens unplanned.
- **Security testing** — SAST/DAST/dependency scans in CI; penetration testing for sensitive systems (`security.md`).
- **Accessibility testing** — automated axe-style checks plus keyboard/screen-reader passes (`frontend.md`).

## TDD as a design tool (not dogma)

- **Red → Green → Refactor**: write a failing test for the next small behavior, make it pass simply, then clean up under the green. The discipline keeps you writing testable, minimal code and gives you a safety net to refactor fearlessly.
- The deepest value isn't the tests — it's the **design pressure**. Code that's hard to test is telling you it has too many dependencies or tangled concerns; TDD surfaces that *before* you've written it (`SKILL.md` law #2, `paradigms.md` functional core).
- It's a tool, not a religion. Use it where it helps (logic with clear inputs/outputs); don't force it where it doesn't (exploratory spikes, trivial glue). The non-negotiable is *that the behavior ends up tested*, not the order you wrote it in.

## Testing review checklist

- Tests assert observable behavior/outputs, not internal calls — would they survive a refactor?
- Suite shaped like a pyramid: many fast unit, fewer integration at real boundaries, a few E2E on critical journeys?
- Fully deterministic — time injected, randomness seeded, tests isolated and order-independent, no real network, races stress-tested?
- Edges and error paths covered, not just the happy path; every fixed bug has a test that failed first?
- Property-based tests where the input space is wide; contract tests where components agree on an interface?
- Coverage aimed at risk (not a vanity number); test strength validated (mutation testing) where it matters?
- Named as behavioral facts, AAA, one logical assertion; hard-to-test code treated as a design smell to fix?
- Runs in CI on every change, fast, and red blocks merge?
