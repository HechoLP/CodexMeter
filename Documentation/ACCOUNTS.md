# Codex accounts

CodexMeter can save your own ChatGPT logins and apply a selected login to Codex. Switching is always user-initiated; it never rotates accounts when usage limits are reached.

## Use

1. Open CodexMeter from the menu bar. The account menu sits above **Token Usage** and **Codex Limits**, visible from either tab without opening Settings.
2. Open the account menu and choose **Save Current Account** if your login is not saved yet. It stays in this Mac’s Keychain.
3. Choose **Add Account…** and complete Codex’s browser sign-in with another account. The account window shows registration progress and Cancel; registration uses a temporary, private Codex home and does not replace your current login.
4. Open the account menu and select a saved account. Finish your running work, then confirm **Quit Codex & Switch**. CodexMeter requests normal termination, applies the saved login, and reopens Codex. It never force-quits the desktop or other Codex clients.

The current saved login is shown in the popover header and checked in the account menu. **Manage Accounts…** opens the separate account window for saving or removing logins. Account controls are no longer a Settings category.

Removing an entry removes its saved Keychain copy; it does not sign out of Codex. Up to 12 accounts can be saved. The current account is identified from the local login file, not inferred from its email. Equal emails in different workspaces remain separate entries.

## Supported configuration

- A vendor-signed Codex desktop installed in `/Applications/ChatGPT.app` or `/Applications/Codex.app`, with one of these desktops running while registering or starting a switch.
- The default `~/.codex` login location and Codex’s `file` credential storage. CodexMeter checks the running desktop app-server’s effective home, including a shell-provided `CODEX_HOME` and its `HOME` fallback. A custom home, keyring/auto credential backend, uninspectable desktop, or conflicting managed login policy stops the operation without editing the active login.
- Complete ChatGPT logins. API keys and externally managed access-token sessions are not imported.
- Other CLI, IDE, or desktop Codex processes must be closed. Standard `codex` and platform-named `codex-*-apple-darwin` executables are detected. Arbitrarily renamed clients and remote clients are outside this switcher’s supported configuration.
- Process checks use kernel owner and command metadata when macOS cannot expose an executable path. Unrelated terminal login processes, browser helpers, and widgets do not block switching. Live Codex candidates with an unavailable path still block; an unidentified live process produces a separate verification error. Nothing is force-quit by these checks.

If the selected login has expired or been revoked, Codex may ask you to sign in again. **Switch** also works when the desktop is signed out and its login file is absent, so an existing saved account can be restored. A malformed or unsafe file is never treated as an absent file.

## Credential handling

Saved logins use a dedicated, non-synchronizing macOS login Keychain item. Keychain’s access controls remain intact. Because CodexMeter releases are ad-hoc signed, a new build can cause macOS to ask permission to access an entry created by an earlier build. Do not disable Keychain protection to suppress the prompt.

Browser registration is delegated to the verified, bundled Codex CLI. Its temporary home is user-only (`0700`), and is removed after the login child exits. Cancellation terminates only that owned child, waits for exit, and then removes that directory. A process crash or power loss can leave an owner-only temporary directory until macOS cleans temporary files; it is never uploaded or logged.

Before replacement, CodexMeter preserves the departing account’s latest login in Keychain, rechecks that clients are stopped, and compares the active file with the bytes it read. The replacement is staged privately (`0600`) and published atomically. A missing login uses no-clobber publication, so a concurrently created login wins. Account operations from multiple CodexMeter instances are serialized with an owner-only lock.

CodexMeter does not refresh a copied saved credential in a disposable process. After reopening, the official Codex process owns token renewal in the canonical login file. This avoids losing a rotated refresh token when a preflight network request fails. CodexMeter checks saved credential shape and identity, but does not claim remote authentication succeeded before Codex uses the login.

The local token database is unchanged by account switching. Its totals are still this Mac’s observed history, not a per-account ledger. Account-limit and optional profile snapshots are cleared on switching, and results from an older account request are discarded.

## Native surface

Accounts inherits the existing Quiet Instrument design: semantic system typography and label colors, SF Symbols, dividers, and native controls. It introduces no new theme or design tokens.

- The popover uses a compact native account menu shared by both top-level tabs. Long account names truncate in the label beside **Switch** and remain available in its help text; duplicate emails include a workspace suffix. Extra accounts expand the menu rather than the popover. Busy operations show progress, and errors remain readable below the account row.
- The resizable management window opens at 560 × 400 pt, with a 500 × 300 pt minimum. Only the account list scrolls; footer actions, status, and the Keychain/restart notice remain outside it.
- Account emails allow two lines; matching emails show a workspace suffix. The current login uses both a checkmark and **Current** text. Switching and removal require native confirmation alerts.
- Busy operations disable account changes. During registration, **Cancel** remains available in the footer. Switch and removal controls include the account email in their accessibility labels.
- The management window uses primary-label error text beside a red warning symbol labeled **Error** for accessibility. The popover uses primary-label error text with a warning symbol below the account row. Both remain readable in either appearance and never rely on color alone.

## Verification boundary

Core tests use synthetic credentials, isolated fixture directories, and mocked login/desktop operations. Optional integration tests check the installed desktop's signature, effective login location, and configuration without changing its login, and exercise Keychain with a uniquely named synthetic item that is removed afterward.

Native layout tests render the production Accounts view with synthetic empty, populated, long-email, error, and registration-in-progress states in light and dark appearances at both window sizes (20 combinations). The test bitmap uses a fixed 2× pixel resolution. Text recognition inspects both the full viewport and the unchanged footer region so small captions are not dependent on full-image recognition, while still requiring their complete text. A clipped-notice negative control checks that dictionary correction does not complete missing safety text. They check footer actions, complete status/safety text, and viewport bounds, and assert that rendering never saves or replaces a login or operates Codex. These captures are synthetic SwiftUI renders, not signed-in user screenshots; they do not establish VoiceOver reading order, keyboard focus behavior, or increased-contrast coverage, which require interactive checks.

Additional popover tests cover both top-level tabs, light and dark appearances, and six account states (empty, populated, long email, error, busy, and 12 saved accounts). They verify that the switch control and full errors fit, no scrolling is added, and rendering never changes credentials or operates Codex. Other popover tests inject a synthetic account store instead of accessing the developer’s Keychain.

A real two-account browser login, Keychain authorization prompt, and restart/switch must still be validated interactively before a public release; automated tests must never change the developer’s running Codex login.
