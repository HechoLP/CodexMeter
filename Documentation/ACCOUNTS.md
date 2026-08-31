# Codex accounts

CodexMeter can save your own ChatGPT logins and apply a selected login to Codex. Switching is always user-initiated; it never rotates accounts when usage limits are reached.

## Use

1. Open the Codex desktop app. In CodexMeter, choose **Codex Limits → Accounts**, **More → Codex Accounts**, or **Settings → Accounts**.
2. Choose **Save Current Account** to keep the current login in this Mac’s Keychain.
3. Choose **Add Account** and complete Codex’s browser sign-in with another account. Registration uses a temporary, private Codex home and does not replace your current login. Cancel stops only this registration process.
4. Choose **Switch** beside a saved account, finish your running work, and confirm **Quit Codex & Switch**. CodexMeter requests normal termination, applies the saved login, and reopens Codex. It never force-quits the desktop or other Codex clients.

Removing an entry removes its saved Keychain copy; it does not sign out of Codex. Up to 12 accounts can be saved. The current account is identified from the local login file, not inferred from its email. Equal emails in different workspaces remain separate entries.

## Supported configuration

- A vendor-signed Codex desktop installed in `/Applications/ChatGPT.app` or `/Applications/Codex.app`, with one of these desktops running while registering or starting a switch.
- The default `~/.codex` login location and Codex’s `file` credential storage. CodexMeter checks the running desktop app-server’s effective home, including a shell-provided `CODEX_HOME` and its `HOME` fallback. A custom home, keyring/auto credential backend, uninspectable desktop, or conflicting managed login policy stops the operation without editing the active login.
- Complete ChatGPT logins. API keys and externally managed access-token sessions are not imported.
- Other CLI, IDE, or desktop Codex processes must be closed. Standard `codex` and platform-named `codex-*-apple-darwin` executables are detected. Arbitrarily renamed clients and remote clients are outside this switcher’s supported configuration.

If the selected login has expired or been revoked, Codex may ask you to sign in again. **Switch** also works when the desktop is signed out and its login file is absent, so an existing saved account can be restored. A malformed or unsafe file is never treated as an absent file.

## Credential handling

Saved logins use a dedicated, non-synchronizing macOS login Keychain item. Keychain’s access controls remain intact. Because CodexMeter releases are ad-hoc signed, a new build can cause macOS to ask permission to access an entry created by an earlier build. Do not disable Keychain protection to suppress the prompt.

Browser registration is delegated to the verified, bundled Codex CLI. Its temporary home is user-only (`0700`), and is removed after the login child exits. Cancellation terminates only that owned child, waits for exit, and then removes that directory. A process crash or power loss can leave an owner-only temporary directory until macOS cleans temporary files; it is never uploaded or logged.

Before replacement, CodexMeter preserves the departing account’s latest login in Keychain, rechecks that clients are stopped, and compares the active file with the bytes it read. The replacement is staged privately (`0600`) and published atomically. A missing login uses no-clobber publication, so a concurrently created login wins. Account operations from multiple CodexMeter instances are serialized with an owner-only lock.

CodexMeter does not refresh a copied saved credential in a disposable process. After reopening, the official Codex process owns token renewal in the canonical login file. This avoids losing a rotated refresh token when a preflight network request fails. CodexMeter checks saved credential shape and identity, but does not claim remote authentication succeeded before Codex uses the login.

The local token database is unchanged by account switching. Its totals are still this Mac’s observed history, not a per-account ledger. Account-limit and optional profile snapshots are cleared on switching, and results from an older account request are discarded.

## Native surface

Accounts inherits the existing Quiet Instrument design: semantic system typography and label colors, SF Symbols, dividers, and native controls. It introduces no new theme or design tokens.

- The resizable window opens at 560 × 400 pt, with a 500 × 300 pt minimum. Only the account list scrolls; footer actions, status, and the Keychain/restart notice remain outside it. Settings reuses the same view without a duplicate heading.
- Account emails allow two lines; matching emails show a workspace suffix. The current login uses both a checkmark and **Current** text. Switching and removal require native confirmation alerts.
- Busy operations disable account changes. During registration, **Cancel** remains available in the footer. Switch and removal controls include the account email in their accessibility labels.
- Errors use primary-label text beside a red warning symbol labeled **Error** for accessibility, so the message remains readable in both appearances and never relies on color alone.

## Verification boundary

Core tests use synthetic credentials, isolated fixture directories, and mocked login/desktop operations. Optional integration tests check the installed desktop's signature, effective login location, and configuration without changing its login, and exercise Keychain with a uniquely named synthetic item that is removed afterward.

Native layout tests render the production Accounts view with synthetic empty, populated, long-email, error, and registration-in-progress states in light and dark appearances at both window sizes (20 combinations). They check footer actions, complete status/safety text, and viewport bounds, and assert that rendering never saves or replaces a login or operates Codex. These captures are synthetic SwiftUI renders, not signed-in user screenshots; they do not establish VoiceOver reading order, keyboard focus behavior, or increased-contrast coverage, which require interactive checks.

A real two-account browser login, Keychain authorization prompt, and restart/switch must still be validated interactively before a public release; automated tests must never change the developer’s running Codex login.
