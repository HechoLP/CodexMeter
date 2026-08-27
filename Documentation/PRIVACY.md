# Privacy

CodexMeter runs locally and performs no network requests.

It discovers only JSONL files within `~/.codex/sessions` and `~/.codex/archived_sessions`. The reader passes over those files in bounded chunks but projects only the metadata needed to locate token-count events. The database stores normalized token counts, timestamps, SHA-256-derived session and event identifiers, and incremental parser checkpoints. Model names and project working directories are not persisted. A checkpoint retains the local JSONL path required to reopen that file; event rows retain only a digest of that path.

The Application Support directory is restricted to the current user (`0700`) and SQLite files are restricted to the current user (`0600`). Clearing local history enables SQLite secure deletion, truncates the write-ahead log, and vacuums the database. It also records a cutoff so older source events are not silently imported again.

CodexMeter does not store or log prompts, responses, reasoning text, source code, tool input or output, terminal output, authentication tokens, or `~/.codex/auth.json`.

Debug logging is off by default. When enabled, it records only timestamps, fixed operational event names, data-quality state, source counts, and processed-byte totals. It never records source paths or raw error descriptions, and rotates at 1 MiB.

“All Time” is limited to records observable in local Codex session history after any user-established clear-history cutoff. Deleted logs and usage from other Macs are not recoverable.
