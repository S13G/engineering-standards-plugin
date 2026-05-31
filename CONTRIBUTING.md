# Contributing

Thanks for helping improve this engineering standard. The goal is a thorough, agent-neutral, canon-grounded set of rules that any AI coding agent applies silently. Contributions that sharpen the rules, fix inaccuracies, or add a missing domain are all welcome.

## How the standard is organized

```
AGENTS.md                              # source of truth: the universal laws + review gate (agent-neutral)
CLAUDE.md / GEMINI.md / .cursorrules   # thin per-agent pointers → AGENTS.md (keep them thin)
skills/engineering-standards/
├── SKILL.md                           # Claude Code skill core: same laws + the routing table
└── reference/<domain>.md              # 14 on-demand per-domain deep-dives (shared by every agent)
```

Two things carry the **universal laws**: `AGENTS.md` (for all agents) and `skills/engineering-standards/SKILL.md` (the Claude Code skill). They must stay in sync. The 14 `reference/` files are shared — never duplicated per agent.

## The two rules that keep this consistent

1. **Edit the laws in both places, or neither.** If you change a Universal Law or the Review Gate, make the identical change in `AGENTS.md` **and** `skills/engineering-standards/SKILL.md`. A PR that updates one but not the other will be asked to fix it.
2. **Add a domain by adding a file *and* a routing row.** A new `reference/<domain>.md` must also be listed in the routing table in **both** `SKILL.md` and `AGENTS.md`, or no agent will know to load it.

## Style for reference files

Each `reference/<domain>.md` should:

- **State principles language-agnostically**, then illustrate with whatever language shows the idea most clearly (Go for concurrency, C for systems/memory, SQL for data, TS for frontend, Dart/Kotlin/Swift for mobile). Don't make one language dominate the whole file.
- **Cite the canon where it adds weight** — SOLID, DDIA, *A Philosophy of Software Design*, *Release It!*, *97 Things Every Software Architect Should Know* (cite axioms by `#n`), OWASP, etc. — but keep every point actionable, not academic. A rule the reader can apply beats a reference they can't.
- **Cross-link** related domains with the `reference/<other>.md` convention already used throughout.
- **End with a review checklist** of the domain's must-pass questions, matching the existing files' format.
- Follow the standard's own rules: clear, simple, no filler. If a section restates what's obvious, cut it.

## Submitting a change

1. Fork and branch (`git switch -c improve-<area>`). Keep branches short-lived.
2. **Atomic commits**, present-tense subject, Conventional Commits prefix (`feat:`, `fix:`, `docs:`, `refactor:`). Explain *why* in the body when it isn't obvious. One concern per commit.
3. Keep PRs small and single-purpose — a focused 80-line PR gets a real review; a 2,000-line one gets rubber-stamped. Split aggressively.
4. In the PR description, say what changed and why, and confirm you synced the laws across both entry files (rule 1) if you touched them.

## What gets accepted

- Corrections to anything factually wrong or outdated.
- Sharper, shorter phrasing of an existing rule.
- A new domain reference that fills a real gap (with its routing rows).
- Better or more representative examples.

## What won't

- Personal style preferences dressed up as rules (prefer principles to taste).
- Framework- or vendor-specific advice that doesn't generalize (keep it language- and tool-agnostic unless the file is explicitly about that tool).
- Bloat — length for its own sake. The progressive-disclosure design only works if each file stays focused.

By contributing, you agree your contributions are licensed under the repository's [MIT License](LICENSE).
