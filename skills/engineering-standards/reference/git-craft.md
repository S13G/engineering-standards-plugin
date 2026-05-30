# Version Control & Collaboration Craft

How you commit, branch, review, and integrate is engineering — it determines whether the team can move fast without breaking each other. Sloppy history and big-bang merges cost more than most bugs. Draws on *97 Things* (#15 "Commit-and-run is a crime", #20 "Continuously Integrate"), the Conventional Commits spec, and trunk-based development / *Accelerate* (DORA) research.

---

## Commits: atomic, complete, and explained

A commit is a unit of change another human (and `git bisect`, and `git revert`) will work with for years. Make each one a clean, self-contained step.

- **Atomic.** One logical change per commit. Not "fixed bug and refactored and reformatted" — three commits. An atomic commit can be reverted, cherry-picked, and reviewed on its own.
- **Complete and green.** Every commit should build and pass tests. A commit that "doesn't work yet, see next commit" breaks `bisect` and rollback — the two tools you most need when production is on fire.
- **Separate refactor from behavior change.** A commit that *moves/renames* code (no behavior change) and a commit that *changes behavior* must be different commits. Mixing them makes review impossible — the reviewer can't tell the 3 meaningful lines from the 300 moved ones.
- **No commit-and-run (#15).** Don't push a change that breaks the build or others' work and walk away. You broke it; you stay until it's green. Breaking the shared trunk and leaving is, as the book puts it, a crime against the team.

### Commit messages: the *why* is the payload

Code shows *what* changed; the diff shows *how*. The message must carry **why** — the context that's invisible in the code and gone from everyone's memory in a month.

```
feat(auth): rate-limit login to 5 attempts per 15 min

Brute-force attempts were hitting the login endpoint unthrottled,
making credential-stuffing cheap. Cap per-IP attempts and return 429
with Retry-After so legitimate users get a clear signal.

Closes #482
```

- **Subject ≤ ~50 chars, imperative mood** ("add", not "added"/"adds") — it completes "If applied, this commit will ___". Conventional Commits prefix (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`) makes history scannable and changelogs automatable.
- **Body explains the why and the tradeoff**, wrapped ~72 cols — only when it isn't obvious from the subject. Link the issue.
- **Never** `"fix"`, `"wip"`, `"stuff"`, `"asdf"`. That message is a debt the next person on `git blame` pays.

---

## Branching: optimize for fast, safe integration

> "Continuously Integrate." (**#20**) The longer code lives unmerged, the more painful and risky the eventual merge — integration debt compounds exactly like technical debt.

- **Short-lived branches, merged often.** Trunk-based development (small branches, merged to main within a day or so behind tests) consistently outperforms long-lived feature branches in the DORA/*Accelerate* research — fewer merge conflicts, faster feedback, smaller blast radius.
- **Long-lived branches rot.** A branch open for three weeks diverges from a trunk that moved under it; the merge becomes an archaeology project and a conflict minefield. If a feature is big, **don't hold it on a branch — land it incrementally behind a feature flag** (`cloud.md`), dark until complete.
- **Keep main always releasable.** main is sacred: it builds, it passes, it could ship right now. Protect it (required checks, required review, no force-push).
- **Rebase your local work to keep history linear and clean; never rewrite shared/public history.** Force-pushing a branch others have pulled rewrites their reality. Rebase before you share, merge after.

---

## Pull requests: small, focused, reviewable

- **Small PRs get good reviews; big PRs get rubber-stamped.** A 50-line PR gets real scrutiny; a 2000-line PR gets "LGTM" because no human can hold it. Review quality falls off a cliff past a few hundred lines. Split aggressively.
- **One concern per PR.** A reviewer should be able to state what it does in one sentence. "Refactor + feature + dependency bump" is three PRs.
- **The PR description does the reviewer's onboarding:** what, why, how to test, what to watch for. Don't make them reverse-engineer intent from the diff.
- **Self-review first.** Read your own diff before requesting review — you'll catch the debug print, the commented-out block, the leftover TODO. Wasting a reviewer's time on what you'd have caught yourself is rude and slow.

---

## Code review: improve the code, respect the human

Review is the highest-bandwidth knowledge-sharing and the cheapest place to catch bugs — but only if done well.

- **Review against the standard, not your personal taste.** Correctness, clarity, the universal laws (`SKILL.md`), the domain checklists. **#59: prefer principles to opinion** — "I'd have done it differently" is not a review comment; "this can deadlock because the locks aren't ordered" is.
- **Be specific and kind.** Comment on the code, never the person. Explain the *why* and suggest the fix: "this query is N+1 — preload `account` to avoid a query per row" beats "this is slow." Phrase as a question when unsure.
- **Distinguish blocking from optional.** Tag nits ("nit: naming") vs. must-fix ("blocking: missing authz check") so the author knows what gates the merge. Don't hold a PR hostage over a preference.
- **As the author, don't take it personally.** The review critiques the code; "egoless programming" — your self-worth isn't the diff. Push back with reasoning when you disagree; concede fast when you're wrong.
- **Reviewing teaches both sides.** The reviewer learns the change; the author learns the standard. **#54: Share your knowledge.** Reuse and quality spread through review, not mandates (#26).

---

## Integration hygiene

- **Pull/rebase before you push.** Integrate others' work into yours continuously, not in one terrifying merge at the end.
- **CI is the gate, not a suggestion** (`testing.md`): every PR runs the full suite; **red blocks merge**, no exceptions, no "merge now fix later."
- **Conflicts are resolved by the person who created the divergence** — understand both sides before resolving; a blind "accept theirs" silently drops someone's work.
- **`.gitignore` build artifacts, secrets, and local config.** A committed secret is compromised forever (rotate it immediately — `security.md`); a committed `node_modules`/build dir is noise that poisons every diff.

---

## Git-craft review checklist

- Is each commit atomic, building, green, and separated into refactor-vs-behavior?
- Do commit messages explain *why* (imperative subject ≤50, Conventional Commits prefix, body for the non-obvious), with no "wip/fix/stuff"?
- Are branches short-lived and merged continuously; big features landed incrementally behind flags, not held on long branches?
- Is main always releasable and protected; is shared history never force-rewritten?
- Is the PR small, single-concern, self-reviewed, with a description that gives the reviewer what/why/how-to-test?
- Does review target the standard (not taste), stay specific and kind, mark blocking vs. nit?
- Does CI gate every merge (red blocks), and are secrets/artifacts gitignored?
