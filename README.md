# CodexMeter ◈ — Know where your coding tokens went.

> Local Codex and Claude Code token usage, one click away on macOS.

[![CI](https://img.shields.io/github/actions/workflow/status/HechoLP/CodexMeter/ci.yml?branch=main&style=flat-square&label=CI&color=0a0a0c)](https://github.com/HechoLP/CodexMeter/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-0a0a0c?style=flat-square)](https://support.apple.com/macos)
[![macOS Release](https://img.shields.io/badge/macOS-v1.3.1-6e5aff?style=flat-square)](Documentation/ReleaseNotes/1.3.1.md)
[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-F05138?style=flat-square&logo=swift&logoColor=white)](Package.swift)
[![License: MIT](https://img.shields.io/badge/license-MIT-6e5aff?style=flat-square)](LICENSE)

<img src="Assets/README/codexmeter-hero.png" alt="CodexMeter hero featuring the actual app popover and local token totals" width="100%" />

<p align="center"><sub>The app popover shown above is an actual CodexMeter screen.</sub></p>

Tiny native macOS menu bar app that turns **local Codex and Claude Code session history** into separate token totals. Codex also offers a separate, opt-in, memory-only ChatGPT account-total view. Claude is opt-in: after you enable it and add the Claude Code account, CodexMeter can show the documented five-hour and weekly limits without reading or storing Claude credentials.

## Why

- **Glanceable totals.** See input, cached input, output, and total tokens without leaving the menu bar.
- **Plan around limits.** See the nearest Codex or Claude Code quota windows, reset countdowns, and an explicitly labeled even-use pace estimate before starting a long task.
- **Honest accounting.** Cumulative snapshots are normalized into increases instead of being added repeatedly.
- **Local by design.** Prompts, responses, source code, credentials, and raw session paths are not stored in CodexMeter's database.
- **Native and quiet.** SwiftUI and AppKit, no Dock window, and no telemetry.

## Install

### macOS requirements

- macOS 14 Sonoma or later
- Local Codex session history under `~/.codex`

### Homebrew Tap

Install the certificate-free stable release from the public personal Tap:

```bash
brew install --cask HechoLP/tap/codexmeter
```

To update an existing installation, including releases with automatic updates enabled:

```bash
brew update
brew upgrade --cask --greedy HechoLP/tap/codexmeter
```

Homebrew verifies the published ZIP against the Cask's SHA-256 checksum. Because the app is ad-hoc signed and not Apple-notarized, macOS still blocks its first launch. After confirming that Homebrew installed `HechoLP/tap/codexmeter`, remove quarantine from this app only and open it:

```bash
xattr -dr com.apple.quarantine /Applications/CodexMeter.app
open /Applications/CodexMeter.app
```

Homebrew 6 no longer provides the old `--no-quarantine` installation option. The explicit command above keeps the trust decision limited to `/Applications/CodexMeter.app`.

### Direct download

CodexMeter v1.3.1 is available from the public [CodexMeter repository](https://github.com/HechoLP/CodexMeter/releases/tag/v1.3.1) as a certificate-free Universal 2 DMG and ZIP. The app uses an ad-hoc signature rather than an Apple Developer ID certificate, so macOS will not trust the first launch automatically. Verify the downloaded DMG and follow the one-time first-run steps below.

This is the stable 1.3.1 application release, but it is not Apple-trusted or notarized. Sparkle update archives and the update feed are separately authenticated with Ed25519 signatures, while first-install trust is established by checking the published SHA-256 manifest.

### macOS에서 인증서 없는 릴리스를 처음 실행할 때

공식 GitHub 릴리스에서 DMG와 `SHA256SUMS.txt`를 같은 폴더에 받은 뒤, 먼저 체크섬을 확인하세요. 다음 명령이 `OK`를 출력하지 않으면 앱을 실행하지 마세요.

```bash
cd ~/Downloads
grep ' CodexMeter-1.3.1.dmg$' SHA256SUMS.txt | shasum -a 256 -c -
open CodexMeter-1.3.1.dmg
```

열린 DMG에서 `CodexMeter.app`을 `Applications` 폴더로 복사합니다. 체크섬이 일치하고 공식 릴리스임을 확인한 경우에만 아래 명령으로 해당 앱의 격리 속성을 제거하고 실행하세요.

```bash
xattr -dr com.apple.quarantine /Applications/CodexMeter.app
open /Applications/CodexMeter.app
```

`xattr` 명령은 이 앱에 대한 macOS의 다운로드 격리 검사를 제거합니다. 출처가 다르거나 체크섬이 일치하지 않는 파일에는 사용하지 마세요. Developer ID 서명과 Apple 공증을 마친 정식 릴리스에서는 이 단계가 필요하지 않습니다.

## First run

1. Launch CodexMeter after Codex has created local session history.
2. To add Claude Code, open **Settings → Services**, enable Claude Code, and explicitly add the account already signed in to the official Claude CLI. If no account is signed in, run `claude` in your terminal and sign in there first, then choose **Add Account**.
3. Select the diamond meter in the macOS menu bar, then choose **Codex** or **Claude**.
4. Use **Refresh** whenever you want an immediate reconciliation. Claude limits appear after Claude Code completes a response.

Local totals require no account connection. On macOS, **Settings → Usage & Privacy → Use ChatGPT account totals** can optionally use the existing Codex sign-in to match ChatGPT profile totals.

## Features

- **Codex and opt-in Claude Code** local usage, selected directly in the menu after the Claude account is added. Each service has independent history, refresh, and data controls; token totals are never mixed. See [Claude Code support](Documentation/CLAUDE.md).
- User-selected Codex account switching: save logins in this Mac’s Keychain, add another account through Codex’s browser sign-in, and explicitly quit/switch/reopen Codex. No automatic quota-based rotation. See [account setup and supported configurations](Documentation/ACCOUNTS.md).

- Live Today total from the selected service's local records always stays in the primary summary
- Current week/month through the server snapshot date and lifetime totals when explicitly enabled
- Week, month, and **Local History** totals from local Codex records when account totals are off
- Input, cached input, output, and total-token breakdowns
- macOS drill-down views for account limits, Today/7D/30D charts, models, projects, sessions, and verified sub-agent relationships
- Read-only Codex 5-hour/weekly/additional limit windows and reset credits, plus documented Claude Code five-hour and weekly limit percentages
- First-screen limit previews with low-quota text warnings, reset countdowns, and even-use pace; detailed Limits can also show a current-window run-out estimate
- Model-aware API-equivalent cost estimates using the current official price catalog; these are estimates, not bills or subscription charges
- Privacy-minimized project and session analytics with keyed project identifiers and image counts only—never attachment contents
- Automatic file-event refresh plus manual, 30-second, 1-, 2-, 5-, 15-, and 30-minute modes
- Bounded incremental JSONL ingestion with durable SQLite checkpoints
- Duplicate, replay, partial-line, truncation, and same-inode rewrite protection
- Resumable 32 MiB / roughly five-second import slices for large histories
- Native menu bar popover and Settings window
- Optional launch at login through macOS Service Management
- Daily signed update checks with a manual check-for-updates action
- Secure local-history clearing with a persistent re-import cutoff
- No notifications, advertising, or telemetry

## How token counting works

```text
Codex session JSONL
  → contained source discovery
  → bounded incremental reader
  → cumulative snapshot normalization
  → local normalized event cache
  → menu bar totals
```

Codex token-count events are cumulative snapshots. CodexMeter derives component-wise increases and ignores repeated snapshots. The local total uses the inclusive input count plus output:

```text
Total = Input + Output
```

`Cached Input` is the portion of `Input` that Codex served from cache rather than processing from scratch. Because it is already included in `Input`, CodexMeter shows it as a separate auditable breakdown but does not add it to Total a second time. The derived local Total therefore matches the raw Codex `total_tokens` meaning: `Input + Output`.

When optional profile sync is enabled, lifetime comes directly from the account-wide profile statistic and the dated day/week/month values are derived from its daily buckets. They are never combined with the local component breakdown.

## Data sources

CodexMeter reads JSONL files only inside:

- `~/.codex/sessions`
- `~/.codex/archived_sessions`

Optional profile sync also reads only `tokens.access_token` and `tokens.account_id` from `~/.codex/auth.json` for a fixed read-only request to `https://chatgpt.com/backend-api/wham/profiles/me`. Credentials and the response are held only in memory and are not written to CodexMeter's database or logs. This is a non-public ChatGPT endpoint and may change.

The macOS **Limits** view uses the signed Codex app-server's read-only `account/rateLimits/read` RPC. The last successful limit response is held in memory only. This provider never changes accounts, consumes reset credits, or makes purchases. The separate **Accounts** feature changes the local Codex login only after the user confirms a switch.

Claude account discovery uses the read-only `claude auth status` command; signing in stays entirely inside Claude Code. After the user enables Claude and adds that account, CodexMeter installs a small local status-line helper and records only the documented five-hour/weekly percentages and reset timestamps. Claude credentials remain owned by Claude Code. Any prior user status-line command is preserved and restored when the integration is disabled or disconnected.

For local analytics, CodexMeter stores canonical model IDs, a keyed HMAC of each normalized working directory, the final project-folder name, hashed session relationships, and numeric image counts. Image counts describe the whole retained session after the local-history cutoff, rather than only the selected chart range. It does not store full working-directory paths, session text, image bytes, MIME payloads, or attachment contents.

## Accuracy and limitations

- **Local History** means the oldest token record still present in local Codex session history through now.
- Optional **Lifetime** profile totals are account-wide and can include older, cloud, or other-device activity that is absent from this Mac.
- Profile statistics can lag behind real time; CodexMeter shows the server's exact `stats_as_of` date instead of presenting delayed data as current.
- Deleted logs cannot be reconstructed in **This Mac** or **Local History** totals.
- Activity from another computer is absent from local totals unless its session history exists locally; optional account totals can include it.
- A future Codex session-schema change may require a CodexMeter update.
- Ambiguous counter baselines and malformed records are excluded rather than guessed.
- API-equivalent cost uses the bundled current pricing snapshot and is marked unavailable for unknown models or incomplete pricing metadata. It is not an OpenAI bill.
- Project names are folder basenames and can be identical; their stored identities remain separate keyed hashes.

## Roadmap

Codex and **Claude Code local session logs** are supported. Claude five-hour and weekly limits are available after explicit account setup. Claude web/mobile token totals, account switching, attachment counts, and cost estimates are not included. Additional service integrations will be added where reliable usage data is available, preserving the local-first privacy model.

CodexBar's current feature families have been reviewed as a product reference, but CodexMeter keeps an independent interface and a narrower trust boundary. See the [CodexBar feature strategy](Documentation/CODEXBAR_STRATEGY.md) for what is adopted, adapted, deferred, or intentionally excluded.

## Privacy

Local accounting and analytics remain on-device. The app can check a signed Sparkle update feed. Optional profile sync sends the existing Codex access token and account ID only to `chatgpt.com` to retrieve aggregate profile statistics. CodexMeter does **not** store or log prompts, responses, reasoning text, source code, tool input or output, terminal output, raw session paths, full project paths, remote profile responses, or attachment contents. Credentials never enter the usage database or logs. Explicitly saved Codex accounts remain in the local Keychain; Claude sign-in remains in Claude Code's credential store and is never copied into CodexMeter.

The Application Support directory is owner-only (`0700`); the SQLite database, lock, and fingerprint-key files are owner-only (`0600`). See [Privacy](Documentation/PRIVACY.md) for the complete boundary.

## Platform permissions

| Capability | Required? | Why |
| --- | :---: | --- |
| Full Disk Access | No | Reads supported local sessions under `.codex` and `.claude/projects` (or `CLAUDE_CONFIG_DIR/projects`). |
| Accessibility | No | Does not control other apps. |
| Screen Recording | No | Does not inspect the screen. |
| Profile credential access | Optional | Reads only the access token and account ID after the user enables account totals. |
| Saved Codex accounts | Optional | Explicit registration stores a login in this Mac’s Keychain; a confirmed switch replaces the local Codex login and restarts Codex. |
| Claude account | Optional | Reads the official Claude CLI's signed-in status only; sign-in stays in Claude Code. CodexMeter stores only connection consent and documented limit percentages/reset times. |
| Launch at Login | Optional | Enabled only by the user in Settings. |

## Settings

Switch Codex accounts directly from the account menu at the top of the menu-bar popover. Choose a saved account, or **Add Account…** / **Manage Accounts…** without opening Settings. Switching still asks before restarting Codex. See [Accounts](Documentation/ACCOUNTS.md).

| Pane | Controls |
| --- | --- |
| General | Launch at Login, refresh mode, week start, and macOS automatic updates |
| Appearance | Period, metric, number style, icon/text visibility, popover details |
| Usage | Account totals, read-only limits, cost/projects/sessions/agent/attachment visibility, privacy boundary, and accounting semantics |
| Data | Local/limit/pricing source status, database statistics, rebuild, clear history |
| Advanced | Privacy-safe diagnostics, log folder, and account-limit provider status |

## Build from source

```bash
git clone https://github.com/HechoLP/CodexMeter.git
cd CodexMeter
swift test
swift run CodexMeter
```

Build and verify a certificate-free Universal 2 release candidate:

```bash
Scripts/release_unsigned.sh
```

For a clean, matching release tag, build the verified artifacts and signed Sparkle feed together:

```bash
Scripts/release_stable.sh
```

These commands produce an ad-hoc-signed ZIP, DMG, per-file checksums, and `SHA256SUMS.txt` without using an Apple certificate. Maintainers who later add a Developer ID Application certificate and notarization profile can use the optional Apple-trusted workflow:

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CODE_SIGN_TEAM_ID="TEAMID"
export NOTARY_PROFILE="codexmeter-notary"
Scripts/release_public.sh
```

## Troubleshooting

- **No usage found:** launch Codex at least once and check that `~/.codex/sessions` contains JSONL files.
- **Totals are lower than expected:** use **Settings → Data → Rebuild Statistics** after Codex finishes writing its session files.
- **Launch at Login is blocked:** open macOS **System Settings → General → Login Items**.
- **Database safety limit reached:** review the local totals, then use **Clear Local History** if they are no longer needed.

See the complete [Troubleshooting guide](Documentation/TROUBLESHOOTING.md).

## Documentation

- [Architecture](Documentation/ARCHITECTURE.md)
- [CodexBar feature strategy](Documentation/CODEXBAR_STRATEGY.md)
- [Privacy](Documentation/PRIVACY.md)
- [Releasing](Documentation/RELEASING.md)
- [Troubleshooting](Documentation/TROUBLESHOOTING.md)
- [Changelog](CHANGELOG.md)
- [Contributing](CONTRIBUTING.md)
- [Security](SECURITY.md)

## Acknowledgements

README presentation inspired by [CodexBar](https://github.com/steipete/CodexBar). Automatic updates use [Sparkle](https://sparkle-project.org/). CodexMeter is an independent implementation focused on local Codex token accounting.

## Disclaimer

CodexMeter is an unofficial utility and is not affiliated with or endorsed by OpenAI. Codex is a trademark of OpenAI.

## License

MIT © CodexMeter contributors. See [LICENSE](LICENSE).
