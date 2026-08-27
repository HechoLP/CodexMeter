# CodexMeter for Windows 0.1.1

- Corrects token totals after same-size session rewrites by invalidating the changed-file cache on file-system events.
- Coalesces overlapping refresh requests so slow scans cannot race or replace a newer result.
- Treats an unterminated final JSONL record as incomplete and imports it only after the record is finished.
- Rebuilds the session watcher safely and detects `.codex` when it is created after CodexMeter starts.
- Makes settings saves atomic, avoids unnecessary startup-registry writes, and restores the previous startup setting if saving fails.
- Makes the Settings window open and reopen reliably while handling save and release-page errors without terminating the tray app.
- Updates the Windows test runner and enables strict .NET analyzers and formatting checks in CI.
- Provides self-contained x64 and ARM64 portable ZIP packages with SHA-256 manifests.

This preview is not code-signed. Verify the ZIP against `SHA256SUMS-windows.txt` before extracting it. Windows SmartScreen may require **More info → Run anyway**, **Properties → Unblock**, or `Unblock-File` for the verified executable.
