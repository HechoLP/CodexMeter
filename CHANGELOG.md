# Changelog

All notable changes to CodexMeter will be documented in this file.

## [Unreleased]

## [1.4.6] - 2026-09-06

### Fixed

- Account switching no longer aborts when an unrelated `codex` process is alive anywhere on the machine. Modern Codex keeps an idle background app-server running after its window closes, and editor extensions and remote sessions spawn their own — the switch would quit and reopen the desktop app but never apply the saved login, showing only a small "Another Codex process is still running" note. The process gate now blocks a switch only while a Codex process actually holds `~/.codex/auth.json` open (checked by device and inode); `CodexLoginFile.replace` still refuses to overwrite a login that changed under it, so the switch stays safe. The blocked-state message now points at CLI sessions and editor extensions.

## [1.4.5] - 2026-09-05

### Fixed

- Eliminated the last remaining compiler warning in the project: `SettingsToggleRow` forwarded its get/set closures into a SwiftUI `Binding` initializer that only infers Sendable safety for closure literals written at the call site, not forwarded parameters. Restructured to build the `Binding` from literals inside `body`. No behavior change; `swift build` now produces zero warnings.

## [1.4.4] - 2026-09-05

### Changed

- Trimmed Settings to the text that carries real information: merged and shortened notes that repeated what an adjacent row or dialog already said (account-totals, breakdown, and history-clearing notes), and moved a misplaced diagnostics note back next to the section it explains. No preference, control, or behavior changed.
- The About pane now leads with the app icon, name, and version — matching native macOS About panels — instead of a one-line tagline.

## [1.4.3] - 2026-09-05

### Fixed

