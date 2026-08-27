# Troubleshooting

## Codex usage not found

Confirm that Codex has created local session history on this Mac. CodexMeter does not query account-wide cloud usage and cannot recover deleted logs or usage from another computer.

## Sessions directory is empty

CodexMeter reads `~/.codex/sessions` and `~/.codex/archived_sessions`. Run a local Codex session first, then choose Refresh in the menu bar popover.

## Statistics appear incomplete

The footer reports partial accuracy when a cumulative baseline, malformed event, or interleaved counter cannot be resolved safely. CodexMeter intentionally undercounts ambiguous usage instead of inventing a delta. Choose Data > Rebuild Statistics after Codex has finished writing its session files.

## Rebuild statistics

Settings > Data > Rebuild Statistics deletes only CodexMeter's derived rows and reprocesses observable Codex JSONL. It preserves the clear-history cutoff.

## Clear local history

Settings > Data > Clear Local History securely clears CodexMeter's local SQLite rows and records the current time as an import cutoff. It never deletes Codex session files, and events at or before the cutoff stay excluded.

## Launch at Login issue

If macOS requires approval, use Settings > General > Open Login Items Settings and enable CodexMeter. Launch at Login is available from a packaged app; behavior from `swift run` is not representative.

## Database issue

Use Settings > Data > Open Data Folder to inspect the CodexMeter Application Support directory. Rebuild Statistics is the first recovery step. Before reporting a problem, enable debug logging, reproduce it, then use Settings > Advanced > Open Log Folder. Debug logs contain operational event names and aggregate counts only.
