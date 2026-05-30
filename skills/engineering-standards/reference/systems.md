# Systems & Low-Level Engineering

Memory, allocation, the cache hierarchy, syscalls, and OS/kernel-adjacent code. Where the abstractions end and the hardware is real. The cost of a mistake here is a security hole, a corruption, or a 100× slowdown — not a failed assertion. Discipline matters more, not less. Examples are C/C++/Rust-flavored because that's where this work lives. Concurrency at this level: `concurrency.md` (the memory model is essential here).

---

## Memory is manual truth — own every byte's lifecycle

Every allocation has exactly one owner responsible for freeing it exactly once. Ambiguous ownership is the root of the entire class of memory bugs.

The four classic catastrophes, and what causes each:
- **Use-after-free** — using memory after it's freed. Owner freed it while someone else still held the pointer.
- **Double free** — freeing the same block twice. Two parties thought they owned it.
- **Leak** — never freeing. No owner took responsibility, or an error path skipped the free.
- **Buffer overflow** — writing past the end. No bounds check. This is the #1 source of remote-code-execution exploits in history (`security.md`).

```c
// BAD: ownership unclear, error path leaks, no bounds discipline
char *buf = malloc(len);
if (process(buf) < 0) return -1;   // LEAK: buf never freed on the error path
strcpy(buf, src);                  // OVERFLOW: no check that src fits in len
free(buf);

// GOOD: single owner, single exit that always frees, bounded copy
char *buf = malloc(len);
if (!buf) return -ENOMEM;          // check EVERY allocation
int rc = process(buf);
if (rc == 0) {
    size_t n = strnlen(src, len - 1);   // bounded; reserve the NUL
    memcpy(buf, src, n);
    buf[n] = '\0';
}
free(buf);                         // one owner, one free, on every path
return rc;
```

**Rules:**
- **Check every allocation.** `malloc` can return NULL. Dereferencing it is a crash or worse.
- **One owner, one free, on every path** — including every error and early return. RAII (C++), ownership/borrow (Rust), or `goto cleanup` (C) exist precisely to make "free on every path" automatic. Use them; don't hand-track frees across branches.
- **Null the pointer after free** (or use a scheme that does) so a stale use is a clean crash, not a silent use-after-free.
- **Never trust a length from outside.** Every copy into a fixed buffer is bounded by the buffer, not by the input. `strcpy`/`sprintf`/`gets` are banned; use the `n`-bounded forms and still verify.
- **Prefer a language or tool that enforces this.** Rust's borrow checker, C++ smart pointers + RAII, and ASan/Valgrind/UBSan in CI turn whole bug classes into compile errors or test failures. This is the highest-leverage choice you can make in systems code.

---

## Mechanical sympathy — the hardware is not uniform

> "You don't have to be an engineer to drive a car, but you do have to understand the engine to race one." — Martin Thompson's *mechanical sympathy*.

Performance at this level is dominated by **memory access patterns**, not instruction count. The CPU is fast; memory is slow; the gap is enormous.

- **The cache hierarchy is everything.** An L1 hit is ~1ns; a main-memory miss is ~100ns — a 100× difference. The same algorithm can run 10–100× faster purely by being cache-friendly. Big-O hides this completely.
- **Locality wins.** Access memory sequentially and contiguously so the prefetcher and cache lines work for you. This is why an array beats a linked list for traversal despite identical Big-O — the array is contiguous; the list chases pointers all over RAM, missing cache on each hop.
- **Data-oriented design.** Lay out data the way it's *accessed*, not the way it's conceptually grouped. A struct-of-arrays often crushes an array-of-structs for bulk processing, because you load only the fields you touch into cache.
- **False sharing kills parallel scaling.** Two cores updating different variables that happen to sit on the *same cache line* ping-pong that line between caches, serializing what should be parallel. Pad/align hot per-core data to its own cache line.
- **Branch prediction matters in hot loops.** Unpredictable branches stall the pipeline; sorting data or going branchless can win big — but only where a profiler says it matters (the universal law still rules).

---

## Syscalls and the user/kernel boundary

A system call is a context switch into the kernel — far more expensive than a function call. The boundary is also a trust and safety frontier.

- **Syscalls are expensive; batch them.** Reading 1 byte at a time with a syscall each is pathological. Buffer, and use vectored (`readv`/`writev`) or batched (`io_uring`, `sendmmsg`) interfaces to amortize the crossings.
- **Always check the return value** of every syscall and handle `errno`. They fail for real reasons (`EINTR`, `EAGAIN`, `ENOMEM`, `EINTR` on signals). Retry `EINTR`; respect `EAGAIN` on non-blocking I/O. Ignoring a syscall result is how data silently doesn't get written.
- **Validate everything crossing the boundary.** In kernel/driver code, *never trust a user-space pointer or length*: validate it, and copy with the safe accessors (`copy_from_user`/`copy_to_user`) — never dereference a user pointer directly. A missing check here is a privilege-escalation exploit.
- **Mind blocking.** A blocking syscall stalls the thread; in an event loop it stalls everything (`concurrency.md`). Use non-blocking I/O + readiness (`epoll`/`kqueue`/`io_uring`) for scalable servers.
- **Release every kernel resource you acquire** — fds, mmaps, locks — on every path. An fd leak exhausts the process's table and then everything fails to open.

