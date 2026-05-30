# Frontend Engineering

Web UI: structure, state, rendering, accessibility, and performance. The UI *is* the product to the user, so its correctness and clarity are not cosmetic. Framework-agnostic principles; examples lean TypeScript/React because the patterns transfer. For visual craft, layout, and design-system polish, this pairs with the `impeccable`, `frontend-design`, and `web-design-guidelines` skills — this file is about engineering soundness.

---

## Separate the three jobs

Data fetching, state management, and rendering are three different responsibilities that get tangled by default. Keep them apart:

- **Fetching** — talking to the network, caching, retries, loading/error status. Belongs in a data layer (hooks, query library, repository), never inline in a render path.
- **State** — what the UI currently is. Two distinct kinds, treated differently (below).
- **Rendering** — a pure function of state to UI. Given the same state, the same output. No fetching, no mutation, no surprises inside render.

```tsx
// BAD — render path does fetching and owns server state by hand
function Profile({ id }) {
  const [user, setUser] = useState(null)
  useEffect(() => { fetch(`/users/${id}`).then(r => r.json()).then(setUser) }, [id])
  return <div>{user?.name}</div>   // no loading state, no error state, refetch races on id change
}

// GOOD — data layer owns fetching/caching/status; component just renders state
function Profile({ id }: { id: string }) {
  const { data, isLoading, error } = useUser(id)   // fetching abstracted away
  if (isLoading) return <ProfileSkeleton />
  if (error)     return <ErrorState onRetry={error.retry} />
  return <div>{data.name}</div>
}
```

---

## Server state vs. UI state — the distinction that prevents most bugs

- **Server state** is a *cache* of data that truly lives on the server: it's shared, it goes stale, it needs invalidation, refetch, and reconciliation. Use a query/cache library for it (TanStack Query, RTK Query, SWR). Do **not** hand-roll it in component state — that's how you get stale data, duplicate fetches, and race conditions on fast prop changes.
- **UI state** is local and ephemeral: is this modal open, which tab is active, the current form input. Keep it as local as possible; lift it only when a real shared parent needs it.

Conflating the two is the most common architectural mistake in frontend apps.

---

## State management rules

- **Keep state as local as it can be.** Global state is shared mutable state (see `concurrency.md` — same hazards, fewer guarantees). Lift only when genuinely shared; colocate otherwise.
- **Never mutate state directly.** Produce a new value; let the framework diff and re-render. Direct mutation breaks change detection and creates phantom bugs.
- **Derive, don't duplicate.** If a value can be computed from existing state, compute it during render — don't store a copy that can drift out of sync.
- **Single source of truth** for any given fact. Two pieces of state representing the same thing *will* disagree eventually.

---

## Rendering and performance

- **Keys must be stable and unique** in lists — never the array index when the list reorders/filters, or the framework reuses the wrong DOM node and state leaks between rows.
- **Side effects belong in effect hooks/handlers, not in render.** Render must be pure and idempotent; the framework may call it more than once.
- **Measure before optimizing** (the universal law holds here too). Reach for memoization only when a profiler shows a real re-render cost — premature `memo`/`useMemo` everywhere adds noise and bugs.
- **Virtualize long lists.** Rendering 10,000 DOM nodes janks; render only what's visible.
- **Mind the bundle.** Code-split by route, lazy-load below-the-fold and heavy dependencies, and watch what you pull in — a date library in the critical path costs real seconds on a slow phone. Ship less JavaScript.
- **Optimistic UI** for snappy mutations (update immediately, reconcile on server response, roll back on failure) — but only where being briefly wrong is safe.

---

## Accessibility is correctness, not decoration

An inaccessible UI is a broken UI for a real fraction of users — and the fixes also make it more robust and testable.

- **Semantic HTML first.** A real `<button>`, `<a>`, `<label>`, `<nav>`, `<h1>`–`<h6>` carries keyboard behavior, focus, and screen-reader meaning for free. A `<div onClick>` throws all of that away and you re-implement it badly.
- **Everything works by keyboard.** Tab order is logical, focus is always visible, focus is trapped in modals and returned on close. If you can't operate it without a mouse, it's broken.
- **Label every input.** Associate `<label>`s; provide accessible names for icon-only controls.
- **Don't rely on color alone** to convey state (error, success) — pair it with text or an icon.
- **Respect user settings** — `prefers-reduced-motion`, `prefers-color-scheme`, text scaling without layout breaking.
- **Touch targets ≥ 44×44px.** Tiny tap targets fail on real fingers.

