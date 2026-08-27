# Security Policy

## Supported versions

CodexMeter has not published its first stable release. Security fixes currently target the `main` branch.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not include real prompts, responses, source code, terminal output, authentication files, or session archives in a report. A minimal synthetic fixture and the affected CodexMeter version are preferred.

CodexMeter intentionally has no network client, telemetry, analytics, or updater. Its primary trust boundary is the local Codex session-data directory and its own SQLite database under Application Support.
