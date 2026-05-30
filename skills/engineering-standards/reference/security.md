# Security Engineering

Security is not a feature you add; it is a property of the whole system, enforced at every layer. The mindset: **assume hostile input, a breached perimeter, and a motivated attacker** — then make a mistake's blast radius small by construction. Anchored on the OWASP Top 10, *least privilege*, and *defense in depth*. Cross-refs: input/SQL in `data.md`, transport/secrets-in-config in `cloud.md`, memory-safety exploits in `systems.md`.

---

## The two foundational principles

**Least privilege.** Every actor — code, process, credential, token, DB user, network path — gets the *minimum* access to do its job, and no more. The app's DB user can't `DROP`. The service token can't reach unrelated services. The function can't see secrets it doesn't use. When something is compromised (and eventually something is), least privilege is what bounds the damage.

**Defense in depth.** No single control is trusted to be perfect. Layer them: validate at the boundary *and* parameterize the query *and* constrain the database. Each layer assumes the one before it might have failed. A single missed check shouldn't mean game over.

---

## Never trust input — validate at every boundary

Every byte from outside your trust boundary is hostile until proven otherwise: user forms, URLs, headers, file uploads, API responses from other services, queue messages, even the system clock.

- **Validate on the server, always** — even if the client already validated. Client checks are UX; the server is the authority (`frontend.md`). An attacker skips your UI entirely.
- **Allowlist, don't blocklist.** Define what's *valid* and reject the rest. Blocklists of "bad" patterns are always incomplete — attackers find the case you didn't think of.
- **Validate type, range, length, and format** — then treat the value as known-good past the boundary.

### Injection — the perennial #1 risk

Injection happens whenever untrusted input is interpreted as *code/commands* by some downstream interpreter (SQL, shell, HTML, LDAP, the OS). The universal fix: **never concatenate input into a command string; separate code from data.**

- **SQL** → parameterized queries / prepared statements, *always*. Never string-build SQL (`data.md`).
- **OS commands** → avoid shelling out; if you must, pass an argument array (no shell string), never interpolate input.
- **HTML/JS (XSS)** → context-aware output **encoding**, and a Content-Security-Policy as the second layer. Treat all user content as untrusted on render.
- **Templates/LDAP/XML** → the same rule — use the safe, parameterized API, never string assembly.

```
// BAD — string-built query: classic SQL injection
query("SELECT * FROM users WHERE email = '" + input + "'")

// GOOD — parameterized: the driver sends code and data separately; input can't be code
query("SELECT * FROM users WHERE email = $1", [input])
```

---

## Authentication vs. authorization — never conflate them

- **Authentication** = *who are you* (proving identity). **Authorization** = *what may you do* (checking permission). They are different checks at different moments.
- **Authorize every action against the actor**, server-side, every time. The #1 web vulnerability class (OWASP **Broken Access Control**) is forgetting to check that *this* user owns *this* resource. Knowing a record's ID must never be enough to access it.

```
// BAD — IDOR: any logged-in user can read anyone's invoice by guessing an id
getInvoice(id) = db.invoices.find(id)

// GOOD — ownership enforced on every access
getInvoice(id, actor) = db.invoices.find_owned_by(id, actor.id) ?? deny(404)
```

- **Sessions/tokens**: short-lived, rotated, revocable. Store session cookies `HttpOnly` + `Secure` + `SameSite`. For JWTs, verify signature and expiry on every request and keep them short-lived (you can't un-issue a long one).
- **Passwords**: never store plaintext or a plain hash. Use a slow, salted KDF built for it — **bcrypt / scrypt / Argon2** — never `md5`/`sha256` of a password. Enforce rate limits and lockout on auth endpoints (`backend.md`).
- **Don't leak existence.** Login, password-reset, and invite flows return the *same* response whether or not the account exists — otherwise you've built an account-enumeration oracle.

---

## Secrets and cryptography — don't roll your own

- **Secrets never touch the codebase.** No keys, passwords, or tokens in source, commits, or config files — env vars or a secrets manager (`cloud.md`). A secret in git history is compromised permanently; rotate it the moment it lands there.
- **Never log secrets, tokens, passwords, full card numbers (PAN), or PII.** Logs are widely readable and kept forever. Redact at the boundary.
- **Store sensitive tokens as a hash/digest**, compare by hash; the plaintext exists only in transit to the user (`backend.md`).
- **Don't invent crypto.** Use vetted, standard libraries and algorithms; a hand-rolled cipher or a misused primitive is a guaranteed hole. Prefer high-level, misuse-resistant APIs (libsodium, the platform's AEAD) over assembling primitives yourself.
- **Encrypt in transit (TLS) and at rest** for sensitive data. Verify certificates; don't disable verification "to make it work."
- **Use cryptographic randomness** for anything security-bearing — tokens, salts, IDs. A regular PRNG is predictable; use the CSPRNG (`/dev/urandom`, `crypto.randomBytes`, `SecureRandom`). Never a timestamp or a sequential counter for a secret token.

---

## Supply chain and the broader surface

