## 1. Sensitive Settings

- [x] 1.1 Add `filterSensitiveContent` to the shared settings configuration with a missing-value default of `true` and persistence tests.
- [x] 1.2 Expose the setting through `SettingsViewModel`, including a disable confirmation that clearly states sensitive text may be stored in the unencrypted local SQLite history database and leaves filtering enabled when cancelled.
- [x] 1.3 Add a UI test or documented acceptance check proving the disable confirmation contains the unencrypted local database disclosure before the user can confirm.
- [x] 1.4 Add the Privacy settings control, localized safety explanation, and immediate state feedback.
- [x] 1.5 Update `ClipboardMonitor` to read the current setting on every text capture and bypass only sensitive detection when filtering is disabled.

## 2. Capture Regression

- [x] 2.1 Add capture regression tests proving enabled filtering still skips synthetic password, token, identity, and bank-card matches and that no clipboard payload is logged.
- [x] 2.2 Add regression tests proving disabled filtering completely persists the synthetic cURL and DingTalk-style token samples, including internal newlines, quotes, URLs, Chinese text, and Emoji, while no clipboard payload is logged.
- [x] 2.3 Add regression coverage proving no clipboard payload is logged for every filter state: enabled and matched, enabled and unmatched, and disabled.
- [x] 2.4 Add a regression test proving ordinary long text remains eligible when filtering is enabled, so length is not treated as a sensitive-content rule.

## 3. About UI and Runtime Version Information

- [x] 3.1 Update application metadata to version `1.0.1` and build `2` while preserving deployment target macOS `14.0` and bundle identifier `com.peibin.MacPasteHistory`.
- [x] 3.2 Add a testable `AppVersionProviding` abstraction and Bundle-backed implementation for display name, `CFBundleShortVersionString`, and `CFBundleVersion`.
- [x] 3.3 Add an “关于与更新” settings category showing the app icon, name, runtime version/build, automatic-check state, update status, and GitHub project link.
- [x] 3.4 Add unit tests confirming the About UI state uses injected Bundle/provider values rather than a hard-coded version.

## 4. Sparkle Integration and Secure Update Behavior

- [x] 4.1 Add Sparkle 2 through Swift Package Manager and configure XcodeGen product linking and embedding for the app target.
- [x] 4.2 Add an `UpdateService` owned as a single instance by `AppDelegate`, exposing manual-check availability, in-progress state, automatic-check state, and understandable status/error.
- [x] 4.3 Configure the fixed HTTPS `SUFeedURL` as `https://peibinliang.github.io/MacPasteHistory/appcast.xml` and the Sparkle public key without adding GitHub Releases API polling or private key material.
- [x] 4.4 Connect the About & Updates manual-check button to Sparkle and prevent concurrent checks while retaining clear “already up to date” and failure feedback.
- [x] 4.5 Add focused tests for update-service state and manual-check wiring using an injected updater boundary where practical.

## 5. Sandboxing

- [x] 5.1 Keep `com.apple.security.network.client` disabled for the main app and configure Sparkle Installer Launcher XPC, Downloader XPC, and required Mach lookup exceptions per Sparkle sandbox guidance.
- [x] 5.2 Extend entitlement and generated-app validation so Release builds prove Sparkle framework/XPC embedding and the intended sandbox boundary.
- [x] 5.3 Add configuration and Release-bundle validation proving deployment target macOS `14.0` and bundle identifier `com.peibin.MacPasteHistory` remain unchanged.

## 6. Release Artifacts

- [ ] 6.1 Produce a Developer ID-signed, notarized V1.0.1 app ZIP that preserves required metadata, plus checksum and release notes.
- [ ] 6.2 Generate the Sparkle EdDSA signature without exposing the private key and prepare local signed ZIP, checksum, release notes, appcast content, and a release-publication checklist.
- [ ] 6.3 Obtain and record explicit user approval before uploading signed ZIP/checksum/release notes to GitHub Release `v1.0.1` or publishing the fixed appcast; without that approval, do not perform either remote mutation.
- [ ] 6.4 After the documented approval in 6.3, upload the approved assets and publish the valid fixed appcast only after its enclosure is available.
- [ ] 6.5 Verify appcast XML parsing, HTTPS enclosure URL, version `1.0.1`, build `2`, matching ZIP Bundle values, Developer ID signing, notarization, and valid enclosure signature.

## 7. Documentation

- [x] 7.1 Update the changelog, user guidance, privacy policy, release-preparation guide, configuration documentation, and development log with the sensitive-filter setting and update behavior.
- [x] 7.2 Document that disabling filtering may save sensitive text in the local unencrypted history database and that no clipboard data is uploaded by the feature.

## 8. End-to-End V1.0.0 → V1.0.1 QA

- [x] 8.1 Run XcodeGen, file-reference validation, unit tests, Release build, and relevant release/entitlement checks; preserve command output as release evidence.
- [ ] 8.2 Test an installed V1.0.0 app through automatic and manual discovery, download, signature validation, installation, and restart to V1.0.1.
- [ ] 8.3 Test unavailable network, HTTP 404, malformed appcast, invalid EdDSA signature, invalid code signature, and user cancellation; confirm V1.0.0 continues working and data is unchanged.
- [ ] 8.4 Verify post-upgrade clipboard monitoring, history count, favorites, settings, and shortcut preservation on Apple Silicon and the supported macOS release matrix; record any explicit Intel release decision.
