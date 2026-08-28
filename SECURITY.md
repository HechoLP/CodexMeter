# Security Policy

## Supported versions

Security fixes target the latest `1.x` release and the `main` branch. Older preview builds are unsupported.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository. Do not include real prompts, responses, source code, terminal output, authentication files, or session archives in a report. A minimal synthetic fixture and the affected CodexMeter version are preferred.

CodexMeter has no telemetry. Its local-accounting trust boundary is the Codex session-data directory, plus the macOS SQLite database or the Windows process-memory cache. macOS local analytics may persist canonical model IDs, keyed project identifiers, hashed session identifiers, project folder basenames, and numeric image counts, but never full paths, session content, or attachment payloads. When a macOS user explicitly enables ChatGPT account totals, a separate memory-only boundary reads the current Codex access token and account ID and sends them only to the fixed `https://chatgpt.com/backend-api/wham/profiles/me` endpoint. Credentials and responses must never be persisted or logged, redirects must be rejected, and remote values must never be inserted into local usage tables. Read-only account limits come only from a vendor-signed local Codex app-server with bounded execution and output; no reset-credit consumption or account-mutation RPC is allowed. The macOS Sparkle updater requires both a signed HTTPS appcast and an Ed25519-signed GitHub Release archive before extraction. The publisher-unsigned Windows release does not self-update; users must verify its portable ZIP against the published SHA-256 manifest.

The certificate-free macOS and Windows packages are stable application builds, but they are not publisher-trusted by Apple or Microsoft. This distribution limitation is documented in the install guide and does not weaken the separate SHA-256 and Sparkle Ed25519 integrity checks.
