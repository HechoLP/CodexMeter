# Releasing CodexMeter

## Certificate-free preview prerequisites

- The Sparkle Ed25519 private key in the login Keychain under account `HechoLP` when generating the update feed
- GitHub write permission for tags and releases

Do not store certificate exports, Apple credentials, the Sparkle private key, notary private keys, or Keychain profiles in the repository. The Sparkle public key is expected in `Config/Info.plist` and `Config/Release.env`.

## Certificate-free preview build

```bash
Scripts/release_unsigned.sh
```

This produces an ad-hoc-signed Universal 2 app in the per-user build cache plus ZIP, DMG, per-artifact SHA-256 files, and a consolidated `SHA256SUMS.txt` under `Artifacts/`. It does not read or use an Apple signing identity. Hardened Runtime is intentionally disabled for this build because an ad-hoc-signed host cannot reliably load the separately signed Sparkle framework under library validation. The verifier requires the host to be ad-hoc signed, rejects an Apple certificate authority, checks that Hardened Runtime is absent, and still validates the app, framework, architectures, metadata, and packaged checksums.

Certificate-free artifacts must remain clearly labeled as unnotarized previews. Require verification against the uploaded `SHA256SUMS.txt`, identify the quarantine-removal effect explicitly, and limit the command to `/Applications/CodexMeter.app`. Do not advertise the preview as Apple-trusted or copy its checksum into a public Cask.

Generate the signed update feed only on a maintainer Mac that has the Sparkle key:

```bash
Scripts/generate_appcast.sh
```

The command validates the feed signature, archive signature, byte length, and download URL before writing `Artifacts/appcast.xml`.

## Optional Apple-trusted public build

This path additionally requires a `Developer ID Application` certificate, the associated Apple Developer Team ID, and a notarytool Keychain profile. It is not required for the certificate-free preview above.

Public builds are accepted only from a clean worktree whose `vVERSION` tag points exactly to `HEAD`, with matching release notes under `Documentation/ReleaseNotes/`. The configured GitHub release repository must also be public. This prevents a binary built from different source from being published under an existing version.

If releases are hosted separately from the source repository, set both values before building:

```bash
export CODEXMETER_RELEASE_REPOSITORY="OWNER/PUBLIC-RELEASE-REPOSITORY"
export CODEXMETER_UPDATE_FEED_BRANCH="update-feed"
```

The build derives and embeds the appcast URL from those values. Create and review the release commit, update `Config/Release.env` and the release notes, commit everything, then create `vVERSION` at that exact commit before running the public workflow. Never move or replace an existing published tag.

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CODE_SIGN_TEAM_ID="TEAMID"
export NOTARY_PROFILE="codexmeter-notary"
Scripts/release_public.sh
```

The public command fails closed unless all three values are present. It requires a Developer ID signature, Hardened Runtime, the expected Team ID, an empty host-app entitlement allowlist, notarization, stapling, Gatekeeper acceptance, matching bundle metadata, Universal 2 architectures, embedded Sparkle verification, ZIP/DMG checksums, a signed appcast, and verification of each packaged app.

After verification, confirm the version in `Config/Release.env`, the immutable Git tag, artifact names, appcast enclosure URL, and release notes match. Upload `appcast.xml`, the ZIP, DMG, per-artifact checksums, and `SHA256SUMS.txt`, then publish the exact same signed file as `appcast.xml` on the configured dedicated `update-feed` branch. The branch must contain no private key material. Create the GitHub Release from the already verified tag only after the final independent audit passes. `Scripts/release_unsigned.sh` may produce only a clearly labeled certificate-free preview and can never satisfy the Apple-trusted release gate.

## Homebrew Cask

The repository intentionally does not contain a public Cask while only maintainer previews exist. For a public Homebrew release:

1. Run `Scripts/release_public.sh` and confirm the ZIP passes Developer ID, notarization, stapling, Gatekeeper, metadata, architecture, entitlement, and checksum verification.
2. Publish that exact ZIP at tag `vVERSION`; do not rebuild it after calculating the Cask checksum.
3. Create a Cask in the public Tap using the published ZIP URL, `version`, and `sha256`.
4. Keep that Cask only in the public `HechoLP/homebrew-tap` repository after the release gate passes.
5. Run `brew style`, `brew audit --cask --online HechoLP/tap/codexmeter`, and a clean install/uninstall cycle.
6. Only then change the README wording from the source-build path to the public `brew install --cask HechoLP/tap/codexmeter` path.

For local maintainer verification, `Scripts/install_homebrew_local.sh` generates an ephemeral local-only Cask backed by the already verified ZIP and runs the normal Homebrew installer. This path does not create or advertise a public Cask and does not make an ad-hoc-signed build Apple-trusted.

## Rollback

Delete or mark the affected GitHub Release as a pre-release, restore the previous signed appcast, and document any local-database compatibility implications. Never rebuild an old version or rewrite a published tag; issue a new patch version instead.
