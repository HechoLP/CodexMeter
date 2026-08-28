# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS 14 or later and Windows 10/11. CodexMeter is a native menu bar or notification-area utility distributed as a certificate-free application, with stronger platform signing and notarization used when release credentials are available.

## Stack

The macOS app uses Swift, SwiftUI, AppKit, Foundation, Swift Concurrency, SQLite, OSLog, CoreServices file events, ServiceManagement, and Sparkle. The Windows app uses .NET 10, WPF, and native file-system notifications. Public packages are self-contained and do not require a separately installed runtime.

## Users

People who use Codex on macOS or Windows and want to see the input, cached input, output, and total tokens visible in their local history. macOS users can also explicitly enable a separate account-wide profile view.

## Product Purpose

CodexMeter turns local Codex session token events into a fast, durable usage snapshot. Success means the menu bar or notification-area item appears immediately, values remain accurate across restarts and duplicate file events, and normal operation has negligible CPU, memory, disk, and network impact. Optional macOS account totals stay isolated from local accounting and are labeled with the server snapshot date.

## Positioning

CodexMeter measures locally observable token consumption and can optionally display aggregate ChatGPT profile statistics on macOS. It does not present account quota, claim to be an official OpenAI usage dashboard, or copy CodexBar's branding, assets, or layout.

## Operating Context

The app runs quietly in the macOS menu bar or Windows notification area, discovers supported JSONL session history under the user's Codex data directory, imports existing records in the background, and incrementally follows later writes. The default reporting calendar uses the current system time zone and selected week start.

## Capabilities and Constraints

- Show input, cached input, output, and total tokens for Today, This Week, This Month, and locally observable history.
- Preserve input, cached input, and output as separate auditable local components, and never add optional account totals to local values.
- Persist normalized usage and parser checkpoints in owner-only SQLite on macOS; keep Windows usage events in process memory.
- Avoid prompts, responses, source code, terminal output, and stored authentication data.
- Keep optional macOS account retrieval opt-in, fixed-destination, aggregate-only, and memory-only.
- Operate without telemetry, analytics, notifications, a local web server, or a separately installed runtime.
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

## Accessibility & Inclusion

Support VoiceOver labels, keyboard navigation, system appearance, sufficient contrast, Reduce Motion, and non-color-only status communication.
