# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS

## Stack

The app uses Swift, SwiftUI, AppKit, Foundation, Swift Concurrency, SQLite, OSLog, CoreServices file events, ServiceManagement, and Sparkle. Public packages are Universal 2 macOS applications and do not require a separately installed runtime.

## Users

People who use Codex on macOS and want to see the input, cached input, output, and total tokens visible in their local history. They can also inspect local models/projects/sessions, API-equivalent cost estimates, read-only account limits, and an explicitly enabled account-wide profile view.

## Product Purpose

CodexMeter turns local Codex session token events into a fast, durable usage snapshot. Success means the menu bar item appears immediately, values remain accurate across restarts and duplicate file events, and normal operation has negligible CPU, memory, disk, and network impact. Optional account totals stay isolated from local accounting and are labeled with the server snapshot date.

## Positioning

CodexMeter measures locally observable token consumption and can optionally display aggregate ChatGPT profile statistics and read-only Codex account-limit windows. It keeps quota percentages separate from token totals, does not claim to be an official OpenAI usage or billing dashboard, and does not copy CodexBar's branding or assets.

## Operating Context

The app runs quietly on macOS 14 or later as a native menu bar utility. It discovers supported JSONL session history under the user's Codex data directory, imports existing records in the background, and incrementally follows later writes. The default reporting calendar uses the current system time zone and selected week start. Public builds are certificate-free unless stronger Apple signing and notarization credentials are available.

## Capabilities and Constraints

- Show input, cached input, output, and total tokens for Today, This Week, This Month, and locally observable history.
- Preserve input, cached input, and output as separate auditable local components, and never add optional account totals to local values.
- Persist normalized usage and parser checkpoints in owner-only SQLite.
- Avoid prompts, responses, source code, and terminal output. Authentication data never enters usage storage or logs; explicitly saved account logins use a separate local Keychain vault.
- Keep optional account retrieval opt-in, fixed-destination, aggregate-only, and memory-only.
- Read account limits only through a verified signed Codex app-server; keep the provider read-only and never expose reset-credit consumption or purchase actions.
- Let users save their own Codex logins and explicitly switch via normal desktop quit, private login replacement, and reopen. Never rotate accounts automatically based on quota; keep account state separate from local history.
- Derive current API-equivalent estimates from model token usage; unknown or incomplete pricing data remains unavailable rather than becoming zero.
- Persist only canonical model IDs, keyed project identifiers, folder basenames, session relationships, and numeric attachment metadata needed for local analytics.
- Keep normal accounting free of telemetry, analytics, notifications, a local web server, and a separately installed runtime. Explicit account registration delegates the temporary browser sign-in flow to the bundled Codex CLI.
- Remain responsive during large historical imports and tolerate unknown, malformed, partial, truncated, rotated, and duplicated input.
- Keep launch-at-login optional and use the platform-supported current-user mechanism.

## Brand Commitments

The product name is CodexMeter. Its interface is compact, quiet, precise, and native to each platform. A small diamond-meter mark may identify the product, but purple/blue AI gradients, neon, decorative glass, giant cards, and dashboard-like chrome are out of scope.

## Evidence on Hand

- A detailed production brief supplied with the initial repository request.
- Local Codex CLI and session data available for schema validation on the development Mac.
- No approved logo, screenshot, testimonials, usage benchmark, or official OpenAI affiliation claim.

## Product Principles

1. Accuracy and duplicate prevention outrank visual flourish.
2. Show cached data immediately; perform heavy work asynchronously.
3. Read and retain only the minimum data required for token accounting.
4. Prefer platform-native frameworks and predictable native behavior.
5. Keep every public claim narrower than the evidence.
6. Put glanceable status in the first screen and progressively disclose analysis instead of building one long dashboard.

## Accessibility & Inclusion

Support VoiceOver labels, keyboard navigation, system appearance, sufficient contrast, Reduce Motion, and non-color-only status communication.
