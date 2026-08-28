# Troubleshooting

## Codex usage not found

Confirm that Codex has created local session history on this Mac. Local History cannot recover deleted logs or usage from another computer. On macOS, enable **Settings → Usage & Privacy → Use ChatGPT account totals** to load the separate account-wide profile totals.

## Sessions directory is empty

CodexMeter reads `~/.codex/sessions` and `~/.codex/archived_sessions`. Run a local Codex session first, then choose Refresh in the menu bar popover.

## Totals are lower than expected

For **This Mac** values, CodexMeter excludes a cumulative baseline, malformed event, or interleaved counter when it cannot derive a safe delta. Choose Data > Rebuild Statistics after Codex has finished writing its session files. Deleted logs and usage from another computer cannot be reconstructed locally.

For **ChatGPT account** values, confirm that Codex is signed in and profile sync is enabled. The displayed date is the server's exact snapshot date, so these totals can lag behind live local activity. The primary Today summary and menu bar Today value remain the current Mac's live local total; delayed profile-day totals are shown separately. A sign-in-expired or temporarily-unavailable status never changes local history.

## Rebuild statistics

Settings > Data > Rebuild Statistics deletes only CodexMeter's derived rows and reprocesses observable Codex JSONL. It preserves the clear-history cutoff.

## Clear local history

Settings > Data > Clear Local History securely clears CodexMeter's local SQLite rows and records the current time as an import cutoff. It never deletes Codex session files, and events at or before the cutoff stay excluded.

## Launch at Login issue

If macOS requires approval, use Settings > General > Open Login Items Settings and enable CodexMeter. Launch at Login is available from a packaged app; behavior from `swift run` is not representative.

## Database issue

Use Settings > Data > Open Data Folder to inspect the CodexMeter Application Support directory. Rebuild Statistics is the first recovery step. Before reporting a problem, enable debug logging, reproduce it, then use Settings > Advanced > Open Log Folder. Debug logs contain operational event names and aggregate counts only.

CodexMeter stops adding rows if its local database reaches the 1 GiB safety limit, and it refuses to enumerate more than 50,000 session files in one installation. The app reports either condition instead of deleting data automatically. Clear Local History is the explicit recovery option after you have confirmed you no longer need the locally derived totals.
