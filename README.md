# CodexMeter ◈ — Know where your Codex tokens went.

> Local Codex token usage, always one click away in your macOS menu bar.

[![CI](https://img.shields.io/github/actions/workflow/status/HechoLP/codex-meter/ci.yml?branch=main&style=flat-square&label=CI&color=0a0a0c)](https://github.com/HechoLP/codex-meter/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-0a0a0c?style=flat-square)](https://support.apple.com/macos)
[![Release](https://img.shields.io/badge/release-v0.1.0%20preview-6e5aff?style=flat-square)](https://github.com/HechoLP/CodexMeter/releases/tag/v0.1.0)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white)](Package.swift)
[![License: MIT](https://img.shields.io/badge/license-MIT-6e5aff?style=flat-square)](LICENSE)

<img src="Assets/README/codexmeter-hero.png" alt="CodexMeter hero featuring the actual app popover and local token totals" width="100%" />

<p align="center"><sub>The app popover shown above is an actual CodexMeter screen.</sub></p>

Tiny, native macOS 14+ menu bar app that turns **local Codex session history** into clear token totals. Today, this week, this month, and all locally available time stay one click away—without an account login, API key, browser cookie, telemetry, or cloud sync.

## Why

- **Glanceable totals.** See input, cached input, output, and total tokens without leaving the menu bar.
- **Honest accounting.** Cumulative snapshots are normalized into increases instead of being added repeatedly.
- **Local by design.** Prompts, responses, source code, credentials, and raw session paths are not stored in CodexMeter's database.
- **Native and quiet.** Swift and SwiftUI, no third-party runtime, no Dock icon, and no background network traffic.

## Install

### Requirements

- macOS 14 Sonoma or later
- Local Codex session history under `~/.codex`

### Direct download

Homebrew is not required. Download [CodexMeter 0.1.0](https://github.com/HechoLP/CodexMeter/releases/tag/v0.1.0), then:

1. Open `CodexMeter-0.1.0.dmg`.
2. Drag `CodexMeter.app` into **Applications**.
3. Control-click the installed app and choose **Open** on the first launch.

The ZIP asset contains the same Universal 2 app for manual installation. SHA-256 checksum files are included with both downloads.

This preview is ad-hoc signed because a Developer ID certificate and Apple notarization profile are not yet available. macOS may ask you to confirm the first launch; if it remains blocked, use **System Settings → Privacy & Security → Open Anyway**. A future stable release will use Developer ID signing and notarization.

## First run

1. Launch CodexMeter after Codex has created local session history.
2. Select the diamond meter in the menu bar.
3. Open **Settings** to choose the displayed period, refresh mode, menu bar elements, and launch-at-login behavior.
4. Use **Refresh** whenever you want an immediate reconciliation.

No Codex account sign-in is required.

## Features

- Today, week, month, and locally observable all-time totals
- Input, cached input, output, and total-token breakdowns
- Automatic file-event refresh with a lightweight one-minute fallback
- Manual, 30-second, one-minute, and five-minute refresh modes
- Incremental JSONL ingestion with transactional SQLite checkpoints
- Duplicate, replay, partial-line, truncation, and same-inode rewrite protection
- Resumable 32 MiB / roughly five-second import slices for large histories
- Native menu bar popover, Settings window, VoiceOver labels, and keyboard-accessible controls
- Optional Launch at Login through macOS Service Management
- Secure local-history clearing with a persistent re-import cutoff
- No notifications, advertising, analytics, or cloud account

## How token counting works

```text
Codex session JSONL
  → contained source discovery
  → bounded incremental reader
  → cumulative snapshot normalization
  → transactional SQLite storage
  → menu bar totals
```

Codex token-count events are cumulative snapshots. CodexMeter derives component-wise increases and ignores repeated snapshots. Cached input is a subset of input and is never added twice:

```text
Total = Input + Output
Cached Input ⊆ Input
```

## Data sources

CodexMeter reads JSONL files only inside:

- `~/.codex/sessions`
- `~/.codex/archived_sessions`

It does not use an official account-usage API and does not scan unrelated folders.

## Accuracy and limitations

- **All Time** means the oldest token record still present in local Codex session history through now.
- Deleted logs cannot be reconstructed.
- Activity from another Mac is not included unless its session history exists locally.
- A future Codex session-schema change may require a CodexMeter update.
- Ambiguous counter baselines and malformed records are reported as partial rather than guessed.

## Roadmap

Codex is the first supported data source. Future releases are planned to expand CodexMeter into a multi-service local usage meter, including **Claude** and other AI coding assistants where reliable local usage data is available. Support will be added service by service while preserving CodexMeter's local-first privacy model.

## Privacy

CodexMeter performs no network requests. It stores normalized counts, timestamps, SHA-256-derived identifiers, keyed continuity fingerprints, and parser checkpoints. It does **not** store or log prompts, responses, reasoning text, source code, tool input or output, terminal output, raw session paths, model names, project paths, authentication tokens, or `~/.codex/auth.json`.

The Application Support directory is owner-only (`0700`); the SQLite database, lock, and fingerprint-key files are owner-only (`0600`). See [Privacy](Documentation/PRIVACY.md) for the complete boundary.

## macOS permissions

| Capability | Required? | Why |
| --- | :---: | --- |
| Full Disk Access | No | Reads only supported files under `~/.codex`. |
| Accessibility | No | Does not control other apps. |
| Screen Recording | No | Does not inspect the screen. |
| Keychain access | No | Does not read Codex credentials. |
| Launch at Login approval | Optional | Used only when automatic launch is enabled. |

## Settings

| Pane | Controls |
| --- | --- |
| General | Launch at Login, refresh mode, week start |
| Appearance | Period, metric, number style, icon/text visibility, popover details |
| Usage | Accounting semantics and cached-input explanation |
| Data | Source status, database statistics, rebuild, clear history |
| Advanced | Privacy-safe diagnostics and log folder |

## Build from source

```bash
git clone https://github.com/HechoLP/CodexMeter.git
cd CodexMeter
swift test
swift run CodexMeter
```

Build and verify the Universal 2 local candidate:

```bash
Scripts/release.sh
```

Maintainers with a Developer ID Application certificate and notarization profile use:

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CODE_SIGN_TEAM_ID="TEAMID"
export NOTARY_PROFILE="codexmeter-notary"
Scripts/release_public.sh
```

## Troubleshooting

- **No usage found:** launch Codex at least once and check that `~/.codex/sessions` contains JSONL files.
- **Statistics look incomplete:** use **Settings → Data → Rebuild Statistics**.
- **Launch at Login is blocked:** open macOS **System Settings → General → Login Items**.
- **Database safety limit reached:** review the local totals, then use **Clear Local History** if they are no longer needed.

See the complete [Troubleshooting guide](Documentation/TROUBLESHOOTING.md).

## Documentation

- [Architecture](Documentation/ARCHITECTURE.md)
- [Privacy](Documentation/PRIVACY.md)
- [Releasing](Documentation/RELEASING.md)
- [Troubleshooting](Documentation/TROUBLESHOOTING.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## Acknowledgements

README presentation inspired by [CodexBar](https://github.com/steipete/CodexBar). CodexMeter is an independent implementation focused on local Codex token accounting.

## Disclaimer

CodexMeter is an unofficial utility and is not affiliated with or endorsed by OpenAI. Codex is a trademark of OpenAI.

## License

MIT © CodexMeter contributors. See [LICENSE](LICENSE).
