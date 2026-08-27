# Changelog

All notable changes to CodexMeter will be documented in this file.

## [Unreleased]

### Added

- Added a native Windows 10/11 tray application with x64 and ARM64 self-contained packages, local Codex accounting, settings, tests, CI, and a certificate-free release workflow.

### Fixed

- Coalesced overlapping Windows refreshes, invalidated changed-file caches on file-system events, and retried unterminated final JSONL records after they become complete.
- Rebuilt Windows session watchers safely, including when `.codex` is created after launch, and kept the last good snapshot when a non-fatal source read fails.
- Made Windows settings saves atomic, prevented repeated startup-registry writes, and made the Settings window reopen reliably without duplicate event handlers.
- Derived Windows package versions from the project metadata so CI and release artifacts cannot silently reuse an older release version.

## [0.1.6] - 2026-08-27

### Fixed

- Aligned displayed totals with ChatGPT profile token activity by including input, cached input, and output while preserving the three auditable components.

## [0.1.5] - 2026-08-27

### Fixed

- Built every public macOS package in a new Swift scratch directory so a stale or damaged incremental build database cannot reuse an older executable under a new version number.
- Republished the inherited-session accounting correction from 0.1.4 in a verified clean Universal 2 binary.

## [0.1.4] - 2026-08-27

### Fixed

- Excluded copied parent token history from inherited sessions even when Codex omits an explicit replay ordinal or a second copied session-metadata record.
- Added a one-time derived-statistics rebuild so existing installations discard stale duplicated rows while preserving source JSONL files, settings, and the local-history cutoff.

## [0.1.3] - 2026-08-27

### Added

- Added purposeful refresh feedback: the refresh icon completes one bounded turn and changed token totals transition smoothly while respecting Reduce Motion.
- Added installation through the public `HechoLP/homebrew-tap` personal Tap.

### Fixed

- Replaced vague partial/stale-history warnings with concrete refresh results and update timestamps while preserving internal accounting safeguards.
- Removed the same ambiguous status copy from the Windows source for the next Windows package.

## [0.1.2] - 2026-08-27

### Fixed

- Moved certificate-free downloads and the signed Sparkle appcast to a dedicated public release repository so installation and automatic update checks work without GitHub authentication while the source repository remains private.

## [0.1.1] - 2026-08-27

### Added

- Added a certificate-free Universal 2 release workflow that produces an ad-hoc-signed ZIP, DMG, and checksum manifest without an Apple signing identity.

### Fixed

- Isolated unreadable or concurrently replaced Codex session files so one source cannot abort the full refresh; affected snapshots are marked partial while healthy sources continue importing.
- Replaced per-checkpoint full-prefix fingerprint recomputation with a versioned incremental accumulator and explicit fingerprint I/O accounting.
- Kept the data folder owner-only when it is created from Settings and aligned CI and release documentation with the preview-only distribution boundary.
- Made packaging create its artifact directory, made release hosting configurable, and made public builds fail closed unless a clean, matching version tag points to `HEAD` in a public release repository.
- Added a consolidated `SHA256SUMS.txt` artifact and checksum-gated first-run instructions for unnotarized maintainer previews.

### Security

- Kept certificate-free first launch explicitly checksum-gated, restricted quarantine removal to `/Applications/CodexMeter.app`, and separated Ed25519 update authentication from Apple first-install trust.

## [0.1.0] - 2026-08-27

### Added

- Native macOS menu bar popover and Settings interface.
- Incremental local Codex JSONL discovery, parsing, normalization, and SQLite persistence.
- Today, week, month, and locally observable all-time token totals.
- Launch at Login, data rebuild/clear controls, and privacy-safe opt-in diagnostics.
- Universal 2 ZIP/DMG release pipeline, checksums, CI, and release documentation.
- Resumable 10,000/100,000-event stress coverage and fail-closed public-release verification.
- Local-only Homebrew Tap verification for maintainer preview builds.
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
