# Development Log

## 2026-08-05

### Fixed

- Replaced the standard clipboard history window with a rounded, translucent top overlay.
- Prevented global shortcut invocation from activating a normal app window and switching away from the current fullscreen Space.
- Added outside-click and Escape dismissal while preserving keyboard navigation and double-click paste behavior.

### Root Cause

- `AppDelegate` created history with a standard titled `NSWindow` and called `NSApp.activate(ignoringOtherApps:)`; macOS therefore activated the app on its own Space when invoked over a fullscreen application.

### Verification

- Added `HistoryPanelWindowTests` for nonactivating style, fullscreen auxiliary behavior, cross-Space behavior, popup level, key input support, transparency, and top-center positioning.
- Targeted tests passed with 4 tests and 0 failures; the new window module reached 96.36% line coverage.
- The final full test suite passed with 102 tests and 0 failures.
- Manual fullscreen verification remains required against representative native and third-party applications.

### Compatibility

- No database migration, data repair, new permission, or clipboard-history format change is required.

## 2026-07-02

### Added

- Initialized git repository.
- Installed and used XcodeGen to generate `MacPasteHistory.xcodeproj`.
- Added initial macOS SwiftUI app structure under `MacPasteHistory/`.
- Added menu bar status item, main window, settings window, Application Support directory setup, SQLite opening, logging, and default settings.
- Added initial unit tests for default settings.
- Added text clipboard monitoring based on pasteboard `changeCount`.
- Added plain text reading, text hash normalization, restore skip guard, and clipboard writing.
- Added SQLite migration tracking and the `clipboard_history` table.
- Added `ClipboardHistoryRepository` for text save, dedupe, search, delete, and clear operations.
- Added main panel text history list with search, previews, relative time, restore, delete, and clear actions.
- Added unit tests for text hash, pasteboard reading/writing, monitor behavior, and repository behavior.
- Added bounded history previews, friendly time formatting, detail viewing, favorite/unfavorite actions, favorites-only filtering, content type filtering, and paginated history loading.
- Added unit tests for history display formatting, favorite persistence, repository filters, repository pagination, and ViewModel filter/loading behavior.
- Added PNG/TIFF image clipboard reading, TIFF-to-PNG normalization, image file and thumbnail storage, image metadata persistence, image hash deduplication, image restore, delete cleanup, and image history previews/detail display.
- Added Finder image file copy detection through pasteboard file URLs, with non-image file URLs ignored.
- Added tests for image reading, storage limits, thumbnail creation, repository metadata, monitor image capture, recording gating, restore, and cleanup.
- Added tests for Finder image file URL reading and non-image file URL skipping.
- Added persisted total storage cap configuration and wired cleanup to use the total storage cap instead of the single-image size limit.
- Stabilized image dimension tests by generating deterministic pixel-sized bitmap fixtures.
- Added tests for total storage cap defaults and persistence.
- Added release user guide and privacy policy drafts.
- Added XcodeGen-managed entitlements wiring and Release build optimization/signing settings for local release validation.
- Added a local Release smoke-test script for sandbox entitlement, launch, text capture, image capture, and quit validation.
- Extended the Release smoke-test script to cover large text, large image metadata, and expired image startup cleanup.
- Extended the Release smoke-test script to launch a temporary installed app copy, verify restart persistence, and validate Release startup cleanup for count limits, favorite preservation, and storage caps.
- Extended the Release smoke-test script to verify oversized images are skipped without database records, original files, or thumbnail files.
- Updated the Release smoke-test script to launch the Release app with an isolated temporary App Support directory so synthetic QA data does not touch the user's real history database.
- Added an `ApplicationSupportService` override path for isolated release and test runs.
- Added `scripts/preview-release-app.sh` for repeatable local Release preview, with optional isolated data mode for manual QA.
- Added `scripts/seed-preview-data.sh` and `scripts/preview-release-app.sh --seed-preview-data` so local Release previews can launch with synthetic text and image history in an isolated App Support directory.
- Added `docs/release/manual-qa-record.md` to capture manual release evidence that cannot be proven by automation.
- Added `scripts/release-qa-baseline.sh` to generate Markdown baseline evidence for manual Release QA records.
- Added `scripts/package-release-qa-build.sh` to create a zipped Release QA package, checksum, and manifest for cross-machine compatibility testing.
- Added `scripts/verify-release-qa-package.sh` to validate QA package checksums, app bundle metadata, architectures, signing, and Sandbox entitlement before manual testing.
- Added `scripts/generate-manual-qa-fixtures.swift` to create synthetic text, code, chat, large-text, and image fixtures for manual common-app Release QA.
- Added `scripts/start-manual-release-qa-session.sh` to prepare a timestamped manual Release QA session workspace with package artifacts, verification output, baseline evidence, fixtures, and a QA record copy.
- Added `scripts/validate-manual-qa-record.sh` to catch incomplete manual Release QA records before final release approval.
- Added `scripts/validate-xcode-file-references.sh` to regenerate the Xcode project and verify Swift file references resolve to real files.
- Wired Xcode file-reference validation into Release preview, QA packaging, and Release smoke-test build entry points, with a lock around XcodeGen so concurrent release scripts do not corrupt or race project generation.
- Added `scripts/release-readiness-report.sh` to aggregate Xcode file references, Xcode authorization, signing identities, release docs, screenshot assets, manual QA record validation, and git status into a final Markdown readiness report.
- Added `scripts/prefill-manual-qa-record.sh` and wired it into manual Release QA session setup so objective build, package, signing, current-machine, and fixture fields are filled without marking manual QA scenarios as passed.
- Added `scripts/scan-privacy-log-safety.sh`, switched the central Logger wrapper to OSLog private privacy by default, and wired the scan into the release readiness report.
- Added `scripts/verify-privacy-usage-descriptions.sh` and wired Info.plist privacy usage description validation into the release readiness report.
- Added `scripts/release-install-preflight.sh` to copy a Release app into a temporary install directory, launch it with isolated sandbox-container data, verify SQLite schema initialization, and confirm quit behavior.
- Wired the Release install preflight into `scripts/release-readiness-report.sh` so the final readiness gate launches a copied Release app, verifies isolated local storage initialization, and confirms quit behavior by default.
- Wired `scripts/release-smoke-test.sh` into `scripts/release-readiness-report.sh` so the final readiness gate also runs sandbox, synthetic clipboard capture, restart persistence, large-content, oversized-image, and cleanup checks by default.
- Required explicit double-click paste evidence in the manual Release QA record and validator.
- Required manual Release QA records to retain the expected environment, common-app, and privacy/safety evidence rows.
- Scoped manual Release QA required-row validation to the matching Markdown sections so misplaced rows do not satisfy the checklist.
- Added reproducible App Icon generation and verification scripts, generated the macOS AppIcon PNG set, and wired icon verification into the release readiness report.
- Added `scripts/verify-release-screenshot-assets.sh` and wired screenshot PNG dimension validation into the release readiness report.
- Added `scripts/verify-manual-qa-fixtures.sh` and wired synthetic manual QA fixture generation validation into the release readiness report.
- Updated manual Release QA session README generation to list the required static release checks, install preflight, manual-record validation, and final readiness report in execution order.
- Added `--json-output` to `scripts/release-readiness-report.sh` so release gates can emit a machine-readable status, checks, blockers, warnings, and remaining evidence summary alongside Markdown.
- Added `--strict-final` to `scripts/release-readiness-report.sh` so final distribution checks fail when any warning remains.
- Added `scripts/verify-supported-macos-targets.sh` and wired it into release readiness checks to keep project, Info.plist, release docs, and macOS QA matrix support targets aligned.
- Added `scripts/verify-release-version-build.sh` and wired it into release readiness checks to keep Info.plist, release docs, and manual QA version/build declarations aligned.
- Added `scripts/verify-release-entitlements.sh` and wired it into release readiness checks to keep App Sandbox enabled while broad network, USB, and user-selected file access entitlements remain disabled.
- Added `scripts/verify-release-identity.sh` and wired it into release readiness checks to keep Bundle ID, product name, Info.plist path, and menu bar app identity aligned.
- Added `scripts/verify-xcode-authorization.sh` and wired release readiness Xcode authorization to its real PASS/FAIL status instead of reporting authorization as PASS when blockers exist.
- Added `scripts/verify-signing-identities.sh` and wired release readiness signing checks to report formal distribution failures and internal QA ad-hoc warnings consistently.
- Added `scripts/verify-release-app-signature.sh` and wired release readiness to verify the built Release app's signature, Team ID, Bundle ID, and Sandbox entitlement.
- Added `scripts/verify-manual-release-qa-session.sh` and wired manual QA session creation to generate `session-verification.md` for package, checksum, manifest, baseline, fixture, record, and README completeness.
- Added `--qa-session` to `scripts/release-readiness-report.sh` so final readiness checks can validate the generated manual QA session directory and warn when the session evidence is omitted.
- Added `scripts/verify-release-qa-baseline.sh` and wired manual QA session verification to validate the build, toolchain, signing, Sandbox, common-app, and remaining-evidence baseline fields.
- Added `scripts/verify-release-qa-manifest.sh` and wired manual QA session verification to validate package manifest fields, artifact paths, SHA-256 integrity, and embedded baseline evidence.
- Added the package manifest to manual QA record prefill and validation so final records reference the exact QA package manifest under test.
- Wired manual QA record validation to verify the referenced Package manifest file instead of only checking that the field is present.
- Wired manual QA record validation to reject Package manifests whose embedded baseline was generated from a dirty git worktree.
- Wired manual QA record validation to verify App path exists and matches the Packaged app listed in the Package manifest.
- Wired manual QA record validation to compare the recorded Package SHA-256 against the checksum file referenced by the Package manifest.
- Wired manual QA record validation to compare the Package verification summary against the manifest signature, Team ID, Sandbox, and checksum success result.
- Wired manual QA record validation to verify the referenced Fixture directory exists and contains the generated manual QA samples.
- Wired manual QA record validation to compare the recorded Git commit against the Package manifest commit.
- Wired manual QA record validation to compare the recorded Version / build against the Package manifest version.
- Wired manual QA record validation to compare the recorded Signing identity against the Package manifest signature, Team, and Sandbox state.
- Wired manual QA record validation to reject `Filled` placeholders in addition to `TBD` and `Not run`.
- Wired manual QA record validation to require the final Decision rows for readiness, blockers, follow-ups, and approver.
- Added OpenSpec release-change progress to `scripts/release-readiness-report.sh` so readiness reports and JSON output list the exact remaining release tasks.
- Added double-click paste from the history list: a successful restore closes the history window, reactivates the previous foreground app, and sends `Command + V`.
- Added `PasteCommandService` and tests for restore success/failure reporting plus paste command dispatch.
- Added a local release environment report script and snapshot for Xcode status, signing identities, machine architecture, macOS version, and common-app availability.
- Added `DataCleanupServiceTests` coverage for expired image file cleanup.
- Added `DataCleanupServiceTests` coverage for text count limits, image count limits, favorite-preserving image count limits, and image storage cap cleanup.
- Added `ClipboardDataClearService` and unit coverage for clearing all database records plus image and thumbnail files.
- Added `LoginItemService` using `SMAppService.mainApp` for the settings launch-at-login toggle, with service and ViewModel regression tests.
- Added reproducible release screenshot generation with synthetic, non-private App Store screenshot assets under `docs/release/screenshots/`.
- Fixed expired image cleanup so original and thumbnail files are removed before expired database rows are deleted.
- Fixed cleanup count-limit eviction so favorites count toward the configured total limit while remaining protected from deletion.
- Fixed main-list restore actions so mouse restore and Enter restore both write the selected item to the clipboard before showing feedback.
- Fixed image capture so the single-image size limit setting is read dynamically when saving images.

