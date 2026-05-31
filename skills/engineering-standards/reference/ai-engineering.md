# AI & LLM Engineering

Building with large language models adds a layer of managed non-determinism on top of every other engineering concern. The model is an external dependency with a probabilistic API — same input, different output; costs money per call; can be manipulated through its own inputs. Apply the same rigor as any unreliable external dependency, plus the controls this one uniquely requires. Draws on the OWASP LLM Top 10, Anthropic and OpenAI prompting guides, prompt-injection research (Simon Willison), and emerging LLM evaluation practice.

> "The model is not the product — the system around the model is." The value is in the scaffolding: the evals, the guardrails, the fallbacks, the observability.

---

## Non-determinism is the default — design around it

A function that returns different values for the same inputs is a bug everywhere else; in LLM engineering it is the operating condition.

- **Pin what you can.** Set `temperature=0` (or the minimum supported) for tasks that require consistent, verifiable output — classification, extraction, structured generation. Reserve higher temperatures for creative tasks where variance is the goal.
- **Seed random generation** where the API supports it — reproducible outputs make debugging tractable.
- **Never assert on exact output strings.** Tests must check *properties*: structure, required fields, format compliance, safety constraints — not brittle exact-match (`testing.md`). "The response contains a valid ISO 8601 date" is a test; "the response equals '2024-01-15'" is a fragile accident.
- **Treat every call as a distribution, not a value.** Evaluate with multiple samples where quality matters; a single pass hides variance that will surface in production.

```python
# BAD — asserts exact string; breaks on any model or prompt change
assert response == "The capital of France is Paris."

# GOOD — asserts structure and contract
assert response["city"] == "Paris"
assert response["confidence"] >= 0.9
assert "source" in response
```

---

## Prompts are code — version, review, and test them

A prompt is a program written in natural language. It has the same lifecycle obligations as code: version control, peer review, regression testing, and a single source of truth.

- **Prompts live in version control**, not in a database, a notebook, or a shared doc. Every change is diffable, attributable, and reversible.
- **Structure beats cleverness.** A prompt with explicit sections — role, task, constraints, output format, examples — is more reliable and easier to maintain than a "clever" one that depends on subtle phrasing. Write for the next engineer who will change it under pressure.
- **Separate system prompt from user content.** Never interpolate user-supplied input into the system prompt — that is the prompt injection path (below, `security.md`).
- **Few-shot examples are part of the prompt.** Curate them; bad examples steer the model wrong. They belong in version control too.
- **Treat prompt changes like code changes:** PR, review, and a passing eval run before merge. "I tweaked the wording" without an eval run is shipping untested code.

---

## Evals: the test suite for AI behavior

You cannot know whether an LLM feature works without an eval set. Evals are to AI features what tests are to code — the difference is they assess *quality across a distribution*, not binary pass/fail on deterministic outputs (`testing.md`).

- **Build the eval set before or during development**, not after launch. The set is the spec; building it forces you to define what "good" means concretely.
- **Eval types, from cheapest to most reliable:**
  - **Exact match / schema checks** — verifiable facts, JSON schema compliance. Deterministic. Run in CI on every prompt or model change.
  - **Heuristic checks** — regex, keyword presence, length bounds, format validation. Also CI-runnable, zero marginal cost.
  - **LLM-as-judge** — a separate model call scores quality (coherence, accuracy, tone). Scalable but adds cost and a layer of non-determinism to manage.
  - **Human eval** — ground truth for subjective quality; expensive; use it to calibrate automated evals, not as the only gate.
- **Track eval scores across prompt and model changes.** A change that improves one metric while degrading another is not obviously an improvement — you need the full picture before merging.
- **Document failure modes.** An eval set that only covers the happy path is the AI equivalent of only testing the success branch.

---

## Hallucination, grounding, and the "I don't know" path

LLMs confabulate — they produce plausible-sounding falsehoods with high confidence. Every system that presents model output as fact must have an explicit grounding and uncertainty strategy.

