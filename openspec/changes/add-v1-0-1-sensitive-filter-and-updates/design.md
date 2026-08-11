## Context

V1.0.0 runs the existing `SensitiveContentDetector` before persisting copied text.
The detector correctly recognizes sensitive patterns, but users cannot knowingly
retain locally stored technical text that contains those patterns. V1.0.1 keeps the
detector and its safe default, while adding a narrowly scoped control for users who
accept the storage risk.

The same release introduces runtime version display and direct updates. The app is a
sandboxed macOS application, so updates must not add network access to the main
clipboard process or implement custom bundle replacement.

## Goals / Non-Goals

**Goals:**

- Preserve sensitive filtering for new and upgraded installations unless the user
  explicitly disables it.
- Persist the setting and apply it to each captured text item immediately.
- Show bundle-derived application name, version, and build number in a dedicated
  About & Updates settings category.
- Use Sparkle 2 for scheduled and manual update checks from the fixed HTTPS appcast,
  with signed GitHub Releases assets.
- Keep a failed, cancelled, or rejected update from affecting clipboard monitoring,
  history data, settings, or the currently installed app.

**Non-Goals:**

- Do not alter sensitive-content recognition rules, the history database schema, or
  its storage location.
- Do not add cloud sync, analytics, accounts, channels, forced updates, a custom
  installer, custom signing logic, or GitHub Releases API polling.
- Do not claim that local history storage is encrypted.

## Decisions

### Persist a safe-by-default setting

`UserDefaultsConfig` SHALL expose `filterSensitiveContent`. Its value SHALL be
`true` when no value exists, including after an upgrade from V1.0.0. The Privacy
settings UI SHALL label the control “过滤敏感内容” and explain that detected
passwords, tokens, and identity information are skipped while it is enabled.

The first request to turn the setting off SHALL require a confirmation that the
history database is currently unencrypted and that sensitive content could be stored
locally. Cancelling SHALL leave the value enabled. Re-enabling SHALL take effect
without another confirmation.

`ClipboardMonitor` SHALL obtain the current setting for every text capture rather
than caching it during initialization. When enabled, it SHALL use the existing
detector and skip matching text without logging its payload. When disabled, it SHALL
skip only the detector gate and retain the existing reader cleanup, empty-content,
classification, deduplication, and repository persistence flow. This does not permit
truncation: internal newlines, quotes, URLs, Chinese text, and Emoji SHALL remain
intact after the existing allowed cleanup.

Clipboard payloads SHALL never be written to logs, regardless of whether filtering is
enabled, disabled, matched, or bypassed. Logging may report only non-sensitive
metadata needed for diagnostics.

### Read version information from the running bundle

An `AppVersionProviding` protocol and Bundle-backed implementation SHALL provide the
application display name, `CFBundleShortVersionString`, and `CFBundleVersion`.
`SettingsView` SHALL receive this provider so it is testable. The About &
Updates UI SHALL not hard-code `1.0.1`; it SHALL display a localized equivalent of
`版本 1.0.1（构建 2）` using runtime values.

### Delegate update mechanics to Sparkle

`AppDelegate` SHALL own the app's single `UpdateService`, backed by one Sparkle
standard updater controller, and inject it into settings. The service SHALL expose only
the UI state needed for manual checks: availability, in-progress state, automatic
check state, and a user-readable status/error. The manual check button SHALL be
disabled while a check is in progress. Sparkle's standard scheduler SHALL perform
automatic checks; the UI SHALL only request foreground manual checks.

Because the application is normally dockless (`LSUIElement`), the Sparkle standard
user-driver delegate SHALL declare gentle scheduled-reminder support and temporarily
make the update session visible in the Dock without disabling automatic checks or
overriding the user's persistent Dock preference. Sparkle's standard UI SHALL remain
responsible for update download, verification, installation, cancellation, and relaunch.

`SUFeedURL` SHALL be the fixed URL
`https://peibinliang.github.io/MacPasteHistory/appcast.xml`. The app SHALL NOT call
the GitHub Releases API. The appcast enclosure SHALL use an HTTPS GitHub Release URL
for the matching ZIP, contain Sparkle's EdDSA signature, and identify version `1.0.1`
and build `2` for this release.

