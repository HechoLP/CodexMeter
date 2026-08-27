# Security Policy

## Supported versions

CodexMeter has not published its first stable release. Security fixes currently target the `main` branch.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not include real prompts, responses, source code, terminal output, authentication files, or session archives in a report. A minimal synthetic fixture and the affected CodexMeter version are preferred.

CodexMeter has no telemetry or analytics. Its local-accounting trust boundary is the Codex session-data directory, plus the macOS SQLite database or the Windows process-memory cache. The macOS Sparkle updater requires both a signed HTTPS appcast and an Ed25519-signed GitHub Release archive before extraction. The unsigned Windows preview does not self-update; users must verify its portable ZIP against the published SHA-256 manifest.
