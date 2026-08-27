# Changelog

All notable changes to CodexMeter will be documented in this file.

## [Unreleased]

## [0.1.0] - 2026-08-27

### Added

- Native macOS menu bar popover and Settings interface.
- Incremental local Codex JSONL discovery, parsing, normalization, and SQLite persistence.
- Today, week, month, and locally observable all-time token totals.
- Launch at Login, data rebuild/clear controls, and privacy-safe opt-in diagnostics.
- Universal 2 ZIP/DMG release pipeline, checksums, CI, and release documentation.
- Resumable 10,000/100,000-event stress coverage and fail-closed public-release verification.
- Versioned Homebrew Cask and a verified local-Tap installation path.
- Product-focused README artwork and installation documentation.
- Sparkle 2.9.6 automatic updates, daily checks, a user preference, and manual update checks.

### Fixed

- Excluded replayed parent history from forked and subagent sessions, with a targeted database migration that rebuilds affected local totals.
- Defaulted fresh installs to a logo-only menu bar item and made the Settings button reliably activate a native window.
- Prevented duplicate accounting after database migration, session archival, counter races, and same-inode file rewrites.
- Preserved oversized-line quarantine and complete snapshot consistency across refreshes and concurrent writers.
- Corrected automatic discovery fallback, manual wake behavior, calendar-boundary refreshes, loading states, actual update time, menu-bar display accessibility, and data-maintenance feedback.
- Rejected floating-point token components that could round into integers and excluded future-only records from current status.

### Security

- Owner-only Application Support and database permissions.
- Hashed session/event identifiers and no persisted model or project metadata.
- Secure-delete, WAL truncation, and vacuum behavior for local-history clearing.
- Per-install keyed rewrite fingerprints, owner-only lock/key files, source/refresh/database resource limits, pinned CI actions, and strict Developer ID/notarization gates.
- HTTPS update delivery with Ed25519 archive signatures, signed appcast verification, and verification before extraction.
