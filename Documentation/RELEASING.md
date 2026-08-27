# Releasing CodexMeter

## Certificate-free stable release

CodexMeter can publish a stable release without an Apple Developer ID or Microsoft publisher certificate. “Stable” describes the tested application and immutable release process; it does not mean the packages are trusted by Apple Gatekeeper or Microsoft SmartScreen.

Required maintainer access:

- GitHub write permission for the source, public releases, update-feed, and personal Homebrew Tap repositories
- The Sparkle Ed25519 private key in the login Keychain under account `HechoLP`
- A clean source worktree whose immutable `vVERSION` tag points exactly to `HEAD`

Never store certificate exports, Apple credentials, the Sparkle private key, notary credentials, or Keychain profiles in the repository. Only the Sparkle public key belongs in `Config/Info.plist` and `Config/Release.env`.

Run the stable release gate from the tagged commit:

```bash
Scripts/release_stable.sh
```

The command verifies the matching tag, clean worktree, release notes, and public release repository. It then builds an ad-hoc-signed Universal 2 app, packages ZIP and DMG files, writes per-artifact SHA-256 files and `SHA256SUMS.txt`, verifies every packaged app, and creates a signed Sparkle appcast. Hardened Runtime is intentionally disabled because an ad-hoc-signed host cannot reliably load the separately signed Sparkle framework under library validation.

The verifier requires an ad-hoc signature, rejects an Apple certificate authority, checks that Hardened Runtime is absent, and validates the app metadata, empty entitlement allowlist, embedded Sparkle framework, Universal 2 architectures, archive contents, and checksums. `Scripts/generate_appcast.sh` separately verifies the feed signature, archive signature, byte length, and download URL.

## Unified macOS and Windows release

Both platforms use the same immutable `vVERSION` tag and the same public release in `HechoLP/CodexMeter-Releases`.

1. Merge the reviewed release commit to `main` after CI passes.
2. Create and push `vVERSION` at that exact commit. Never move or replace a published tag.
3. Run `Scripts/release_stable.sh` on the tagged commit for the macOS ZIP, DMG, checksums, and signed appcast.
4. Wait for the Windows Release workflow. It tests, formats, packages, smoke-tests x64, verifies both package hashes, and uploads x64/ARM64 artifacts to the workflow run. It does not create a release in the source repository.
5. Download the exact Windows workflow artifact; do not rebuild or rename it.
6. Create one stable public GitHub Release at `vVERSION` and upload the macOS and Windows archives, per-artifact checksums, both checksum manifests, and `appcast.xml`.
7. Confirm every asset is anonymously downloadable before publishing the exact same signed `appcast.xml` on the public `update-feed` branch.

The configured release repository and feed branch can be overridden only when both are intentionally supplied:

```bash
export CODEXMETER_RELEASE_REPOSITORY="OWNER/PUBLIC-RELEASE-REPOSITORY"
export CODEXMETER_UPDATE_FEED_BRANCH="update-feed"
```

## First-install trust disclosure

The macOS build is ad-hoc signed and not Apple-notarized. The Windows build is not publisher-signed. Release notes and installation pages must require checksum verification before users bypass quarantine or SmartScreen.

For macOS, document only this app-scoped command after the verified app is copied to Applications:

```bash
xattr -dr com.apple.quarantine /Applications/CodexMeter.app
open /Applications/CodexMeter.app
```

Do not advertise these packages as Apple-trusted or Microsoft-trusted. SHA-256 verifies the first download; Sparkle Ed25519 signatures authenticate later macOS updates. Homebrew installation also verifies the exact published ZIP checksum.

## Homebrew Cask

The public Cask lives in `HechoLP/homebrew-tap`.

1. Publish the exact verified macOS ZIP at `vVERSION` before changing the Cask.
2. Update `Casks/codexmeter.rb` with the published URL, version, and exact ZIP SHA-256.
3. Keep `auto_updates true`, the macOS 14 requirement, and the certificate/notarization caveat.
4. Run `brew style`, `brew audit --cask --online HechoLP/tap/codexmeter`, and a clean install/uninstall cycle.
5. Verify the installed app version, build number, architecture, updater metadata, first-run icon-only state, Settings window, refresh animation, and live totals.

The personal Tap provides convenient installation and checksum-based artifact integrity; it does not make the app Apple-trusted. Homebrew 6 does not provide the former `--no-quarantine` option.

`Scripts/install_homebrew_local.sh` creates an ephemeral local-only Cask backed by an already verified ZIP for maintainer testing.

## Optional Apple-trusted release

If a Developer ID Application certificate, Team ID, and notarytool Keychain profile become available later, use:

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CODE_SIGN_TEAM_ID="TEAMID"
export NOTARY_PROFILE="codexmeter-notary"
Scripts/release_public.sh
```

That optional path additionally enforces Developer ID signing, Hardened Runtime, Team ID, notarization, stapling, and Gatekeeper acceptance. It is not required for the certificate-free stable release.

## Rollback

Withdraw the affected public release, restore the previous signed appcast, and document any local-database compatibility implications. Never rebuild an old version or rewrite a published tag; issue a new patch version instead.
