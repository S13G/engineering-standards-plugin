# Cloud, Distributed Systems & Operability

Deploying and running software that survives real infrastructure: instances die, networks partition, dependencies fail, load spikes. Draws on the *Twelve-Factor App*, *Designing Data-Intensive Applications* (Kleppmann), *Release It!* (Nygard), and SRE practice. For in-process coordination see `concurrency.md`; for data see `data.md`.

The governing assumption: **everything fails, all the time.** Design for failure as the normal case, not the exception.

---

## Twelve-Factor essentials (the ones that bite hardest)

- **Config in the environment, not the code.** Anything that differs between dev/staging/prod — URLs, credentials, toggles — comes from env vars or a secrets manager. Never commit it (`security.md`). One build artifact runs in every environment; only config changes.
- **Backing services are attached resources.** A database, queue, or cache is a URL you can swap without code changes. No hard-coded hosts.
- **Strict separation of build, release, run.** Build once, produce an immutable artifact, promote that *same* artifact through environments. Never build per-environment — "works in staging, breaks in prod" usually means a different artifact ran.
- **Processes are stateless and disposable.** Keep no session or user data in process memory or local disk; it vanishes when the instance is replaced (which is constant). Persist state in a backing service. This is what makes horizontal scaling and zero-downtime deploys possible.
- **Logs are an event stream** to stdout/stderr, structured (JSON) — not files the app manages. The platform aggregates them.
- **Fast startup, graceful shutdown.** On `SIGTERM`: stop taking new work, finish in-flight requests, release resources, exit. Slow or dirty shutdown drops requests on every deploy and scale-down.

---

## Scaling

