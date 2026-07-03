# Development Log

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
- `scripts/validate-manual-qa-record.sh docs/release/manual-qa-record.md` correctly failed on the unfilled template, and the same script passed against a filled synthetic record in `build/manual-qa-record-validate-pass.md`.
- `scripts/validate-xcode-file-references.sh` passed after regenerating `MacPasteHistory.xcodeproj`, checking that all Swift references, including `MacPasteHistory/Services/PrivacyService.swift`, resolve to existing files.
- `scripts/release-readiness-report.sh --output build/release-readiness-report.md` correctly failed on the current unfilled manual QA record and missing signing identities while passing Xcode, docs, and screenshot checks.
- `scripts/release-readiness-report.sh --allow-adhoc --manual-record build/manual-qa-record-validate-pass.md --output build/release-readiness-pass.md` passed against a filled synthetic record, with missing signing identities downgraded to an internal-QA warning.
- `scripts/preview-release-app.sh --build-only` and `scripts/package-release-qa-build.sh --output-dir build/release-qa-entry-verify` passed in parallel after wiring Xcode file-reference validation into release entry points and serializing XcodeGen.
- `scripts/release-smoke-test.sh` passed after wiring Xcode file-reference validation into the Release smoke build entry point.
- Targeted `ClipboardDataClearServiceTests` passed with 1 test and 0 failures after extracting clear-all behavior into a service.
- Targeted `DataCleanupServiceTests` passed with 5 tests and 0 failures after adding count-limit and storage-cap cleanup coverage.
- Targeted `DataCleanupServiceTests` passed after reproducing and fixing expired image file cleanup.
- Targeted `ClipboardReaderTests` passed with 7 tests and 0 failures after adding Finder image file URL coverage.
- Targeted `ClipboardReaderTests`, `ClipboardMonitorTests`, and `UserDefaultsConfigTests` passed with 14 tests and 0 failures after fixing image fixture dimensions and storage cap persistence.

### Risks

- App icon assets are only scaffolded; real icon artwork still needs to be added.
- Text history still needs manual GUI verification for real app copy, restart, restore, delete, and clear workflows.
- History experience still needs manual GUI verification for large-list scroll smoothness and detail interaction polish.
- Image history still needs manual GUI verification for screenshot capture, browser-copied images, and pasting restored images into real apps.
- Release preparation still needs Apple Developer signing certificates, manual sandbox runtime QA, compatibility, common-app QA, and screenshot verification.
