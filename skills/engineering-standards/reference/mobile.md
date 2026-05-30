# Mobile Engineering

Flutter, Android, and iOS. Mobile adds constraints a server never has: an unreliable network in the user's pocket, a battery and memory budget you can exhaust, an OS that kills your process whenever it likes, and a lifecycle that interrupts everything. Build for those realities, not for the simulator on fast Wi-Fi.

---

## Architecture: unidirectional data flow + a clean data layer

Whatever the platform calls it (BLoC, MVVM, MVI, TCA, Redux), the winning shape is the same: **state flows one way, events flow back, and the UI is a pure function of state.**

```
UI  ──event──▶  Logic (BLoC / ViewModel / Reducer)  ──state──▶  UI
                       │
                       ▼
                  Repository  ──▶  DataSource (remote API / local DB / cache)
```

- **Screens are dumb.** They render the current state and emit events. No business logic, no direct network calls in a widget/view/controller.
- **The logic layer holds business logic, not UI logic.** It takes events, talks to repositories, emits states. It must be unit-testable with no UI and no real network.
- **Repositories abstract the data source.** The logic layer must not know whether data came from the network, a local database, or a cache — that's the repository's secret. This is what makes offline-first and testing possible.
- **Immutable state.** Model UI state as immutable values (Flutter: `freezed`/`equatable`; Swift: value types; Kotlin: `data class`). New state replaces old; never mutate in place. Same reasoning as `frontend.md` and `concurrency.md`.

```dart
// Flutter BLoC: screen emits an event, renders whatever state comes back — nothing more
BlocBuilder<TransferBloc, TransferState>(
  builder: (context, state) => switch (state) {
    TransferLoading() => const ProgressIndicator(),
    TransferLoaded(:final balance) => BalanceView(balance),
    TransferError(:final message) => ErrorView(message, onRetry: () =>
        context.read<TransferBloc>().add(const TransferRetried())),
  },
);
```

---

## Offline-first is the default, not a feature

The network *will* be absent, slow, or flaky — in an elevator, on a subway, in a rural area. An app that only works online is broken for a large share of real usage.

- **Write to the local database first, sync in the background.** The user's action is durable immediately; the UI responds instantly; the sync layer reconciles with the server when it can.
- **The local DB is the source of truth for the UI.** Render from local; treat the server as the thing you sync *to*, not the thing you block the UI on.
- **Queue mutations** made offline and replay them when connectivity returns — with **idempotency keys** so a replay doesn't double-charge (`backend.md`).
- **Plan for conflict.** Two devices edit offline; on sync they disagree. Decide the resolution rule deliberately (last-write-wins, server-wins, merge, or prompt) — don't let it be accidental.

---

## The lifecycle will interrupt you — survive it

The OS pauses, backgrounds, and **kills** your process at will: a phone call, low memory, the user switching apps. Code that assumes it runs uninterrupted from launch to exit is wrong.

- **Persist state across process death.** When the OS kills and relaunches you, restore where the user was. Never assume in-memory state survived backgrounding.
- **Release resources on pause/background**: cameras, location, sensors, sockets, timers. Holding them drains battery and gets your app killed or throttled.
- **Cancel work tied to a screen when it's disposed.** A network call or stream that outlives its screen leaks memory and may write to a dead UI — a frequent crash and leak source. (Flutter: cancel subscriptions in `dispose`; iOS: `[weak self]`; Android: tie to `viewModelScope`/lifecycle.)
- **Do heavy work off the main/UI thread.** The UI thread renders at 60–120fps; any blocking work there drops frames and triggers ANRs. Push it to isolates/coroutines/GCD background queues.

---

## Resource budgets — battery, memory, data

These aren't optimizations; exceeding them gets your app killed or uninstalled.

- **Battery**: batch network calls; don't poll on a tight timer; use push instead of pull where you can; coalesce background work into OS-scheduled windows (WorkManager / BGTaskScheduler). Wake-locks and chatty radios are the top drains.
- **Memory**: images are the usual killer — downsample to display size, cache with eviction, never decode full-resolution photos into a list. A memory spike gets you OOM-killed.
- **Data**: assume a metered, capped connection. Paginate, compress, cache aggressively, and don't refetch what hasn't changed (ETags/conditional requests). Respect the user's data.

---

## Platform integrity

- **Permissions**: request the minimum, at the moment of use (not all up-front), and degrade gracefully when denied — never crash or dead-end.
- **Secure storage**: tokens and secrets go in the Keychain / Keystore, never in plain preferences or local files. Never log them (`security.md`).
- **Respect platform conventions**: back-button/gesture behavior, safe areas/notches, dynamic type and font scaling, dark mode, and accessibility (VoiceOver/TalkBack). An app that fights the platform feels broken.
- **Handle every async UI path's loading/empty/error states** exactly as in `frontend.md` — a spinner that never resolves on a dropped connection is a classic mobile failure.

---

## Release engineering — the store is a one-way door

Unlike a web deploy you can roll back in seconds, a shipped mobile binary lives on users' devices until *they* update — and some never will. That changes the discipline.

- **Old versions live forever.** Your backend must stay compatible with app versions from months ago. Version your API and never break old clients (`backend.md`); force-upgrade only as a last resort, and design for the user who refuses to update.
- **Staged/phased rollouts.** Release to 1% → 10% → 100%, watching crash rate and reviews. Both stores support halting a rollout — use it; a bad binary at 1% is recoverable, at 100% it's a fire you can't put out fast.
- **Feature-flag risky features** (remote config) so you can disable a broken feature *without* a store release. This is your real "rollback" on mobile — the kill switch, not a redeploy.
- **Signing and provisioning are security-critical.** Keystores/certificates and their passwords are secrets — in a secrets manager and CI, never in the repo (`security.md`). Losing the Android signing key means you can never update that app again; protect it like production credentials.
- **Automate the build/sign/upload pipeline** (Fastlane or equivalent). Manual signing and uploading is error-prone and unrepeatable; CI/CD makes releases boring, which is the goal.

## Crash reporting, analytics, and app size

- **Ship a crash/error reporter from day one** (Crashlytics, Sentry). You cannot SSH into a user's phone — symbolicated crash reports with device/OS context are your *only* window into production failures. Wire it before launch, not after the first mystery 1-star review.
- **Watch crash-free rate as a release gate.** A dip after a rollout means halt and fix. Treat it like an SLO (`cloud.md`).
- **App size is adoption.** A bloated app gets abandoned mid-download on mobile data and won't install on low-storage devices. Use app-bundle/per-device delivery (Android App Bundle, iOS app thinning), compress and lazy-download assets, audit dependencies, and strip unused code/resources. Every megabyte is a conversion cost.
- **Respect privacy and platform policy.** Declare data collection honestly (privacy nutrition labels / data-safety forms), minimize what you collect, and never log PII (`security.md`) — store rejections and trust loss are expensive.

## Mobile review checklist

- Unidirectional flow: dumb screens, testable logic layer, repository hiding the data source?
- State immutable; subscriptions/streams cancelled on dispose; no work tied to a dead screen?
- Offline-first: writes hit local DB first, sync in background, mutations queued with idempotency keys, conflict rule decided?
- Survives process death (state restored) and backgrounding (resources released)?
- Heavy work off the main thread; no jank/ANR risk?
- Image memory bounded (downsampled, evicting cache); network batched/paginated/conditional for battery and data?
- Permissions minimal, just-in-time, graceful on denial; tokens in Keychain/Keystore, never logged?
- Loading/empty/error states handled on every async path; platform conventions and accessibility respected?