### Verification

- `xcodebuild build` passed for `MacPasteHistory`.
- `xcodebuild test` passed with 49 tests and 0 failures.
- `xcodebuild -configuration Release build` passed and produced a locally signed Release app.
- `codesign -d --entitlements :-` confirmed the Release app includes App Sandbox entitlements.
- `scripts/release-smoke-test.sh` passed on the current Apple Silicon Mac with a temporary installed app copy, isolated App Support directory, synthetic clipboard text, large text, PNG, large PNG, oversized-image skip, restart persistence, expired image cleanup, count-limit cleanup, favorite preservation, and storage-cap cleanup data.
- `scripts/preview-release-app.sh --help` and `scripts/preview-release-app.sh --build-only` passed, confirming the preview helper can build Release and print the current app path.
- `scripts/seed-preview-data.sh build/preview-seed-verify.*` generated an isolated preview database with 4 text items, 2 image items, and matching image/thumbnail files.
- `openspec validate prepare-release-testing-and-store-assets --strict` passed after adding the manual QA evidence template and final checklist corrections.
- Targeted `ApplicationSupportServiceTests` passed with 1 test and 0 failures after adding isolated App Support override coverage.
- Targeted `ImageStorageServiceTests` passed with 3 tests and 0 failures after adding dynamic single-image limit coverage.
- `scripts/release-environment-report.sh` confirmed Xcode is selected and licensed, the current machine is Apple Silicon, Chrome/Safari/VS Code/WeChat/DingTalk are installed, and no valid code signing identities are currently available.
- `xcodebuild -checkFirstLaunchStatus` exited with 0 after selecting `/Applications/Xcode.app/Contents/Developer`, confirming Xcode first-launch authorization is complete.
- Targeted `LoginItemServiceTests` passed with 3 tests and 0 failures after wiring launch-at-login registration.
- Targeted `SettingsViewModelTests` passed with 2 tests and 0 failures after covering settings registration and error rollback.
- `scripts/generate-release-screenshots.swift` generated 4 PNG assets; `file`, `sips`, and visual QA confirmed readable 5760x3600 screenshots without real clipboard data.
- `scripts/start-manual-release-qa-session.sh --help` and `scripts/start-manual-release-qa-session.sh --no-build --output-dir build/manual-release-qa-session-verify` passed, confirming the manual QA session helper can prepare package artifacts, verification output, baseline evidence, fixtures, and a QA record copy from the current Release build.
- `scripts/start-manual-release-qa-session.sh --no-build --output-dir build/manual-release-qa-session-prefill-verify` generated a prefilled QA record copy, and `scripts/validate-manual-qa-record.sh` correctly kept it failing because manual scenarios and distribution signing remain incomplete.
- `scripts/validate-manual-qa-record.sh docs/release/manual-qa-record.md` correctly failed on the unfilled template, and the same script passed against a filled synthetic record in `build/manual-qa-record-validate-pass.md`.
- `scripts/validate-xcode-file-references.sh` passed after regenerating `MacPasteHistory.xcodeproj`, checking that all Swift references, including `MacPasteHistory/Services/PrivacyService.swift`, resolve to existing files.
- `scripts/release-readiness-report.sh --output build/release-readiness-report.md` correctly failed on the current unfilled manual QA record and missing signing identities while passing Xcode, docs, and screenshot checks.
- `scripts/release-readiness-report.sh --allow-adhoc --manual-record build/manual-qa-record-validate-pass.md --output build/release-readiness-pass.md` passed against a filled synthetic record, with missing signing identities downgraded to an internal-QA warning.
- `scripts/scan-privacy-log-safety.sh` passed on current app sources, and a temporary violating Swift sample correctly failed for direct console logging and raw clipboard-content logging.
- `scripts/verify-privacy-usage-descriptions.sh` passed, confirming Info.plist includes non-placeholder pasteboard and accessibility usage descriptions.
- `scripts/release-install-preflight.sh --no-build` passed, confirming a copied Release app can launch from a temporary install directory, create isolated local storage in the app sandbox container, and quit cleanly.
- `scripts/release-readiness-report.sh` now includes the Release install preflight by default; final release remains blocked until signing identities and filled manual QA evidence are available.
- `scripts/release-smoke-test.sh` now emits `Status: PASS`, and the readiness report includes it by default before running install preflight with the existing Release build.
- `scripts/validate-manual-qa-record.sh --allow-adhoc build/manual-qa-record-validate-pass.md` correctly failed until the synthetic record included the required double-click paste workflow row.
- `scripts/validate-manual-qa-record.sh --allow-adhoc build/manual-qa-record-missing-matrices.md` correctly failed when required environment, common-app, or privacy rows were removed.
- `scripts/validate-manual-qa-record.sh --allow-adhoc build/manual-qa-record-wrong-section-row.md` correctly failed when a required common-app row appeared outside the Common App Copy Matrix section.
- `scripts/generate-app-icon.swift` generated all 10 macOS AppIcon PNG slots, and `scripts/verify-app-icon-assets.sh` confirmed unique filenames and expected pixel dimensions.
- `scripts/verify-release-screenshot-assets.sh` confirmed all 4 release screenshots are readable 5760x3600 PNG files.
- `scripts/verify-manual-qa-fixtures.sh` generated and validated the browser, VS Code, chat, large-text, standard-image, large-image, and README fixtures.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-green.json --output build/release-readiness-green.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with 13 checks and expected internal-QA warnings.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-template-fail.json --output build/release-readiness-template-fail.md --skip-release-smoke --skip-install-preflight --manual-record docs/release/manual-qa-record.md` exited 1 and produced a valid `fail` JSON summary listing missing signing identity and incomplete manual QA record blockers.
- `scripts/release-readiness-report.sh --strict-final --json-output build/release-readiness-strict-fail.json --output build/release-readiness-strict-fail.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` exited 1 and produced a valid `fail` JSON summary because strict final mode treats warnings as blockers.
- `scripts/verify-supported-macos-targets.sh` passed, confirming project.yml, Info.plist, release guide, and manual QA record all align on the macOS 14.0+ support target and required macOS coverage rows.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-macos-targets.json --output build/release-readiness-macos-targets.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with the Supported macOS targets check included.
- `scripts/verify-release-version-build.sh` passed, confirming Info.plist, release guide, and manual QA record all align on version `0.1.0 (1)`.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-version-build.json --output build/release-readiness-version-build.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with the Release version and build check included.
- `scripts/verify-release-entitlements.sh` passed, confirming `project.yml` binds `MacPasteHistory/MacPasteHistory.entitlements`, App Sandbox is enabled, and broad network, USB, and user-selected file access entitlements are disabled.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-entitlements.json --output build/release-readiness-entitlements.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with the Release entitlements check included.
- `scripts/verify-release-identity.sh` passed, confirming `com.peibin.MacPasteHistory`, `MacPasteHistory`, the handwritten Info.plist path, and `LSUIElement = true`.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-identity.json --output build/release-readiness-identity.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with the Release identity check included.
- `scripts/verify-xcode-authorization.sh` passed, confirming `/Applications/Xcode.app/Contents/Developer`, Xcode first-launch authorization, and Xcode license acceptance.
- `scripts/verify-signing-identities.sh --allow-adhoc` returned `WARN`, confirming the current machine still has `0 valid identities found` and formal distribution remains blocked until an Apple signing identity is installed.
- `scripts/verify-release-app-signature.sh --allow-adhoc` returned `WARN`, confirming the current Release app is `Signature=adhoc`, `TeamIdentifier=not set`, and Sandbox-entitled for internal QA only.
- `scripts/verify-manual-release-qa-session.sh <session-dir>` passed for a generated internal QA session, confirming package, checksum, manifest, package verification, baseline, fixtures, manual record copy, and README are present before manual testing.
- `scripts/release-readiness-report.sh --qa-session <session-dir> ...` produced a valid JSON summary with a passing Manual QA session check, while omitting `--qa-session` keeps a warning for strict final gates.
- `scripts/verify-release-qa-baseline.sh <baseline.md>` passed for a generated internal QA baseline and failed against an intentionally incomplete sample.
- `scripts/verify-release-qa-manifest.sh <manifest.md>` passed for a generated internal QA manifest and failed against an intentionally incomplete sample.
- `scripts/validate-manual-qa-record.sh --allow-adhoc build/manual-qa-record-double-click-pass.md` now fails when the required Package manifest field is absent.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when Package manifest points to a missing file and passes when it points to a valid generated manifest.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when the referenced Package manifest embeds a dirty Git worktree baseline.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when App path is missing, not a `.app`, or does not match the manifest Packaged app.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when Package SHA-256 differs from the manifest checksum file and passes when both values match.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when Package verification reports a mismatched signature, Team, Sandbox, or missing checksum success result.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when Fixture directory points to a missing or invalid generated fixture set.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when the record Git commit differs from the referenced Package manifest commit.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when the record Version / build differs from the referenced Package manifest version.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when the record Signing identity differs from the referenced Package manifest signature, Team, or Sandbox state.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when table rows still contain `Filled` placeholders.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when a required final Decision row is missing.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-openspec-green.json ...` produced `openSpecProgress` as 4/19 with 15 remaining tasks and an OpenSpec progress warning.
- Targeted `ClipboardHistoryViewModelTests` and `PasteCommandServiceTests` passed with 9 tests and 0 failures after adding double-click paste support.
- `scripts/preview-release-app.sh --build-only` and `scripts/package-release-qa-build.sh --output-dir build/release-qa-entry-verify` passed in parallel after wiring Xcode file-reference validation into release entry points and serializing XcodeGen.
- `scripts/release-smoke-test.sh` passed after wiring Xcode file-reference validation into the Release smoke build entry point.
- Targeted `ClipboardDataClearServiceTests` passed with 1 test and 0 failures after extracting clear-all behavior into a service.
- Targeted `DataCleanupServiceTests` passed with 5 tests and 0 failures after adding count-limit and storage-cap cleanup coverage.
- Targeted `DataCleanupServiceTests` passed after reproducing and fixing expired image file cleanup.
- Targeted `ClipboardReaderTests` passed with 7 tests and 0 failures after adding Finder image file URL coverage.
- Targeted `ClipboardReaderTests`, `ClipboardMonitorTests`, and `UserDefaultsConfigTests` passed with 14 tests and 0 failures after fixing image fixture dimensions and storage cap persistence.

### Risks

- Text history still needs manual GUI verification for real app copy, restart, restore, delete, and clear workflows.
- History experience still needs manual GUI verification for large-list scroll smoothness and detail interaction polish.
- Image history still needs manual GUI verification for screenshot capture, browser-copied images, and pasting restored images into real apps.
- Release preparation still needs Apple Developer signing certificates, manual sandbox runtime QA, compatibility, common-app QA, and screenshot verification.