Sparkle SHALL validate the update's signature and application code signing before
installation. The EdDSA private key SHALL remain only in protected publisher
storage; it SHALL NOT be committed, placed in the appcast, uploaded as a release
asset, or printed to CI logs. Only the required public key may be shipped in the app.

The release app and update ZIP SHALL use Developer ID signing and SHALL complete
Apple notarization before distribution. The update capability SHALL preserve the
existing deployment target of macOS 14.0 and bundle identifier
`com.peibin.MacPasteHistory`; generated project and Release-bundle validation SHALL
verify both values.

### Gate remote release publication on explicit approval

Release preparation MAY generate local signed/notarized artifacts, checksums,
release notes, appcast content, and a publication checklist. Uploading GitHub Release
assets or publishing the appcast is a remote mutation and SHALL occur only after
documented explicit user approval. Without that approval, the work SHALL stop at the
local artifacts and checklist.

### Preserve the sandbox boundary

The main app SHALL retain App Sandbox and `com.apple.security.network.client` set to
`false`. Sparkle's Installer Launcher XPC, Downloader XPC, and required Mach lookup
exceptions SHALL be configured following Sparkle's sandbox guidance. The Downloader
XPC, rather than the clipboard process, SHALL retrieve the appcast, release notes,
and update ZIP. Release builds and entitlement validation SHALL prove the embedding
and entitlement configuration.

## Data Flow

### Text capture

1. `ClipboardMonitor` detects a new pasteboard change after existing restore, pause,
   blocked-app, and content-type gates pass.
2. `ClipboardReader` performs the existing permitted text cleanup.
3. The monitor reads `filterSensitiveContent` at capture time.
4. If enabled and the detector matches, the monitor skips persistence without
   logging copied text. If disabled, it bypasses only this detector check.
5. Existing classification, deduplication, local repository persistence, and history
   change notification proceed for eligible text.

### Update check and installation

1. Sparkle checks the fixed appcast on its standard automatic schedule or after a
   user requests a manual check.
2. It compares the appcast build number with the running `CFBundleVersion`.
3. For an available update, Sparkle presents its standard UI and, after user consent,
   downloads the signed GitHub Release ZIP.
4. Sparkle validates the HTTPS source, EdDSA signature, and application code signing.
5. Only after successful validation does Sparkle replace and restart the app. App
   Support history and UserDefaults remain outside the app bundle and are retained.

## Risks / Trade-offs

- Disabling filtering allows a user to store sensitive clipboard data locally. The
  default, explicit confirmation, and concise privacy copy make this an informed
  decision without altering detection rules.
- Sparkle adds framework and XPC entitlement complexity. Release verification must
  inspect the generated app bundle and exercise a real installed upgrade.
- Network, appcast, download, signature, or installation failures may occur. They
  must be surfaced as understandable update status while all existing app behavior
  remains available.

## Migration Plan

1. Add the preference key with a missing-value default of `true`; no database
   migration is required.
2. Update version metadata to marketing version `1.0.1` and monotonically increasing
   build `2`.
3. Add Sparkle package, embedding, sandbox configuration, and public update key.
4. Build, test, and validate generated Xcode references and release entitlements.
5. Sign and notarize the release app, create a ZIP preserving app metadata, generate
   its EdDSA signature, and prepare local release artifacts plus a publication
   checklist. Only after documented explicit user approval, upload the release assets
   and publish a valid appcast that references already-uploaded HTTPS assets.
6. Test automatic and manual update from a real V1.0.0 installation. Confirm that
   cancellation and all failure modes retain V1.0.0 and its user data.

Rollback removes the new UI and updater integration while retaining a safely ignored
preference key. A failed update never replaces the current app, so no history or
settings rollback is necessary.

## Open Questions

- None. The appcast URL, version, build number, distribution destination, and
  sandbox boundary are fixed by the approved V1.0.1 design.
