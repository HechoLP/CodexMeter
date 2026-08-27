# Architecture

CodexMeter is a native Swift menu bar app with no third-party runtime dependencies.

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

Token-count events are cumulative snapshots. The normalizer ignores identical snapshots, derives component-wise increases, counts a fresh first counter only when `last_token_usage` equals `total_token_usage`, and treats unresolved baselines or ambiguous decreases as partial accuracy. Cached input remains a subset of input; total is always input plus output.

The committed byte offset is the first byte after the last complete newline whose parser state and normalized events have been committed together. An ordinary unfinished final line leaves the offset unchanged and is retried after a later append. A line exceeding the 1 MiB safety limit is quarantined through the observed end of file so it cannot be reread indefinitely.

FSEvents is only a refresh hint. Startup, wake, manual refresh, and watcher events all reconcile file identity, size, and committed offset against SQLite.
