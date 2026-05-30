# Concurrency & Parallelism

Threads, async, shared state, memory models, and coordination across processes and nodes. The hardest correctness domain because bugs are non-deterministic — they pass a thousand tests, then corrupt production at 2am under load. Treat every shared mutable thing as guilty until proven safe.

Concurrency is *dealing with many things at once* (structure); parallelism is *doing many things at once* (execution). You can have one without the other.

---

## The root cause: shared mutable state + no ordering guarantee

Almost every concurrency bug is the same shape: two flows touch the same mutable thing, and nothing forces an order between them.

```c
// The canonical data race. counter++ is THREE operations, not one:
//   load counter → add 1 → store counter
// Two threads interleave those steps and one increment vanishes.
int counter = 0;
void worker() { for (int i = 0; i < 100000; i++) counter++; }   // BUG: unsynchronized
```

Three escapes, in order of preference:

1. **Don't share.** Give each worker its own data; combine at the end. No sharing, no race. (This is why pure functions and immutability are concurrency superpowers.)
2. **Don't mutate.** Share immutable data freely; replace instead of edit.
3. **If you must share mutable state, synchronize every access** — *all* of it, readers included. One unsynchronized read poisons the whole thing.

---

## Synchronization primitives — pick the weakest that's sufficient

- **Atomic** operations for single-variable counters/flags. Cheapest correct option when it fits.
- **Mutex / lock** to make a multi-step critical section indivisible. Hold it for as short a span as possible.
- **Read-write lock** when reads vastly outnumber writes and the critical section is non-trivial.
- **Condition variable / semaphore** to coordinate "wait until" without busy-spinning.
- **Channels / message passing** to hand off *ownership* instead of sharing — "share memory by communicating, don't communicate by sharing memory" (Go's model, and Erlang's, and CSP's).

```go
// Go: a channel hands the value's ownership across goroutines — no shared lock needed
results := make(chan int)
for _, job := range jobs {
    go func(j Job) { results <- process(j) }(j)   // each goroutine owns its job
}
total := 0
for range jobs { total += <-results }             // single consumer combines
```

```go
// When you DO share state, the lock guards every access — and defer guarantees release
type Counter struct{ mu sync.Mutex; n int }
func (c *Counter) Inc() { c.mu.Lock(); defer c.mu.Unlock(); c.n++ }
func (c *Counter) Get() int { c.mu.Lock(); defer c.mu.Unlock(); return c.n }  // read locks too
```

---

## The memory model — why "it looked fine" lies

On modern hardware and optimizing compilers, **writes are not guaranteed visible to other threads in program order** unless you synchronize. A thread can see a stale value indefinitely; the CPU reorders; the compiler hoists reads out of loops.

- This is why a plain `bool done` flag polled by another thread can spin forever even after it's "set." You need an atomic with the right *memory ordering*, a lock, or a language-level `volatile`/`Atomic` — a normal variable promises nothing across threads.
- **Happens-before** is the only ordering you can rely on: a lock release happens-before the next acquire; a channel send happens-before its receive; a thread's start happens-before its body. Build correctness on these edges, never on "the code is written in this order."
- Sequential consistency is the easy mental model; relaxed orderings are faster but a foot-gun. Use the strongest ordering until a benchmark proves you need to relax it.

---

## Deadlock, livelock, starvation

**Deadlock** needs all four Coffman conditions at once — break any one and it can't happen:
1. Mutual exclusion · 2. Hold-and-wait · 3. No preemption · 4. Circular wait.

The practical defenses:
- **Lock ordering.** Acquire locks in a single global order everywhere. The classic deadlock (A waits for B's lock while B waits for A's) is *only* possible if two code paths take them in opposite order. This rule alone prevents most deadlocks — and applies to DB row locks too (`data.md`).
- **Lock timeouts / try-lock.** Don't wait forever; back off and retry to break a potential cycle.
- **Hold one lock at a time** when you possibly can. Most deadlocks need at least two.

**Livelock** — threads keep reacting to each other and make no progress (two people stepping the same way in a hallway). Fix with randomized backoff. **Starvation** — a thread never gets the resource because others keep winning. Fix with fairness/queueing.

---

## Async / event loops — different model, same traps

Single-threaded async (Node, Python asyncio, UI main threads) has no *parallel* data races, but it has its own hazards:

- **Never block the loop.** A synchronous CPU-bound call or blocking I/O freezes *everything* — every other request, the whole UI. Offload to a worker/thread pool.
- **Interleaving is still real.** Between two `await`s, other tasks run and can change shared state. The state you read before `await` may be stale after it. Re-check invariants after awaiting.
- **No await left behind.** An unawaited promise/future is a silent dropped error and a leak. Await it or explicitly, deliberately fire-and-forget with error handling attached.
- **Bound your fan-out.** `await all(10000 requests)` opens 10000 sockets at once and falls over. Use a concurrency-limited pool.

---

## Distributed concurrency — the network changes everything

Across machines you lose shared memory and gain partial failure: any message may be lost, delayed, duplicated, or reordered, and you often can't tell "slow" from "dead."

- **CAP**: under a network partition you choose Consistency *or* Availability — not both. Decide deliberately per workflow (a payment chooses C; a "like" count chooses A).
- **Exactly-once delivery is a myth.** Build **at-least-once delivery + idempotent handlers** — the only combination that actually works. Every consumer dedupes. (Idempotency mechanics: `backend.md`, `data.md`.)
- **Distributed locks** (Redis/etcd/Zookeeper) coordinate across nodes — but they are *advisory* and clock-dependent. Always set a **TTL** so a crashed holder's lock self-releases; use a fencing token so a paused-then-resumed holder can't act on a stale lock.
- **Clocks lie.** Never order distributed events by wall-clock time. Use logical clocks (Lamport), version vectors, or a sequence the system controls.
- **Consensus is hard and solved** — don't invent it. Use Raft/Paxos via a real system (etcd, Zookeeper, your DB) when you need agreement; rolling your own is a reliable way to lose data.

```
# Distributed lock done safely: TTL so a dead holder releases; token so a zombie can't act
token = acquire("payout:" + id, ttl=30s) or fail("already processing")
try:    Payout.process(id, fence=token)   # storage rejects writes with a stale token
finally: release("payout:" + id, token)
```

---

## Thread pools, backpressure, and bounded resources

Unbounded concurrency is a denial-of-service you inflict on yourself. Every concurrent system needs limits.

- **Use a bounded thread/worker pool**, never "spawn a thread per request." Threads cost memory and scheduler time; ten thousand of them thrash. A fixed pool caps resource use and makes behavior predictable under load.
- **Size the pool to the work, not by guessing.** CPU-bound work: ~number of cores (more just adds context-switch overhead). I/O-bound work: higher, because threads sit waiting — but bounded by the *downstream* limit (DB connections, the API's rate cap), not by optimism. A pool bigger than the database's connection limit (`data.md`) just queues pain.
- **Backpressure: bound every queue.** An unbounded in-memory queue between a fast producer and a slow consumer is a memory leak that ends in OOM. Bound the queue and decide what happens when it's full — block the producer (natural backpressure), drop oldest/newest, or reject (`429`/`503`, `cloud.md`). Silently buffering forever is never the answer.
- **Reactive streams / flow control** propagate backpressure end-to-end: the consumer signals how much it can take, so the producer slows instead of overwhelming. Prefer a library that does this over hand-rolled queues for streaming pipelines.

## The actor model — concurrency without shared locks

An alternative that sidesteps most lock bugs (Erlang/OTP, Akka, Elixir): state is owned by **actors** that share *nothing* and communicate only by asynchronous messages. Each actor processes one message at a time, so its state never needs a lock — the message queue serializes access for free.

- Great fit for stateful concurrent entities (a connection, a session, a game character, a device), and for fault isolation: an actor can crash and be restarted by a supervisor ("let it crash") without taking down its neighbors.
- The tradeoffs: message-passing overhead, eventual consistency between actors, and you still face distributed-systems realities once actors span nodes. It moves the hard part from "locking" to "message protocols," which is usually a better place for it.

## Concurrency review checklist

- Is any mutable state shared between flows? If yes, is **every** access (reads included) synchronized, or is the state immutable / not shared?
- Could two paths acquire the same two locks in opposite order? Enforce one global lock order.
- Are locks held across I/O, network calls, or user think-time? Shorten the critical section.
- Cross-thread flags/state via atomics or locks, never plain variables relying on visibility?
- Async: nothing blocks the loop; shared state re-checked after every `await`; every future awaited or deliberately handled; fan-out bounded?
- Distributed: at-least-once + idempotent consumers; distributed locks have TTL + fencing; ordering by logical clock, not wall time?
- Is there a deterministic test (stress/race detector, e.g. `-race`, ThreadSanitizer) exercising the concurrent path? (`testing.md`)
