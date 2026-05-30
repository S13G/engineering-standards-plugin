# Engineering Standards

**A thorough, cross-domain software engineering standard for AI coding agents.** Works with Claude Code, Codex, Cursor, Gemini CLI, Aider, and any agent that reads an instructions file.

It encodes the canon of software engineering — SOLID, Clean Code, *Designing Data-Intensive Applications*, *A Philosophy of Software Design*, *97 Things Every Software Architect Should Know*, *Release It!*, 12-Factor, OWASP, CAP, and battle-tested practice — as **enforceable, language-agnostic rules** the agent applies silently to everything it writes, reviews, and designs.

One lean always-on core (the universal laws) plus on-demand deep-dives for each domain — so it stays lightweight no matter how large the standard grows.

---

## What it covers

| Domain | Reference file |
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

The full standard lives in [`AGENTS.md`](AGENTS.md) (the universal laws, agent-neutral) plus the 13 domain files under [`skills/engineering-standards/reference/`](skills/engineering-standards/reference/).

---

## Install

Pick your agent. Every path uses the **same content** — [`AGENTS.md`](AGENTS.md) and the `reference/` files; only the entry point differs per agent.

The simplest universal method is to **copy this repo's files into your project** (or vendor the whole repo), so the agent finds its instructions file at the root:

```bash
# from your project root
git clone https://github.com/S13G/engineering-standards-plugin
cp -R engineering-standards-plugin/AGENTS.md \
      engineering-standards-plugin/CLAUDE.md \
      engineering-standards-plugin/GEMINI.md \
      engineering-standards-plugin/.cursorrules \
      engineering-standards-plugin/skills .
```

Then per agent:

| Agent | Entry point | Setup |
|---|---|---|
| **Codex** | `AGENTS.md` | Read automatically. Just have `AGENTS.md` + `skills/` in the project. |
| **Cursor** | `.cursorrules` | Read automatically once present in the project root. |
| **Gemini CLI** | `GEMINI.md` | Read automatically; it points to `AGENTS.md`. |
| **Aider** | `AGENTS.md` | Run with `aider --read AGENTS.md`. |
| **Claude Code** | plugin *(recommended)* or `CLAUDE.md` | See below — the plugin adds automatic, progressive loading. |
| **Any other** | `AGENTS.md` | Include it in the agent's context and ensure it can open `reference/*.md` on demand. |

> Each root file (`CLAUDE.md`, `GEMINI.md`, `.cursorrules`) is a thin pointer to the single source of truth, `AGENTS.md` — edit `AGENTS.md` and every agent stays in sync.

### Claude Code — install as a plugin (best experience)

Claude Code can load this as a true skill with **progressive disclosure** — it triggers itself on coding tasks and pulls in only the relevant domain file (no manual file copying):

/plugin marketplace add https://github.com/S13G/engineering-standards-plugin
/plugin install engineering-standards@engineering-standards-marketplace

> If you've already set up SSH access to GitHub on your machine, the shorthand `S13G/engineering-standards-plugin` also works in place of the full HTTPS URL.To make it an always-on default across every workspace, also reference it from your global `~/.claude/CLAUDE.md`.

---

## How it loads (and why it won't eat your context window)

The standard is built for **progressive disclosure** — it does *not* dump everything into context at once:

- **Always present:** just the entry pointer / skill description (~150 tokens).
- **When a coding task is in play:** the core universal laws load (~3k tokens).
- **Only when relevant:** the agent opens a *single* domain reference file (~1.5–3k tokens each).

A typical backend task costs roughly **5–6k tokens total** — a few percent of a 200k context window. The per-domain split means writing a database migration never loads the mobile or kernel docs.

On Claude Code this happens automatically via the skill engine. On other agents, the agent reads `AGENTS.md` (the laws) up front and opens a `reference/<domain>.md` file when the task calls for it — same lightweight, load-on-demand behavior, as long as the agent can read files.

---

## Structure

```
engineering-standards-plugin/
├── AGENTS.md                 # source of truth: universal laws + review gate (agent-neutral)
├── CLAUDE.md                 # pointer → AGENTS.md (Claude Code fallback)
├── GEMINI.md                 # pointer → AGENTS.md (Gemini CLI)
├── .cursorrules              # pointer → AGENTS.md (Cursor)
├── .claude-plugin/
│   ├── plugin.json           # Claude Code plugin manifest
│   └── marketplace.json      # Claude Code marketplace entry
└── skills/
    └── engineering-standards/
        ├── SKILL.md          # Claude Code skill core (laws + auto-routing)
        └── reference/        # 13 on-demand per-domain deep-dives (shared by all agents)
```

`AGENTS.md` and `skills/engineering-standards/SKILL.md` carry the same universal laws; both route to the same `reference/` files. Keeping the laws in two entry files (one agent-neutral, one Claude-skill) is the small, deliberate cost of supporting every agent — the 13 domain references are shared, never duplicated.

---

## License

MIT — see [LICENSE](LICENSE). Contributions and new domain references welcome.
