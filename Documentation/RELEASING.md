# Releasing CodexMeter

## Prerequisites

- A `Developer ID Application` certificate in the login Keychain
- A notarytool Keychain profile created locally with `xcrun notarytool store-credentials`
- The Apple Developer Team ID associated with the signing certificate
- The Sparkle Ed25519 private key in the login Keychain under account `HechoLP`
- GitHub write permission for tags and releases

Do not store certificate exports, Apple credentials, the Sparkle private key, notary private keys, or Keychain profiles in the repository. The Sparkle public key is expected in `Config/Info.plist` and `Config/Release.env`.

## Development-signed preview build

```bash
export CODE_SIGN_IDENTITY="Apple Development: Your Name (TEAMID)"
export CODE_SIGN_TEAM_ID="TEAMID"
Scripts/release.sh
```

This produces an Apple Development-signed Universal 2 app in the per-user build cache plus ZIP, DMG, and SHA-256 files under `Artifacts/`. The host app, Sparkle framework, helper app, and XPC services must all have the same Team ID; the verifier fails if any nested code is ad-hoc or signed by another team. The cache staging location avoids cloud-file-provider metadata that can invalidate macOS code signatures. Gatekeeper distribution trust and notarization remain intentionally incomplete, so this path is only for a clearly labeled preview release.

Preview artifacts are for maintainer testing only. Do not advertise them as a normal first-install download, publish Gatekeeper-bypass instructions, or copy their checksum into a public Cask. Only the signed and notarized public workflow below may produce an end-user installation artifact.

Generate the signed update feed only on a maintainer Mac that has the Sparkle key:

```bash
Scripts/generate_appcast.sh
```

The command validates the feed signature, archive signature, byte length, and download URL before writing `Artifacts/appcast.xml`.

## Signed and notarized public build

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CODE_SIGN_TEAM_ID="TEAMID"
export NOTARY_PROFILE="codexmeter-notary"
Scripts/release_public.sh
```

The public command fails closed unless all three values are present. It requires a Developer ID signature, Hardened Runtime, the expected Team ID, an empty host-app entitlement allowlist, notarization, stapling, Gatekeeper acceptance, matching bundle metadata, Universal 2 architectures, embedded Sparkle verification, ZIP/DMG checksums, a signed appcast, and verification of each packaged app.

After verification, confirm the version in `Config/Release.env`, the Git tag, artifact names, appcast enclosure URL, and release notes match. Upload `appcast.xml` alongside the ZIP, DMG, and checksum files, then publish the exact same signed file as `appcast.xml` on the dedicated `update-feed` branch. The branch must contain no private key material. Create the tag and GitHub Release only after the final independent audit passes. `Scripts/release.sh` remains a local, ad-hoc-signed candidate command and can never satisfy the public stable-release gate; it may be used only for a clearly labeled preview release.

## Homebrew Cask

The repository intentionally does not contain a public Cask while only maintainer previews exist. For a public Homebrew release:

1. Run `Scripts/release_public.sh` and confirm the ZIP passes Developer ID, notarization, stapling, Gatekeeper, metadata, architecture, entitlement, and checksum verification.
2. Publish that exact ZIP at tag `vVERSION`; do not rebuild it after calculating the Cask checksum.
3. Create a Cask in the public Tap using the published ZIP URL, `version`, and `sha256`.
4. Keep that Cask only in the public `HechoLP/homebrew-tap` repository after the release gate passes.
5. Run `brew style`, `brew audit --cask --online HechoLP/tap/codexmeter`, and a clean install/uninstall cycle.
6. Only then change the README wording from the source-build path to the public `brew install --cask HechoLP/tap/codexmeter` path.

For local maintainer verification, `Scripts/install_homebrew_local.sh` generates an ephemeral local-only Cask backed by the already verified ZIP and runs the normal Homebrew installer. This path does not create or advertise a public Cask and does not make an Apple Development-signed build a public release.

## Rollback

Delete or mark the affected GitHub Release as a pre-release, publish the previous verified artifact again, and document any local-database compatibility implications. Never rewrite a published tag silently.
