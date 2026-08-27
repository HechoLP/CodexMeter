# Product

<!-- impeccable:product-schema 1 -->

## Platform

macOS 14 or later. CodexMeter is a native menu bar utility distributed directly as a signed and notarized application when release credentials are available.

## Stack

Swift, SwiftUI, AppKit, Foundation, Swift Concurrency, SQLite, OSLog, CoreServices file events, and ServiceManagement. Runtime dependencies outside macOS are not allowed.

## Users

People who use Codex on a Mac and want to answer, with one menu bar click, how many input, cached input, output, and total tokens are visible in their local Codex history for today, this week, this month, and all time.

## Product Purpose

CodexMeter turns local Codex session token events into a fast, durable usage snapshot. Success means the menu bar appears immediately, the values remain accurate across restarts and duplicate file events, and normal operation has negligible CPU, memory, disk, and network impact.

## Positioning

CodexMeter measures locally observable token consumption. It does not present account quota, claim to be an official OpenAI usage dashboard, or copy CodexBar's branding, assets, or layout.

## Operating Context

The app runs quietly in the macOS menu bar, discovers supported JSONL session history under the user's Codex data directory, imports existing records in the background, and incrementally follows later writes. The default reporting calendar uses the current system calendar and time zone.

## Capabilities and Constraints

- Show input, cached input, output, and total tokens for Today, This Week, This Month, and locally observable All Time.
- Treat cached input as a subset of input when that matches the observed Codex schema; never add it to total a second time.
- Persist normalized usage and parser checkpoints in SQLite under Application Support.
- Avoid prompts, responses, source code, terminal output, and authentication data.
- Operate without telemetry, analytics, cloud sync, notifications, a local web server, or a separately installed runtime.
- Remain responsive during large historical imports and tolerate unknown, malformed, partial, truncated, rotated, and duplicated input.
- Keep launch-at-login optional and use the current ServiceManagement API.

## Brand Commitments

The product name is CodexMeter. Its interface is compact, quiet, precise, and native to macOS. A small diamond-meter mark may identify the product, but purple/blue AI gradients, neon, decorative glass, giant cards, and dashboard-like chrome are out of scope.

## Evidence on Hand

- A detailed production brief supplied with the initial repository request.
- Local Codex CLI and session data available for schema validation on the development Mac.
- No approved logo, screenshot, testimonials, usage benchmark, or official OpenAI affiliation claim.

## Product Principles

1. Accuracy and duplicate prevention outrank visual flourish.
2. Show cached data immediately; perform heavy work asynchronously.
3. Read and retain only the minimum data required for token accounting.
4. Prefer macOS frameworks and predictable native behavior.
5. Keep every public claim narrower than the evidence.

## Accessibility & Inclusion

Support VoiceOver labels, keyboard navigation, system appearance, sufficient contrast, Reduce Motion, and non-color-only status communication.