- **Ground outputs in retrievable sources (RAG).** Retrieve relevant documents first; instruct the model to answer *from* those documents; surface citations so users and evals can verify claims. A RAG pipeline is only as good as its retrieval — bad retrieval is worse than none, because the model confabulates confidently from irrelevant context.
- **Design an explicit "I don't know" path.** Instruct the model to express uncertainty when evidence doesn't support a confident answer, and test that it actually uses it — models are biased toward sounding helpful over being accurate.
- **Never present ungrounded model output as fact in high-stakes contexts** — medical, legal, financial, safety-critical. Ground it or gate it behind human review.
- **Validate structured outputs against a schema.** A model asked for JSON that sometimes returns prose, or for a date that sometimes invents one, is not a reliable data source — validate every response and handle failures explicitly.

```python
# RAG pattern: retrieve → ground → cite → verify
docs = retriever.search(query, top_k=5)
response = llm.complete(
    system="Answer only from the provided documents. "
           "If the answer isn't in them, say so explicitly.",
    context=docs,
    query=query,
)
# Eval: does every claim map back to a retrieved document?
assert_citations_present(response, docs)
```

---

## Prompt injection: the model is a confused deputy

When the model processes external content — user input, retrieved documents, tool outputs, web pages, emails — an attacker can embed instructions that hijack the model's behavior. This is **prompt injection**: the LLM equivalent of SQL injection, and just as dangerous (`security.md`).

- **Treat all external content as untrusted data, never as trusted instructions.** The model cannot reliably distinguish "the document says X" from "do X." Design around this limitation; don't assume the model will resist.
- **Separate system instructions from user/external content structurally.** Use the system prompt for your instructions and the user/assistant turns for content. This reduces — but does not eliminate — injection risk.
- **Never let model output trigger privileged actions unchecked.** A model that can call `delete_record`, `send_email`, or `execute_query` on its own output is a privilege-escalation vector. Require explicit human confirmation for irreversible or high-impact actions (see agent design below).
- **Validate and sanitize model output before it reaches any downstream system.** Treat it as untrusted input at every boundary — SQL, shell, HTML, another model call (`security.md`).
- **Know the OWASP LLM Top 10.** The documented risks — prompt injection, insecure output handling, excessive agency, model denial of service, supply chain — map directly onto real incidents. Design against them from the start.

---

## Cost and latency are first-class constraints

LLM calls are not free function calls. Every token costs money; every call adds latency. These are engineering constraints to be designed around, not runtime surprises.

- **Set a token budget per call.** Know the expected input + output token count; enforce it with `max_tokens`. An unbounded call is an unbounded bill and an unbounded wait.
- **Right-size the model.** Use the cheapest model that meets the quality bar for the task, not the most capable one by default. A classification task that works on a smaller model should not run on the flagship. Benchmark quality vs. cost per use case, then decide.
- **Cache aggressively where output is stable.** Identical or semantically equivalent prompts with deterministic outputs can be cached at the application layer — this also reduces non-determinism. Prefer prefix caching where the API supports it (`backend.md`).
- **Stream long responses.** Token-by-token streaming cuts perceived latency for the user; set a hard timeout on the stream, not just the connection.
- **Track cost per request like you track latency per request** — on a dashboard, with alerts. A cost regression from a prompt change is a bug (`cloud.md`).
- **Batch non-interactive workloads.** Embeddings, classification at scale, nightly analysis — use batch APIs at lower cost without real-time latency requirements.

---

## Context management: the token budget

The context window is finite. How you fill it determines output quality more than almost any other factor.

- **Prioritize ruthlessly.** Put the most relevant content nearest the query — models attend better to recent context. Irrelevant content is not neutral; it degrades output and wastes tokens.
- **Truncate with a strategy.** "Last N tokens" drops critical context silently. Prefer semantic retrieval (RAG) to select what's relevant, or summarize older context rather than discarding it blind.
- **Count tokens before the call.** Use the model's tokenizer client-side to verify the request fits the context window *before* submitting — fail predictably on your terms, not mid-stream with a context overflow error. Leave headroom for the output.
- **Separate long-term memory from working context.** Cramming an entire conversation history into every prompt is a cost and quality trap. Summarize, retrieve, or index; treat the working context window as a scarce resource.

---

## Agent and tool-use design

When the model can take actions — call APIs, run queries, read/write files — mistakes have real-world consequences. Apply the same discipline as any system that modifies shared state.

