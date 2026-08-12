## Why

Users currently need to grant Accessibility permission again after every update. Published builds keep the same bundle identifier but use ad-hoc signatures whose designated requirement is tied to a version-specific CDHash, so macOS cannot recognize the replacement as the same trusted application.

## What Changes

- Require publicly distributed app and Sparkle update builds to use a stable Developer ID Application identity and Team ID.
- Require the bundle identifier, signing identity, designated requirement, hardened runtime, entitlements, and updater identity to remain compatible across consecutive releases.
- Add an upgrade identity gate that compares an installed previous release with the release candidate before publication.
- Require notarization and an actual previous-version-to-candidate Accessibility smoke result for final release approval.
- Keep ad-hoc builds available only for local/internal QA and label them as unable to prove Accessibility permission continuity.

## Capabilities

### New Capabilities

- `stable-macos-update-identity`: Defines the distribution identity and cross-version verification required for macOS to treat an updated app as the same trusted application.

### Modified Capabilities

None.

## Impact

- Release configuration in `project.yml` and the Xcode-generated project.
- Release packaging, signature, notarization, readiness, and Sparkle verification scripts.
- Release QA records and documentation.
- External prerequisites: Apple Developer Program membership, a Developer ID Application certificate/private key, a stable Team ID, and notarization credentials. These credentials must not be committed to the repository.
