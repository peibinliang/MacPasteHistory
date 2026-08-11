## Why

V1.0.0 silently skips text that matches its existing sensitive-content rules. This
protects users by default, but it also prevents intentional local capture of useful
cURL commands, access-token URLs, and other long technical text. V1.0.1 must make
that safety control visible and reversible only after the user understands the local
storage risk.

The release also needs trustworthy runtime version information and a secure,
in-application upgrade path. Manual replacement of an app bundle is error-prone and
does not meet the intended GitHub Releases distribution workflow.

## What Changes

- Add a persisted, user-controlled sensitive-content filter that defaults to enabled
  when no preference has been stored, with a confirmation before it is disabled.
- Add an About & Updates settings surface that reads the application name, marketing
  version, and build number from the running bundle.
- Integrate Sparkle 2 for automatic and on-demand checks of the fixed HTTPS appcast;
  Sparkle is responsible for downloading, verifying, installing, and restarting for
  accepted updates.
- Add Release artifacts and verification evidence for version `1.0.1`, build `2`,
  including signed/notarized ZIP, appcast metadata, entitlement checks, and an
  installed V1.0.0-to-V1.0.1 upgrade test.

## Capabilities

### New Capabilities

- `user-controlled-sensitive-filter`: Privacy-safe, persisted user control over
  sensitive-content filtering in the clipboard capture path.
- `application-version-information`: Bundle-derived application name, version, and
  build information for the About & Updates UI.
- `github-release-automatic-updates`: Sparkle-managed, signature-validated updates
  delivered from a fixed GitHub Pages appcast and GitHub Releases assets.

### Modified Capabilities

- None. The existing sensitive-content requirement remains the baseline behavior;
  this change adds a user-approved opt-out without changing its detection rules.

## Impact

- Affected capture and settings code: `UserDefaultsConfig`, `SettingsViewModel`,
  `SettingsView`, and `ClipboardMonitor`.
- Affected app lifecycle and release configuration: `AppDelegate`, XcodeGen package
  and embedding configuration, app entitlements, and entitlement validation scripts.
- Affected tests: settings persistence/confirmation, capture regressions, bundle
  version provider, update-service state, and release/appcast verification.
- Affected documentation and release artifacts: changelog, user guidance, privacy
  policy, release-preparation guide, signed release ZIP, checksums, and appcast.
