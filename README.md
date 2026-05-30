# Engineering Standards — a Claude Code plugin

A thorough, cross-domain software engineering standard for [Claude Code](https://claude.com/claude-code), packaged as a single installable skill.

It encodes the canon of software engineering — SOLID, Clean Code, *Designing Data-Intensive Applications*, *A Philosophy of Software Design*, *97 Things Every Software Architect Should Know*, *Release It!*, 12-Factor, OWASP, CAP, and battle-tested practice — as **enforceable, language-agnostic rules** Claude applies silently to everything it writes, reviews, and designs.

## What it covers

A lean always-on core (the universal laws) plus on-demand deep-dives for each domain:

| Domain | Reference |
|---|---|
| System design, tradeoffs, quality attributes, DDD, ADRs, technical debt | `architecture` |
| OOP / FP / procedural, immutability, pure functions, functional core | `paradigms` |
| Complexity analysis, data-structure choice, time/space tradeoffs | `algorithms` |
| Services, APIs, error handling, jobs, caching, rate limiting | `backend` |
| Schemas, transactions, locking, indexing, replication, store choice | `data` |
| Threads, async, races, memory models, backpressure, distributed coordination | `concurrency` |
| UI structure, state, rendering strategy, accessibility, Core Web Vitals | `frontend` |
| Flutter / Android / iOS, offline-first, lifecycle, release & signing | `mobile` |
| Deployment, scaling, resilience, observability, IaC, cost, multi-region | `cloud` |
| Memory, allocation, syscalls, cache, lock-free, NUMA, I/O models | `systems` |
| Input boundaries, authz, crypto, threat modeling, OWASP Top 10 | `security` |
| Test strategy, determinism, test doubles, property/load/chaos testing | `testing` |
| Commits, branching, pull requests, code review, continuous integration | `git-craft` |

## How it loads (and why it won't eat your context window)

The skill uses **progressive disclosure** — it does *not* dump everything into context:

- **Always present:** only the skill's one-line description (~150 tokens).
- **When a coding task triggers it:** the core `SKILL.md` loads (~3k tokens).
- **Only when relevant:** Claude reads a single domain reference file (~1.5–3k tokens each).

A typical backend task costs roughly **5–6k tokens total** — a few percent of a 200k window. The per-domain split means writing a database migration never loads the mobile or kernel docs.

## Install

```
# In Claude Code:
/plugin marketplace add S13G/engineering-standards-plugin
/plugin install engineering-standards@engineering-standards-marketplace
```

> Replace `S13G` with your GitHub username if the repo lives elsewhere.

Once installed, it triggers automatically on code generation, review, refactoring, and architecture work — no command needed. To make it an always-on default across every workspace, also reference it from your `~/.claude/CLAUDE.md`.

## Structure

```
engineering-standards-plugin/
├── .claude-plugin/
│   ├── plugin.json          # plugin manifest
│   └── marketplace.json     # marketplace entry
└── skills/
    └── engineering-standards/
        ├── SKILL.md         # always-on core: the universal laws + routing
        └── reference/       # 13 on-demand per-domain deep-dives
```

## License

MIT — see [LICENSE](LICENSE).
