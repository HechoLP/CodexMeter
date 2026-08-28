# Architecture

CodexMeter has a native SwiftUI menu bar app for macOS and a native .NET 10 WPF notification-area app for Windows. Local usage accounting has no network dependency. macOS also offers an explicitly enabled, memory-only account-total overlay; Windows remains local-only. Sparkle 2.9.6 is bundled only with the macOS app for signed application updates.

```text
Codex session JSONL
  -> contained source discovery
  -> FSEvents or FileSystemWatcher refresh hint
  -> bounded incremental reader
  -> tolerant metadata projection
  -> cumulative usage normalizer
  -> macOS SQLite checkpoints or Windows changed-file memory cache
  -> cached UsageSnapshot
  -> platform UI store
  -> menu bar or notification-area popover and Settings
```

Optional macOS profile totals follow a separate boundary:

```text
~/.codex/auth.json credential projection
  -> fixed HTTPS GET to chatgpt.com/backend-api/wham/profiles/me
  -> validated aggregate daily/lifetime fields
  -> memory-only ProfileUsageStore
  -> ChatGPT account totals in the UI
```

The profile response is not merged into `UsageSnapshot` or SQLite. Remote failure cannot change local parser state, and local input/cached-input/output values are always presented as a separate **This Mac** breakdown.

Phase 2 extends the same macOS token pipeline without a second database:

```text
normalized usage_events
  -> database-side Today / 7D / 30D buckets
  -> model / keyed-project / session groupings
  -> one PricingCatalog + CostEstimator
  -> Usage / Projects / Sessions drill-down views
```

Canonical model IDs are retained for pricing. Full working directories are immediately projected to a keyed HMAC plus their final folder name; raw paths never enter SQLite. Parent-session IDs are hashed with the existing storage identifier. Image attachment records contribute only a timestamped numeric count when the local schema is unambiguous; the retained whole-session count respects the local-history cutoff and attachment payloads are never copied. Inherited parent replay remains excluded before events reach aggregation, so parent and sub-agent rows are not added twice.

Schema version 15 preserves every Phase 1 accounting event while replaying available JSONL sources once to enrich model, project, cache-write, pricing-context, and session metadata. Replay checkpoints start above each source's historical generation and update semantic duplicates instead of adding token deltas twice. Missing legacy sources remain represented by their preserved totals, with unresolved backfill or legacy partial quality kept conservative rather than reported as exact.

Account limits use an independent read-only boundary:

```text
signed Codex app-server
  -> account/rateLimits/read
  -> tolerant generic limit-window projection
  -> memory-only AccountLimitStore
  -> Limits view
```

CodexMeter verifies the local vendor binary signature before launch, never runs it through a shell, bounds output and execution time, and polls at a low frequency. A failed refresh retains the last in-memory limit snapshot and cannot change local token analytics. Reset credits are displayed only; no consume or account mutation RPC exists in the app.

Estimated cost is a derived metric, not a stored bill. The catalog records one reviewed current API-pricing snapshot. The estimator uses Decimal, separates ordinary/cached/cache-write/output tokens, applies supported high-context request multipliers only where a qualifying request boundary was observed, safely treats input at or below the published threshold as standard pricing, and returns unavailable for unknown models or metadata that can change the amount.

The macOS updater is isolated from token ingestion. It reads a signed HTTPS appcast, verifies the feed and GitHub Release archive with an embedded Ed25519 public key, and verifies the archive before extraction. No usage state is passed to Sparkle. The Windows release has no self-updater and opens only the fixed releases page after explicit user action.

Token-count events are cumulative snapshots. The normalizer ignores identical snapshots, derives component-wise increases, counts a fresh first counter only when `last_token_usage` equals `total_token_usage`, and treats unresolved baselines or ambiguous decreases as partial accuracy. Cached input is a subset of input, so the displayed local activity total is input plus output; all three observed components remain independently stored and auditable. Account totals come from the separate profile boundary and are never reconstructed from or merged into those local rows.

The committed byte offset is the first byte after the last complete newline whose parser state and normalized events have been committed together. An ordinary unfinished final line leaves the offset unchanged and is retried after a later append. A line exceeding the 1 MiB safety limit is quarantined through the observed end of file so it cannot be reread indefinitely. Same-inode rewrites are detected with metadata plus a keyed, streaming HMAC of the committed prefix; long verification work resumes only while file identity, size, modification time, and status-change time remain stable.

On macOS, one refresh processes at most 32 MiB or roughly five seconds of new data before committing progress. On Windows, startup performs a bounded streaming reconciliation and later refreshes reuse unchanged per-file results held in memory. Both platforms fail closed above 50,000 source files. Windows additionally caps normalized events at 500,000 per source and 1,000,000 per process, limits each source to 512 MiB, limits accepted source history to 32 GiB, and reads at most 4 GiB in one reconciliation pass. Hard-linked source aliases are deduplicated by stable Windows file identity.

File-system notifications are only refresh hints. Startup, manual refresh, watcher events, and the fallback timer reconcile source state again. macOS also reconciles committed offsets and keyed continuity fingerprints against SQLite; Windows verifies file length and modification time around each bounded parse, refuses to cache a file that changes during the read, and retains every changed path received during the watcher debounce window.
