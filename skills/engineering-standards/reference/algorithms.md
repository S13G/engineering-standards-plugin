# Algorithms, Data Structures & Complexity

The mathematician's layer: choosing the right data structure, reasoning about cost honestly, and knowing when the textbook answer is wrong on real hardware. Most "slow code" is not a slow algorithm — it's the *wrong data structure* for the access pattern, or an accidental quadratic nobody measured. Draws on Knuth (*TAOCP*), CLRS, Sedgewick, Skiena (*The Algorithm Design Manual*), and Bentley (*Programming Pearls*).

> "It's never too early to think about performance" (#13), but **"premature optimization is the root of all evil"** (Knuth). The resolution: think about *complexity and data structures* early (they're structural and hard to change), tune *constants* late and only with a profiler.

---

## Complexity analysis — but honest about what it hides

Big-O describes how cost **grows** with input size, ignoring constants. It's essential for spotting scalability cliffs and useless for predicting wall-clock time on a given input. Use it for what it's good at.

| Class | Name | Reality check |
|---|---|---|
| O(1) | constant | the goal for hot lookups |
| O(log n) | logarithmic | excellent — balanced trees, binary search, good index |
| O(n) | linear | usually fine — one pass |
| O(n log n) | linearithmic | the floor for comparison sorting; a good target for "process everything" |
| O(n²) | quadratic | the **silent killer** — fine at n=100, a frozen UI at n=10,000 |
| O(2ⁿ), O(n!) | exponential/factorial | only for tiny n; otherwise needs DP, pruning, or approximation |

- **Hunt accidental quadratics.** A loop inside a loop over the same data, a `.contains()` on a list inside a loop, string concatenation in a loop (often O(n²) from recopying), an N+1 query (`data.md`). These pass every small test and melt production. The classic fix: replace the inner linear scan with a hash set/map lookup → O(n²) becomes O(n).
- **Analyze the dominant term and the realistic n.** O(n²) on a list that's always ≤ 8 items is *fine* — don't add a hash map to "optimize" 8 elements (that's premature optimization and added complexity). Know your actual input size.
- **Amortized vs. worst case.** A dynamic array's append is O(1) *amortized* but O(n) on the resize; a hash map is O(1) average but O(n) on a pathological collision/resize. Know which one matters for your latency budget (a p99 spike often lives in the rare worst case).
- **Space counts too.** An O(n) memory algorithm that blows the cache or OOMs is worse than an O(n log n) one that streams. Time–space tradeoffs are real choices, not afterthoughts (`systems.md`).

---

## Data-structure selection — match the structure to the access pattern

The single highest-leverage performance decision. Pick by *how you'll access the data*, not by habit.

| Need | Reach for | Why |
|---|---|---|
| Membership / dedup / lookup by key | **Hash set/map** | O(1) average; turns scans into lookups |
| Ordered iteration + range queries + lookup | **Balanced tree / sorted structure** (B-tree, skip list) | O(log n) ops *and* order — why DB indexes are B-trees (`data.md`) |
| FIFO / work queue / BFS | **Queue** (ring buffer) | O(1) ends; backpressure-friendly |
| LIFO / undo / DFS / recursion-as-iteration | **Stack** | O(1), cache-friendly |
| Always-need-the-min/max (scheduling, top-K, Dijkstra) | **Heap / priority queue** | O(log n) push/pop, O(1) peek |
| Fast sequential scan / index access / tight memory | **Array / contiguous buffer** | cache-optimal; the default until proven otherwise (`systems.md`) |
| Frequent insert/delete in the *middle* | **Linked list** — *rarely* | O(1) splice, but terrible locality; usually an array still wins |
| Prefix/autocomplete/routing | **Trie / radix tree** | shares prefixes; what IP routers and routers-in-code use |
| Approximate membership at huge scale | **Bloom filter** | O(1), tiny memory, "definitely not / maybe yes" |
| Disjoint groups / connectivity | **Union-Find** | near-O(1) merge & query |

**Default to an array/contiguous structure** and move only when the access pattern demands otherwise — contiguous memory beats theoretically-better structures constantly because of cache locality (the Big-O-lies effect, `systems.md`). A linked list's O(1) insert is a trap if you traverse it: every hop is a cache miss.

---

## When Big-O lies — the hardware reality

Asymptotic analysis assumes uniform memory cost. Real memory is a hierarchy with a 100× gap between cache and RAM, so **constant factors and locality routinely dominate** for the input sizes you actually run.

- A "slower" O(n²) algorithm on a contiguous array can beat a "faster" O(n log n) one on a pointer-chasing structure for moderate n, because the first never misses cache and the second misses constantly.
- **Binary search on a sorted array** beats a balanced BST in practice for the same reason — same Big-O, vastly better locality.
- Linear scan of a small contiguous array beats a hash map for tiny n (no hashing, no pointer chase). This is why real sort implementations switch to insertion sort below a threshold.
- **Lesson:** Big-O picks the *structure and algorithm class*; the *profiler and cache analysis* pick the winner among comparable options. Never micro-optimize on Big-O alone, and never optimize at all without measuring (`SKILL.md` law #8).

---

## Algorithmic technique toolbox (recognize the shape)

You rarely invent algorithms; you recognize which known technique the problem fits.

- **Divide and conquer** — split, solve halves, combine (sort, search). Often the route from O(n²) to O(n log n).
- **Dynamic programming** — overlapping subproblems + optimal substructure; memoize to turn exponential into polynomial.
- **Greedy** — locally optimal choice; correct only when the problem has the greedy-choice property (prove it, or it's subtly wrong).
- **Hashing** — trade memory for O(1) lookup; the everyday workhorse for dedup, grouping, joins.
- **Two pointers / sliding window** — turn nested loops over a sequence into a single pass.
- **Binary search** — not just on arrays: binary-search the *answer* for any monotonic predicate.
- **Graph search (BFS/DFS, Dijkstra, topological sort)** — astonishingly many problems are graphs in disguise (dependencies, state machines, reachability).
- **Don't reinvent.** Use the standard library's sort, hash map, and proven algorithms. Hand-rolled sorts and "clever" custom structures are a reliable source of subtle bugs (**#80 Don't be clever**). Reach for a custom algorithm only when profiling proves the standard one is the bottleneck.

---

## Numerical and correctness care (the math hygiene)

- **Floating point is not real numbers.** `0.1 + 0.2 ≠ 0.3`. Never test floats with `==` (use a tolerance); never store money as float — integer minor units or fixed decimal (`data.md`).
- **Integer overflow is real.** `(low + high)` in a binary search can overflow — a bug that hid in the JDK's `binarySearch` for years; use `low + (high - low) / 2`. Know your type's range.
- **Off-by-one lives at boundaries.** Half-open ranges `[start, end)` prevent most of them; be consistent. Test n=0, 1, max (`testing.md`).
- **Randomness:** a normal PRNG is fine for simulation and not for security — security needs a CSPRNG (`security.md`). Seed PRNGs in tests for determinism.

---

## Algorithms review checklist

- Is there an accidental quadratic (nested scan, `contains` in a loop, concat in a loop, N+1) that an index/hash map removes?
- Is the data structure chosen for the actual access pattern (lookup→hash, range/order→tree, min/max→heap, scan→array)?
- Is the realistic input size known, so we neither ship an O(n²) cliff nor over-engineer tiny n?
- For the hot path, was the winner chosen by measurement (cache/locality), not Big-O alone — contiguous by default?
- Is a standard-library implementation used instead of a hand-rolled sort/structure unless profiling demands otherwise?
- Floats never `==`-compared and never used for money; integer overflow considered; ranges half-open and boundaries tested?
- Amortized vs. worst-case understood where p99 latency matters?