- The Codex and Claude Code Settings panes now match: Codex's Account section is a label/value row like Claude's (showing the saved login or "Signed in to the Codex app"), and Codex's header card has the same refresh button as Claude's. Real differences (Claude's on/off toggle, the Codex-only Limits section) are unchanged.
- Settings no longer reads the real Keychain-backed saved-login vault during automated tests; the account store is now injected, with `swift test` using an in-memory vault.

## [1.4.2] - 2026-09-05

### Fixed

- Settings action rows ("Check for Updates…", "Open Log Folder", "Add Account", "Disconnect", "Open Data Folder", "Rebuild Statistics", "Clear Local History") are now bordered icon buttons instead of bare accent-colored text, so they read as clickable controls instead of floating links.

## [1.4.1] - 2026-09-05

### Fixed

- Provider rows in Settings show the actual OpenAI and Claude marks instead of generic terminal/sparkles icons, on a neutral bordered chip rather than a flat color fill.
- Removed the sidebar sort-menu button; it added nothing with six entries and read as a straight copy of the app it was inspired by.

## [1.4.0] - 2026-09-04

### Changed

- Rebuilt the Settings window: a tinted icon sidebar with a search field, and flat row groups instead of boxed forms. Codex and Claude Code each get their own sidebar entry with account, limits, analytics, and local-data controls, so the window is no longer scoped to one provider and its title tracks the selected section.

## [1.3.1] - 2026-09-04

### Fixed

- Claude limit cards no longer read "Weekly · Weekly"; the window name ("Weekly" / "5 hours") is shown once, matching the Codex limit layout.
- The popover footer shows a consistent "Updated <relative>" line on both providers. The ChatGPT account-totals snapshot date stays in the Token History header instead of replacing the footer's freshness indicator.
- Claude local usage now connects even when the status-line limits helper cannot be installed; the Limits section reports the helper problem instead of the whole integration going unavailable.

## [1.3.0] - 2026-09-04

### Added

- Claude Code local token usage with Today/week/month/history totals, model/project/session analytics, and sub-agent relationships.
- A persistent Codex / Claude Code selector in the menu. Each provider has a separate database and history cutoff; Codex account data never appears as Claude usage.
- Claude response-ID deduplication and streaming-counter reconciliation, including cache-read and cache-creation input accounting.
- Read-only Claude five-hour and weekly limits through the documented status-line fields, with existing user status-line configuration preserved and restored.
- A bundled owner-only Claude limits helper that stores no prompts, paths, session identifiers, or credentials.

### Changed

- Replaced the provider segmented control with compact, logo-first Codex and Claude Code tabs, and removed redundant popover branding so usage information appears first.
- Show the connected Claude account and plan in the menu header so it lines up with the Codex account row.
- Made Claude Code an explicit Services integration: enable it, add the account already signed in to the `claude` CLI, then access its token and limit views.
- Resolve the `claude` command from the launch `PATH` as well as the common install locations, and report a clearer message when it is not found.

### Fixed

- Keep the last known Claude account and limits visible during temporary CLI failures, while clearly marking expired or old limit snapshots instead of presenting them as current.
- Distinguish Claude accounts in the same organization, cancel in-flight account setup when Claude is turned off, and fail safely if the existing status-line configuration cannot be restored.
- Restore the user's original Claude status line on disconnect even when they changed it themselves while CodexMeter was connected; the first captured value is no longer overwritten on a later reinstall.
- Run the Claude status-line install and byte-comparison off the main thread so the periodic account refresh never blocks the menu.
- Removed the in-app Claude sign-in launcher, which could not complete the CLI's paste-code flow and left a stranded process; sign in with `claude` in a terminal, then choose **Add Account**.
- Never offer or imply an API-equivalent cost for Claude, where official prices are not published; the cost metric, labels, and toggle are Codex-only rather than showing an "unavailable" estimate.
- Refresh previously opened 7D/30D analysis after imports, calendar changes, rebuilds, and history clearing; discard superseded in-flight analytics results.
- Keep cleared Claude responses excluded when later streaming blocks or copied transcripts appear, including across restarts and rebuilds.
- Show the token chart when cost estimates are turned off, even if Cost was previously selected.

### Scope

- Claude web/mobile account-wide totals, account switching, attachment counts, and API-equivalent cost estimates are not included. Claude credentials are never read or copied.

## [1.2.0] - 2026-08-31

### Added

- User-selected Codex account switching from the menu-bar account menu, with a separate account-management window and explicit restart confirmation.
- Local, non-synchronizing Keychain storage for up to 12 saved logins and isolated browser sign-in through the verified Codex CLI.

### Changed

- Separate Token Usage and Codex Limits tabs, with Weekly limits first and shorter supporting text.
- Explicit back navigation and content-fitting analytic layouts that keep filters at the top and avoid oversized blank headers.
- Native hover, focus, and reduced-motion behavior without changing token accounting or the usage database.

### Fixed

- Unrelated terminal, browser-helper, and widget processes no longer incorrectly block account switching.
- Account identity and error text remain readable in compact popovers; duplicate emails identify their workspace.

### Verification limits

- Automated account tests use synthetic credentials. A real two-account browser login and desktop restart/switch have not been exercised end to end; finish active Codex work before confirming a switch.

## [1.1.5] - 2026-08-29

### Changed

- Rebuilt the menu popover around a provider-first reading order: Codex status, account limits, token usage, history, detailed destinations, and utility actions.
- Enlarged important rows and restored vertical period comparisons so labels and large token totals are easier to scan.
- Added reset-credit context to the account-limit overview when the existing setting is enabled.

## [1.1.4] - 2026-08-29

### Changed

- Replaced the vertical token breakdown and period lists with compact horizontal comparisons so the overview can be understood without scrolling.
- Increased the normal popover overview height while preserving the bounded scroll fallback for smaller screens and larger accessibility text.

## [1.1.3] - 2026-08-29

### Changed

- Reorganized the menu bar overview into clearly labeled Local Usage, Account Limits, Token History, and Explore categories.
- Added visible source and period context to category headings and exposed the category structure as VoiceOver headings.

## [1.1.2] - 2026-08-29

### Fixed

- Prevented the menu bar popover's scrollable usage body from collapsing to zero height, which could leave only the title and footer visible after opening the app.

## [1.1.1] - 2026-08-29

### Changed

- Refocused CodexMeter on its native macOS app, with macOS-only product, architecture, privacy, security, installation, and release documentation.
- Simplified the stable release gate and CI pipeline so all automated verification targets the supported macOS application.

### Removed

- Removed the Windows application, tests, packaging scripts, CI job, release workflow, installation guide, and preview release notes from the current product tree.
- Removed Windows packages from the current release path. Historical tags and changelog entries remain intact as an immutable record of earlier releases.

## [1.1.0] - 2026-08-29

### Added

- Added first-screen Codex limit previews with reset countdowns, low-quota text warnings, and even-use pace, plus current-window run-out estimates in the detailed Limits screen.
- Added fixed 2-, 15-, and 30-minute refresh choices alongside the existing automatic, manual, and shorter intervals.
- Added quick access to Usage, Projects, and Sessions plus a compact actions menu for updates, the OpenAI status page, GitHub, and quit.

### Changed

- Reorganized the macOS popover around progressive disclosure: glanceable local usage and limits stay on the first screen, while detailed analytics remain one click away.

### Fixed

- Isolated preview and development builds from the production usage database so an unreleased schema migration cannot make the installed app stop reading local usage.

## [1.0.6] - 2026-08-28

### Fixed

- Corrected local totals on macOS and Windows to use `Input + Output`; cached input is already included in Input and is now shown only as an auditable breakdown instead of being counted twice.

## [1.0.5] - 2026-08-28

### Changed

- Clarified in the README, Settings, and popover/detail tooltips that the local Activity Total intentionally counts cached input a second time (on top of Input) and will read higher than the token count Codex itself displays, so this is not miscounting.

## [1.0.4] - 2026-08-28

### Changed

- Consolidated macOS and Windows release assets, release links, and the signed Sparkle update feed into the public `HechoLP/CodexMeter` repository.
- Added a dual-published 1.0.4 bridge feed so installations through 1.0.3 can move to the consolidated update location without losing signed-update continuity.

## [1.0.3] - 2026-08-28

### Added

- Added an explicitly enabled macOS view of ChatGPT account-wide profile-day, current-week, current-month, and lifetime totals while keeping the existing local component breakdown separate.
- Added secure, memory-only profile retrieval from a fixed ChatGPT endpoint using only the current Codex access token and account ID.

### Fixed

- Made delayed server snapshots display their exact profile date instead of presenting them as live local usage.
- Refresh account totals immediately after opt-in or a week-start change, discard in-flight results after opt-out, and clear stale account values when credentials expire.
- Invalidate and recalculate account week/month totals at local midnight, after wake, and after clock or time-zone changes so a prior calendar period is never shown under the new label.
- Kept menu-bar account totals available even while local session history is still loading.
- Reject a stable release when the Windows package version diverges from the macOS release version.

### Security

- Reject unsafe credential files, redirects, oversized responses, malformed statistics, duplicate dates, invalid token counts, and authentication failures without logging credentials or response bodies.
- Keep remote account statistics out of SQLite, UserDefaults, Keychain, and diagnostics.

## [1.0.2] - 2026-08-28

### Changed

- Replaced the compact tab strip with a persistent, keyboard-navigable settings sidebar that names and describes each category.
- Enlarged the macOS Settings window to a resizable 980×680pt default with an 840×560pt minimum, using a new saved-frame key so previous small windows do not override the new layout.
- Added a structured **Information** page with application version, build number, local-data scope, privacy statement, update control, and project links.
- Preserve the selected settings category, scroll position, and assistive-technology context when the Settings window is reopened.

## [1.0.1] - 2026-08-28

### Fixed

- Separated menu-bar text visibility from its content format so **Show token text** can be enabled from the default icon-only presentation.
- Migrated the legacy `Icon Only` display value to an independent icon-on/text-off preference without changing the first-launch appearance.
- Renamed the local-only lifetime row to **Local History** and clarified why it can differ from the ChatGPT account's cloud lifetime total.

## [1.0.0] - 2026-08-28

### Added

- Published the first stable CodexMeter release for macOS 14+ and Windows 10/11 under one `v1.0.0` tag.
- Added a native Windows notification-area application with x64 and ARM64 self-contained packages, local Codex accounting, persistent settings, tests, CI, and certificate-free release artifacts.
- Added a clean-tag stable release gate that builds the Universal 2 macOS packages, verifies checksums and metadata, and creates the Ed25519-signed Sparkle update feed without an Apple certificate.
- Added a unified Windows tag workflow that tests, formats, packages, smoke-tests, verifies hashes, and uploads release artifacts without creating a mismatched source-repository release.

### Fixed

- Coalesced overlapping Windows refreshes, invalidated changed-file caches on file-system events, and retried unterminated final JSONL records after they become complete.
- Rebuilt Windows session watchers safely, including when `.codex` is created after launch, and kept the last good snapshot when a non-fatal source read fails.
- Made Windows settings saves atomic, prevented repeated startup-registry writes, and made the Settings window reopen reliably without duplicate event handlers.
- Derived Windows package versions from the project metadata so CI and release artifacts cannot silently reuse an older release version.
- Added continuous refresh-button rotation on Windows while a reconciliation is running, matching the existing bounded-turn macOS feedback.
- Bounded macOS streaming fingerprint verification, made it resume across refreshes, charged its reads to the refresh budget, and rejected resumed state after same-size rewrites even when modification time is restored.
- Bounded the Windows raw-event cache, per-source reads, per-pass reads, and accepted history size; deduplicated hard-linked sources and retained every changed path within the watcher debounce window.

### Changed

- Upgraded the Windows build and test target to .NET 10 LTS.
- Documented macOS and Windows as stable, certificate-free packages with mandatory first-download checksum verification and explicit Gatekeeper/SmartScreen limitations.

### Security

- Prevented large committed prefixes and duplicate source aliases from causing unbounded repeated work or process-memory growth.
- Kept source-file mutation checks, event deduplication, signed macOS updates, owner-only local storage, and release-context verification fail-closed.

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
