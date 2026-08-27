# Architecture

CodexMeter has a native SwiftUI menu bar app for macOS and a native .NET 8 WPF notification-area app for Windows. Local usage accounting has no network dependency. Sparkle 2.9.6 is bundled only with the macOS app for signed application updates.

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

The macOS updater is isolated from token ingestion. It reads a signed HTTPS appcast, verifies the feed and GitHub Release archive with an embedded Ed25519 public key, and verifies the archive before extraction. No usage state is passed to Sparkle. The Windows preview has no self-updater and opens only the fixed releases page after explicit user action.

Token-count events are cumulative snapshots. The normalizer ignores identical snapshots, derives component-wise increases, counts a fresh first counter only when `last_token_usage` equals `total_token_usage`, and treats unresolved baselines or ambiguous decreases as partial accuracy. Cached input remains a subset of input; total is always input plus output.

The committed byte offset is the first byte after the last complete newline whose parser state and normalized events have been committed together. An ordinary unfinished final line leaves the offset unchanged and is retried after a later append. A line exceeding the 1 MiB safety limit is quarantined through the observed end of file so it cannot be reread indefinitely. Same-inode rewrites are detected with metadata plus a keyed, streaming HMAC of the committed prefix; unchanged files avoid that read.

On macOS, one refresh processes at most 32 MiB or roughly five seconds of new data before committing progress. On Windows, startup performs a bounded streaming reconciliation and later refreshes reuse unchanged per-file results held in memory. Both platforms fail closed above 50,000 source files; Windows additionally caps normalized events at 500,000 per source and 5,000,000 per process.

File-system notifications are only refresh hints. Startup, manual refresh, watcher events, and the fallback timer reconcile source state again. macOS also reconciles committed offsets and keyed continuity fingerprints against SQLite; Windows verifies file length and modification time around each bounded parse and refuses to cache a file that changes during the read.
