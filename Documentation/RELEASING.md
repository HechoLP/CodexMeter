# Releasing CodexMeter

## Prerequisites

- A `Developer ID Application` certificate in the login Keychain
- A notarytool Keychain profile created locally with `xcrun notarytool store-credentials`
- The Apple Developer Team ID associated with the signing certificate
- GitHub write permission for tags and releases

Do not store certificate exports, Apple credentials, notary private keys, or Keychain profiles in the repository.

## Build and verify without release credentials

```bash
Scripts/release.sh
```

This produces an ad-hoc signed Universal 2 app in the per-user build cache plus ZIP, DMG, and SHA-256 files under `Artifacts/`. The cache staging location avoids cloud-file-provider metadata that can invalidate macOS code signatures. Gatekeeper and notarization remain intentionally incomplete.

## Signed and notarized public build

```bash
export CODE_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)"
export CODE_SIGN_TEAM_ID="TEAMID"
export NOTARY_PROFILE="codexmeter-notary"
Scripts/release_public.sh
```

The public command fails closed unless all three values are present. It requires a Developer ID signature, Hardened Runtime, the expected Team ID, an empty entitlement allowlist, notarization, stapling, Gatekeeper acceptance, matching bundle metadata, Universal 2 architectures, ZIP/DMG checksums, and verification of each packaged app.

After verification, confirm the version in `Config/Release.env`, the Git tag, artifact names, and release notes match. Create the tag and GitHub Release only after the final independent audit passes. `Scripts/release.sh` remains a local, ad-hoc-signed candidate command and can never satisfy the public gate.

## Rollback

Delete or mark the affected GitHub Release as a pre-release, publish the previous verified artifact again, and document any local-database compatibility implications. Never rewrite a published tag silently.