- **Dependencies are attack surface.** Pin versions, audit them (`npm audit`, `pip-audit`, Dependabot/Snyk), and update known-vulnerable ones promptly. Most breaches ride in through a stale dependency, not novel code.
- **Vendor deliberately.** A typo-squatted or abandoned package is a backdoor. Review what you add; fewer dependencies is a smaller surface.
- **Set security headers** on web responses: `Content-Security-Policy`, `Strict-Transport-Security`, `X-Content-Type-Options`, frame options. Cheap, high-value layers.
- **Rate-limit and throttle** auth, expensive, and abusable endpoints to blunt brute-force and DoS (`backend.md`).
- **Fail closed, not open.** When an authz/security check errors, deny — never default to allowing through because the check threw.
- **Don't leak in errors.** User-facing errors are generic; stack traces, SQL, and internal detail stay in the logs, never in the response.

---

## Threat modeling — think like the attacker, on purpose

Before building anything sensitive, spend an hour asking *how would I break this?* A structured pass beats hoping.

- **STRIDE** is a practical checklist of threat categories: **S**poofing (pretend to be someone), **T**ampering (alter data), **R**epudiation (deny doing it), **I**nformation disclosure (leak data), **D**enial of service, **E**levation of privilege. Walk each component against each letter.
- **Map trust boundaries and the attack surface.** Every place data crosses from less-trusted to more-trusted (user→server, service→service, internet→internal) is a boundary that needs validation and authz. Draw them; the boundaries are where you focus.
- **Assume breach.** Design so that compromising one component doesn't cascade (least privilege + defense in depth). What can an attacker reach *after* they're past the first wall? Minimize it.
- **Abuse cases alongside use cases.** For every "user transfers money," ask "attacker transfers *someone else's* money / replays the request / floods the endpoint." Build the defense as a requirement, not a patch.

## Know the OWASP Top 10 — the bugs that actually get exploited

The current categories, condensed — most real breaches are one of these, not exotic:

1. **Broken Access Control** — the #1 risk; the IDOR/missing-authz failures above. Check ownership on *every* access.
2. **Cryptographic Failures** — weak/missing crypto, secrets in the clear, plaintext transit. Use TLS, vetted libs, proper KDFs.
3. **Injection** — SQL/command/XSS, covered above. Parameterize and encode.
4. **Insecure Design** — the flaw is in the architecture, not a bug (no threat model, no rate limit by design). Threat-model early.
5. **Security Misconfiguration** — default creds, verbose errors, open buckets, missing headers, debug on in prod.
6. **Vulnerable & Outdated Components** — the supply-chain risk; patch and audit dependencies.
7. **Identification & Authentication Failures** — weak passwords, broken sessions, no brute-force protection.
8. **Software & Data Integrity Failures** — trusting unsigned updates/CI artifacts, insecure deserialization.
9. **Logging & Monitoring Failures** — you can't detect or investigate a breach you didn't log (without logging secrets, `cloud.md`).
10. **SSRF** — see below.

### The specific attacks to design against

- **CSRF** (cross-site request forgery) — a malicious site makes the user's browser send an authenticated request to your app. Defend with anti-CSRF tokens (or `SameSite` cookies) on state-changing requests.
- **SSRF** (server-side request forgery) — an attacker tricks *your server* into making requests to internal systems (cloud metadata endpoints, internal services) by controlling a URL you fetch. Defend by validating/allowlisting outbound targets and blocking internal IP ranges; never fetch an arbitrary user-supplied URL.
- **Insecure deserialization** — deserializing untrusted data into objects can execute code. Don't deserialize untrusted input into rich types; use data-only formats (JSON) with schema validation.
- **Mass assignment** — binding request params straight onto a model lets an attacker set fields they shouldn't (`is_admin=true`). Use explicit allowlists of bindable fields.
- **Open redirect** — redirecting to a user-supplied URL enables phishing. Allowlist redirect targets.

## Security is a lifecycle, not a gate (DevSecOps)

Security bolted on at the end is the most expensive and least effective kind. Build it in:

- **Shift left**: threat-model in design, review security in code review, automate checks in CI — **SAST** (static analysis), **dependency/SCA scanning**, **secret scanning** (block commits containing keys), and **DAST** against staging. Catch issues before prod.
- **Principle of least privilege in CI/CD too**: the pipeline's credentials are a juicy target — scope them tightly, rotate them, never print them in logs.
- **Patch promptly**: a known CVE in a dependency is an open door (`cloud.md`). Automate the boring updates.
- **Have an incident plan**: detection (logging/alerting), response, and rotation-of-everything-compromised, decided *before* you need it.

## Security review checklist

- All external input validated server-side with an allowlist; treated as hostile until proven valid?
- Every interpreter call parameterized/encoded — SQL, shell (arg array), HTML output, templates — with no string-built commands?
- Every action authorized against the actor server-side; ownership checked so an ID alone never grants access (no IDOR)?
- Passwords via bcrypt/scrypt/Argon2; sessions/tokens short-lived, rotated, revocable; cookies `HttpOnly`+`Secure`+`SameSite`?
- Auth/reset/invite flows don't reveal whether an account exists; auth endpoints rate-limited?
- No secrets in code/commits/logs; sensitive tokens stored as digests; standard crypto libs only; CSPRNG for security values?
- TLS in transit, sensitive data encrypted at rest, cert verification on?
- Dependencies pinned and audited; security headers set; checks **fail closed**; errors don't leak internals?