---

## Determinism, portability, and undefined behavior

- **Undefined behavior is not "implementation-defined" — it's a license for the compiler to do anything**, including delete your safety checks. Signed overflow, reading uninitialized memory, out-of-bounds access, data races: all UB. Code that "works" while invoking UB is a time bomb the next compiler version detonates. Enable `-fsanitize=undefined` and the strict warnings, and fix the cause.
- **Don't assume sizes, endianness, or alignment.** `int` is not always 32 bits; pointers aren't always 64; structs have padding. Use fixed-width types (`uint32_t`) for anything on the wire or on disk, and serialize explicitly rather than `memcpy`-ing a struct.
- **Initialize before use.** Reading uninitialized memory is UB and a classic info-leak (you read whatever a previous owner left there — possibly a secret).
- **Avoid premature micro-optimization even here.** Write clear, correct, bounds-checked code first; let the profiler and the cache analysis (`perf`, cache-miss counters) point you at the 3% that actually matters. Clever bit-twiddling that saves nothing measurable is just a bug you can't read.

---

## Memory barriers and lock-free programming — expert territory

When you need synchronization without locks (the hottest paths, lock-free queues, schedulers), you work directly with the memory model (`concurrency.md`) — and the margin for error is razor-thin.

- **Atomics with explicit memory ordering** are the tools: `relaxed` (no ordering, just atomicity — for counters you only read at the end), `acquire`/`release` (the workhorse pair — a release-store publishes everything written before it to whoever does the matching acquire-load), and `seq_cst` (sequential consistency — strongest, simplest to reason about, slowest). **Use `seq_cst` until a benchmark proves you need to relax it**; relaxed orderings are where the subtle, unreproducible bugs live.
- **Memory barriers/fences** prevent the CPU and compiler from reordering across a point. You rarely write them by hand now (atomics imply the right ones), but understand that without them, "write A then set ready-flag" can be observed by another core in the opposite order.
- **The ABA problem** haunts lock-free code: a value reads A, changes to B, changes back to A, and a naive compare-and-swap thinks nothing happened. Defend with tagged pointers/version counters or hazard pointers.
- **Reclamation is the hard part.** Freeing memory in a lock-free structure while another thread might still touch it needs epoch-based reclamation, hazard pointers, or RCU. **The honest rule: prefer a well-tested concurrent library to hand-rolled lock-free code.** Almost no one should write a lock-free structure from scratch — the verification cost is enormous and the bugs are non-deterministic. Reach for it only with a measured need and a way to formally/exhaustively test it.

## NUMA and topology awareness

On multi-socket servers, memory is **non-uniform**: a core accessing memory attached to *another* socket pays a large latency penalty. For performance-critical systems:

- **Keep data near the core that uses it** — pin threads and allocate their memory on the same NUMA node. Cross-node access and cross-node lock contention can dominate cost on big machines.
- This is the large-scale echo of cache locality: the closer the data, the faster — at every level from L1 to NUMA node to network.

## I/O models — match the model to the workload

- **Blocking I/O** — simple, one thread per connection. Fine at low concurrency; falls apart at high connection counts (a thread each is too much memory/scheduling).
- **Non-blocking + readiness multiplexing** (`epoll`/`kqueue`) — one thread watches thousands of fds, acting only on ready ones. The classic high-concurrency server model (the engine under most event loops, `concurrency.md`).
- **Asynchronous / completion-based** (`io_uring`, IOCP) — submit operations, get told when they're *done*; the modern high-throughput model that amortizes syscalls (`io_uring` batches submissions and completions, slashing boundary crossings).
- **Zero-copy** (`sendfile`, `splice`, memory-mapped I/O) — avoid copying data through user space when you're just shuttling bytes (file → socket). Saves CPU and memory bandwidth on data-heavy paths.

## Systems review checklist

- Every allocation checked for failure; every resource (memory, fd, lock, mmap) freed exactly once on **every** path including errors?
- Ownership unambiguous — RAII / Rust ownership / `goto cleanup`, not hand-tracked frees across branches?
- Every copy into a buffer bounded by the buffer; no `strcpy`/`gets`/unbounded `sprintf`; lengths from outside never trusted?
- Sanitizers (ASan/UBSan) and Valgrind in CI; strict warnings on and clean?
- Hot paths cache-conscious (sequential/contiguous access, locality, no false sharing on parallel hot data)?
- Syscalls batched/buffered, return values checked, `EINTR`/`EAGAIN` handled, blocking calls kept off event loops?
- Kernel/driver code validates all user-space pointers/lengths and uses safe copy accessors?
- No undefined behavior; fixed-width types for wire/disk formats; nothing read before initialization?
