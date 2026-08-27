# Security Policy

## Supported versions

CodexMeter has not published its first stable release. Security fixes currently target the `main` branch.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not include real prompts, responses, source code, terminal output, authentication files, or session archives in a report. A minimal synthetic fixture and the affected CodexMeter version are preferred.

CodexMeter has no telemetry or analytics. Its local-accounting trust boundary is the Codex session-data directory and its own SQLite database under Application Support. The separate Sparkle updater is restricted to the HTTPS appcast on the configured public release repository's dedicated `update-feed` branch and requires both that signed feed and an Ed25519-signed GitHub Release archive before extraction.
