# Privacy

CodexMeter processes Codex usage locally. On macOS, the bundled Sparkle updater checks an HTTPS appcast and downloads updates from GitHub Releases. Automatic checks run at most once per day by default and can be disabled in **Settings → General**. The Windows preview does not perform a background network request; its Settings window opens the fixed GitHub Releases page only when the user requests it.

Update requests contain the normal connection metadata needed to reach GitHub, such as the user's IP address and HTTP client information. CodexMeter does not add token totals, prompts, responses, source paths, project metadata, cache contents, Codex credentials, or machine profile data to a request. macOS update archives and the appcast are verified with the public Ed25519 key embedded in the app before extraction or installation.

It discovers only JSONL files within `~/.codex/sessions` and `~/.codex/archived_sessions` on macOS or `%USERPROFILE%\.codex\sessions` and `%USERPROFILE%\.codex\archived_sessions` on Windows. Both readers project only the metadata needed to locate token-count events. The macOS database stores normalized counts, timestamps, SHA-256-derived identifiers, and incremental parser checkpoints. The Windows preview keeps normalized events and changed-file stamps only in process memory and persists only user-selected settings under `%LOCALAPPDATA%\CodexMeter`. Raw session paths, model names, and project working directories are not persisted on either platform.

On macOS, the Application Support directory is restricted to the current user (`0700`), and SQLite, lock, and fingerprint-key files are restricted to the current user (`0600`). Clearing local history enables SQLite secure deletion, truncates the write-ahead log, and vacuums the database. The Windows preview has no persistent usage database to clear; exiting the application discards its in-memory normalized event cache.

CodexMeter does not store or log prompts, responses, reasoning text, source code, tool input or output, terminal output, authentication tokens, or `~/.codex/auth.json`.

macOS debug logging is off by default. When enabled, it records only timestamps, fixed operational event names, data-quality state, source counts, and processed-byte totals. It never records source paths or raw error descriptions, and rotates at 1 MiB. The Windows preview does not write a diagnostic log.

“All Time” is limited to records observable in local Codex session history. Deleted logs and usage from other computers are not recoverable.