- **Least privilege.** Grant each tool the minimum capability for the task: a research agent needs read access, not write; a customer agent must never see another customer's data. The blast radius of a prompt-injected agent is bounded by its permissions (`security.md`).
- **Idempotent tool implementations.** The model may call the same tool twice — on retries, confusion, or loop errors. Tool calls must be safe to repeat with the same arguments, or check-and-skip on a repeated call (`backend.md`).
- **Agentic loops must terminate.** A loop without a hard step or iteration limit will run until it exhausts the context, the budget, or a timeout. Set a maximum number of steps; fail loudly when reached.
- **Human-in-the-loop for irreversible actions.** Deleting, sending, publishing, charging — any action the user cannot undo must require explicit human confirmation before execution. This is a safety requirement, not optional UX polish.
- **Log every tool call and its result.** An agent that acts opaquely is undebuggable. Audit trail minimum: model decision, tool called, arguments, result, next step.
- **Plan before acting for multi-step tasks.** A model that reasons through a plan before taking tool actions makes fewer irreversible mistakes than one acting greedily on each step.

```python
MAX_STEPS = 20
for step in range(MAX_STEPS):
    action = model.next_action(context)
    if action.type == "finish":
        break
    if action.is_irreversible:
        action = await human_confirm(action)    # block; never auto-execute
    result = tools.execute(action)
    context.append(result)
else:
    raise AgentStepLimitExceeded(f"Did not finish within {MAX_STEPS} steps")
```

---

## Data, privacy, and governance

What you send to a model provider is outside your perimeter. Treat it accordingly.

- **Minimize what you send.** Strip PII, credentials, and sensitive data from prompts before they leave your system. Pseudonymize where you can; the model rarely needs real values to reason about structure.
- **Never send secrets to the model.** API keys, passwords, and tokens in prompts are logged by providers, potentially used in training, and expose your perimeter if a prompt is extracted (`security.md`).
- **Log model I/O with redaction.** You need prompt + response for debugging and evals; you do not need the PII embedded in them. Redact at the boundary before writing to your log store (`cloud.md`).
- **Know your provider's data handling policies.** Some providers train on API traffic by default unless opted out. Know what you agreed to; opt out for sensitive workloads.
- **Maintain an audit trail for regulated domains.** Financial, medical, and legal AI outputs typically require knowing which model version and which prompt produced a given result. Log model name, version, and parameters alongside every production call.

---

## Observability and reproducibility

"The model did something weird" is not a bug report you can act on. You need enough signal to reproduce and diagnose AI failures.

- **Log the full request context** for every production call: prompt (redacted of PII), model name and version, parameters (temperature, max_tokens, etc.), response, latency, token counts, cost. This is the minimum needed to reproduce a failure.
- **Assign a trace/correlation ID to every LLM call** and thread it through all downstream actions — the same discipline as distributed tracing (`cloud.md`).
- **Version everything that affects output.** Model name + version + prompt version + retrieval corpus version = the reproducibility key. A change to any one of these is a deployment, and needs an eval run before it goes to production.
- **Track quality metrics over time** — eval pass rates, refusal rates, error rates, cost-per-request, latency p99. A chart that shows quality drift across model or prompt changes is as necessary as an uptime chart.
- **Alert on quality regression, not just availability.** A model that is up but returning garbage is worse than one that is down — downstream systems will consume the bad output silently. Quality SLOs belong alongside latency and error-rate SLOs.

---

## AI/LLM review checklist

- Non-determinism acknowledged: temperature pinned for deterministic tasks; tests assert on properties and structure, never exact strings?
- Prompts in version control, structured, reviewed like code; system instructions separated from user/external content?
- Eval set exists, covers failure modes and edge cases, runs on every prompt or model version change, tracks quality metrics over time?
- Grounding strategy defined: RAG pipeline verified end-to-end, citations checkable, "I don't know" path explicitly tested?
- Prompt injection mitigated: all external content treated as untrusted data; model output validated before reaching any downstream interpreter or executor?
- Token budget enforced (`max_tokens`); model right-sized for the task; cost tracked per request with regression alerts?
- Context window managed: relevant content prioritized, token count verified before call, long-term memory separated from working context?
- Agent tools have least-privilege; tool calls idempotent; loops bounded with a hard step limit; irreversible actions gated behind human confirmation?
- PII and secrets stripped from prompts; model I/O logged with redaction; model name + version + prompt version recorded for every production call?
- Quality metrics in observability (not just availability); regression alerts configured; every production call carries a trace ID?