- **Scale horizontally (more instances), not vertically (a bigger box).** Horizontal scaling needs stateless processes (above) and gives you redundancy for free — but only if no instance is special.
- **Statelessness is the enabler.** The moment an instance holds state another can't see, you've lost easy scaling, easy deploys, and easy failover.
- **Know your bottleneck before scaling** (Amdahl's Law). Adding app instances does nothing if the database is the limit — you just add clients hammering the same constraint. Measure, then scale the actual bottleneck.
- **Async-decouple with queues.** Work that needn't be synchronous (email, thumbnails, exports, webhooks) goes on a queue with idempotent, retrying consumers (`backend.md`). This absorbs spikes and isolates failures.
- **Autoscale on the right signal** (queue depth, p99 latency, CPU) — and cap it, so a runaway loop or attack can't scale you into a huge bill.

---

## Resilience — stop one failure becoming all failures

A dependency *will* be slow or down. Without guards, one slow dependency exhausts your threads/connections and your whole service falls over — a **cascading failure**.

- **Timeouts on every remote call.** No timeout means a hung dependency hangs *you* indefinitely. There is no acceptable default of "wait forever."
- **Retries with exponential backoff + jitter** — for *idempotent* operations only. Naive immediate retries turn a blip into a self-inflicted DDoS (a "retry storm"); jitter de-synchronizes clients so they don't all retry in lockstep.
- **Circuit breakers.** After N consecutive failures, stop calling the dead dependency for a cooldown and fail fast — give it room to recover instead of piling on. (Nygard's *Release It!*.)
- **Bulkheads.** Isolate resource pools so one saturated dependency can't consume every thread/connection and sink unrelated features. Compartmentalize like a ship's hull.
- **Graceful degradation.** When a non-critical dependency is down, serve a reduced experience (cached/default data, a hidden feature) rather than a hard error. Decide per feature what "degraded" looks like.
- **Health checks** that reflect real readiness (can I reach my DB?), so the orchestrator routes traffic only to instances that can actually serve — and a liveness check that restarts a wedged instance.

```
# Every outbound call, defensively wrapped
response = http.get(url,
    timeout = 2s,                                  # never wait forever
    retry   = backoff(max=3, base=100ms, jitter=true),  # idempotent calls only
    breaker = circuit(threshold=5, cooldown=30s))  # stop hammering a dead dep
```

---

## Deployment safety

- **Zero-downtime rollouts** (rolling/blue-green/canary): new and old versions run simultaneously during a deploy — so every change must be **backward-compatible** with the version it's replacing (this is exactly why schema changes use expand/contract, `data.md`).
- **Canary releases**: ship to a small slice first, watch error rate and latency, then widen. Catch the bad deploy at 1% of traffic, not 100%.
- **Fast, safe rollback.** The most reliable recovery is reverting to the last good artifact. Keep rollback one command away and always available.
- **Decouple deploy from release.** Ship code dark behind a feature flag, then turn it on independently — separating "is it deployed" from "is it live" shrinks blast radius.

---

## Observability — you can't fix what you can't see

You need to answer "what's wrong, right now, in production" without redeploying. Three pillars:

- **Logs** — structured, with a **correlation/trace ID** threaded through every service so one request is followable end-to-end. Unstructured logs you can't query are nearly useless at scale. Never log secrets/PII (`security.md`).
- **Metrics** — rates, errors, durations (the RED method), and resource saturation (the USE method). Track **p99, not averages** — the average hides the user who waited 8 seconds.
- **Traces** — the path and timing of a request across services, so you can see *where* latency and failures actually originate in a distributed call graph.

**Alert on user-facing symptoms** (error rate up, latency up, queue backing up — your SLOs), not on causes (CPU at 80% may be perfectly fine). Page humans only for things that need a human now; everything else is a dashboard or a ticket.

---

## The fallacies of distributed computing (Deutsch & Gosling)

Every distributed bug traces back to assuming one of these is true. They are all false:

1. The network is reliable · 2. Latency is zero · 3. Bandwidth is infinite · 4. The network is secure · 5. Topology doesn't change · 6. There is one administrator · 7. Transport cost is zero · 8. The network is homogeneous.

Design as if every remote call can be slow, dropped, duplicated, eavesdropped, or reordered — because it can. This is *why* you need timeouts, retries, idempotency, encryption in transit, and service discovery rather than hard-coded hosts.

- **CAP** under partition: choose consistency or availability per workflow, deliberately (`concurrency.md`, `data.md`).
- **Idempotency everywhere**, because at-least-once delivery means everything is retried (`backend.md`).
- **No distributed transactions across services** by default — two-phase commit is brittle and doesn't scale. Prefer **sagas**: a sequence of local transactions, each with a **compensating action** to undo it if a later step fails (refund the charge, release the reservation). You trade atomicity for availability and design the rollback explicitly.

## Infrastructure as Code & immutable infrastructure

- **Infrastructure is code, in version control** (Terraform, Pulumi, CloudFormation). No clicking in a console to create production — that's unrepeatable, undocumented, and undiffable. IaC makes environments reproducible, reviewable (PRs for infra), and recoverable.
- **Immutable infrastructure.** Don't patch running servers in place (config drift makes every box a unique snowflake nobody can reproduce). Build a new image, deploy it, destroy the old one. Servers are cattle, not pets — replaceable and identical.
- **Containers + orchestration** (Docker/Kubernetes) give you that immutability and consistent dev-to-prod parity — at the cost of real operational complexity. Adopt the complexity when you have the scale/team to need it, not as a default for a small service.

## Cost is an engineering constraint

Cloud spend is a non-functional requirement — an inefficient architecture shows up on the bill, and runaway scaling can bankrupt before it pages.

- **Cap autoscaling** so a bug or attack can't scale you into a five-figure surprise. Set budget alerts.
- **Right-size**; turn off idle non-prod environments; use spot/preemptible instances for fault-tolerant batch work. Mind egress (data *leaving* the cloud is the sneaky cost). Serverless is cheap at low/spiky traffic and expensive at sustained high traffic — model it.
- **Efficiency is shared with performance and sustainability:** the same wasteful query or chatty service that's slow also costs money and energy. Measure cost per request like you measure latency.

## Multi-region & disaster recovery

- **Multi-AZ for availability** (survive a datacenter failure) is table stakes for anything important; **multi-region** (survive a whole region) is a deliberate, expensive choice driven by latency-to-users or strict availability/compliance needs.
- **Define RPO and RTO explicitly** — how much data you can afford to lose (Recovery Point) and how long recovery may take (Recovery Time). They drive backup frequency and failover design.
- **Test your backups and failover.** An untested backup is Schrödinger's backup — you don't know if it works until you restore from it, and the worst time to find out is during a real outage. Run game-days/restore drills.

---

## Cloud / ops review checklist

- Config and secrets from the environment, never committed; one immutable artifact promoted across environments?
- Processes stateless and disposable; state in backing services; graceful `SIGTERM` shutdown?
- Every outbound call has a timeout; retries use backoff+jitter and only on idempotent ops; circuit breakers and bulkheads guard against cascades?
- Non-critical dependency failures degrade gracefully instead of hard-failing?
- Deploys backward-compatible and zero-downtime; canaried; one-command rollback ready; risky changes behind flags?
- Structured logs with a trace ID; RED/USE metrics on p99; alerts on user-facing symptoms and SLOs, not raw causes?
- Cross-service consistency handled by idempotency + sagas, not distributed transactions; scaling targets the measured bottleneck?