(The `web-design-guidelines` skill audits these against the current Web Interface Guidelines — run it on UI diffs.)

---

## States you must handle (not just the happy path)

Every data-driven view has at least four states. Designing only the success state is the most common UI bug.

- **Loading** — a skeleton or spinner that doesn't flash for fast responses and doesn't jank layout (reserve the space).
- **Empty** — a real designed state with guidance ("No transactions yet — they'll appear here"), not a blank void or a stuck spinner.
- **Error** — actionable copy ("Couldn't load. Try again") with a retry, never a raw "Error 500" or a white screen.
- **Partial / stale** — when showing cached data while refetching, or some items failed: make the state legible.

---

## Forms and input

- **Validate on the client for UX, on the server for safety.** Client validation is a convenience; the server is the authority and must re-validate everything (`security.md`). Never trust the client.
- **Controlled, predictable inputs.** One source of truth per field; show validation at the right moment (on blur/submit, not aggressively on every keystroke).
- **Disable the submit button while submitting** and guard against double-submit — the network is slow and users click twice.
- **Preserve user input on error.** Never clear a form because one field failed.

---

## Rendering strategy — where and when HTML is built

A core architectural choice with real UX and SEO consequences; pick per route, not once for the whole app.

- **CSR (client-side render)** — ship a near-empty HTML shell + JS that builds the UI in the browser. Great for app-like, behind-login dashboards; bad for first paint and SEO (the crawler/user sees blank until JS runs).
- **SSR (server-side render)** — server sends complete HTML per request, then the client **hydrates** it (attaches interactivity). Fast first paint, SEO-friendly, good for dynamic content; costs server compute and adds hydration complexity.
- **SSG (static generation)** — render to HTML at *build* time, serve from a CDN. Fastest and cheapest for content that doesn't change per request (marketing, docs, blogs). Combine with **ISR** (incremental regeneration) to refresh static pages periodically.
- **Streaming / partial hydration / islands** — send HTML progressively and hydrate only the interactive parts, so the user sees and uses content before the whole page's JS loads. The modern default for cutting time-to-interactive.

**Hydration is the subtle cost:** the server HTML and the first client render must match exactly, or you get hydration mismatches (flicker, lost state, console errors). And hydrating a huge tree blocks interactivity — minimize the JS that has to hydrate.

## Performance: Core Web Vitals are the user's experience, measured

Optimize what the user actually feels; Google's Core Web Vitals are the standard proxy and a ranking signal:

- **LCP (Largest Contentful Paint)** — when the main content appears. Hurt by slow servers, render-blocking JS/CSS, and unoptimized images. Fix: prioritize/preload the hero, server-render or stream, compress and right-size images, modern formats (AVIF/WebP).
- **INP (Interaction to Next Paint)** — responsiveness to taps/clicks. Hurt by long JS tasks blocking the main thread. Fix: break up long tasks, defer non-critical JS, do heavy work in a Web Worker (the frontend echo of "don't block the loop", `concurrency.md`).
- **CLS (Cumulative Layout Shift)** — content jumping as the page loads. Fix: reserve space for images/ads/embeds with explicit dimensions; never insert content above what the user is reading.

General levers: ship less JavaScript (the biggest one), code-split per route, lazy-load below-the-fold, cache aggressively, and put static assets on a CDN. **Measure with real-user metrics, not just a fast laptop** — your users are on mid-range phones and flaky networks. (For broader audits, the `web-design-guidelines` skill checks current Web Interface Guidelines.)

## Frontend review checklist

- Fetching, state, and rendering separated; render pure with no side effects or fetches inside it?
- Server state in a cache/query layer (not hand-rolled in component state); UI state local?
- No direct state mutation; derived values computed, not duplicated; single source of truth per fact?
- List keys stable and unique (not index when order changes)?
- Loading, empty, error, and stale states all designed and handled?
- Semantic elements; full keyboard operability with visible focus; inputs labeled; not color-only; reduced-motion respected; targets ≥44px?
- Client validation for UX *and* server validation for safety; double-submit guarded; input preserved on error?
- Bundle split/lazy-loaded; long lists virtualized; memoization only where measured?
