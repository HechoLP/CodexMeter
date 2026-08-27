# Architecture

CodexMeter is a native Swift menu bar app. Local usage accounting has no network dependency; the only bundled third-party runtime is Sparkle 2.9.6 for signed application updates.

```text
Codex session JSONL
  -> contained source discovery
  -> FSEvents refresh hint
  -> bounded incremental reader
  -> tolerant metadata projection
  -> cumulative usage normalizer
  -> transactional SQLite event + checkpoint commit
  -> cached UsageSnapshot
  -> MainActor UI store
  -> MenuBarExtra popover and Settings
```

The updater is isolated from token ingestion. It reads a signed HTTPS appcast from the configured public release repository's dedicated `update-feed` branch, verifies the feed and GitHub Release archive with an embedded Ed25519 public key, and verifies the archive before extraction. No usage state is passed to Sparkle.

Token-count events are cumulative snapshots. The normalizer ignores identical snapshots, derives component-wise increases, counts a fresh first counter only when `last_token_usage` equals `total_token_usage`, and treats unresolved baselines or ambiguous decreases as partial accuracy. Cached input remains a subset of input; total is always input plus output.

The committed byte offset is the first byte after the last complete newline whose parser state and normalized events have been committed together. An ordinary unfinished final line leaves the offset unchanged and is retried after a later append. A line exceeding the 1 MiB safety limit is quarantined through the observed end of file so it cannot be reread indefinitely. Same-inode rewrites are detected with metadata plus a keyed, streaming HMAC of the committed prefix; unchanged files avoid that read.

One refresh processes at most 32 MiB or roughly five seconds of new source data before committing progress and scheduling a continuation. Discovery fails closed above 50,000 source files, and SQLite ingestion stops at a 1 GiB allocation safety limit instead of exhausting the user's disk. These limits never delete history automatically.

FSEvents is only a refresh hint. Startup, wake, manual refresh, and watcher events all reconcile file identity, size, content continuity, and committed offset against SQLite. Automatic mode also performs a low-frequency fallback reconciliation so a sessions directory created after launch is discovered.
