# Privacy

CodexMeter processes Codex usage locally. Its only network feature is the bundled Sparkle updater, which checks an HTTPS appcast on the configured public release repository's dedicated `update-feed` branch and downloads updates from that repository's GitHub Releases. Automatic checks run at most once per day by default and can be disabled in **Settings → General**; a manual check is available in **Settings → About**.

Update requests contain the normal connection metadata needed to reach GitHub, such as the user's IP address and HTTP client information. CodexMeter does not add token totals, prompts, responses, source paths, project metadata, database contents, Codex credentials, or machine profile data to an update request. Update archives and the appcast are verified with the public Ed25519 key embedded in the app before extraction or installation.

It discovers only JSONL files within `~/.codex/sessions` and `~/.codex/archived_sessions`. The reader passes over those files in bounded chunks but projects only the metadata needed to locate token-count events. The database stores normalized token counts, timestamps, SHA-256-derived session, source, and event identifiers, plus incremental parser checkpoints. Raw session paths, model names, and project working directories are not persisted. Rewrite detection stores only a keyed HMAC of the committed source prefix. The random per-install HMAC key is kept in a separate owner-only file, so the database does not contain a reusable hash oracle for prompt or response content.

The Application Support directory is restricted to the current user (`0700`), and SQLite, lock, and fingerprint-key files are restricted to the current user (`0600`). Clearing local history enables SQLite secure deletion, truncates the write-ahead log, and vacuums the database. It also records a cutoff so older source events are not silently imported again. If post-delete compaction cannot finish immediately, the logical deletion and cutoff remain committed and the Data pane reports that secure compaction should be attempted again.

CodexMeter does not store or log prompts, responses, reasoning text, source code, tool input or output, terminal output, authentication tokens, or `~/.codex/auth.json`.

Debug logging is off by default. When enabled, it records only timestamps, fixed operational event names, data-quality state, source counts, and processed-byte totals. It never records source paths or raw error descriptions, and rotates at 1 MiB.

“All Time” is limited to records observable in local Codex session history after any user-established clear-history cutoff. Deleted logs and usage from other Macs are not recoverable.
