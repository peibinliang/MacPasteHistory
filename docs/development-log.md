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
- Extended the Release smoke-test script to launch a temporary installed app copy, verify restart persistence, and validate Release startup cleanup for count limits, favorite preservation, and storage caps while backing up and restoring app data.
- Extended the Release smoke-test script to verify oversized images are skipped without database records, original files, or thumbnail files.
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
- `scripts/release-smoke-test.sh` passed on the current Apple Silicon Mac with a temporary installed app copy, synthetic clipboard text, large text, PNG, large PNG, oversized-image skip, restart persistence, expired image cleanup, count-limit cleanup, favorite preservation, and storage-cap cleanup data.
- Targeted `ImageStorageServiceTests` passed with 3 tests and 0 failures after adding dynamic single-image limit coverage.
- `scripts/release-environment-report.sh` confirmed Xcode is selected and licensed, the current machine is Apple Silicon, Chrome/Safari/VS Code/WeChat/DingTalk are installed, and no valid code signing identities are currently available.
- `xcodebuild -checkFirstLaunchStatus` exited with 0 after selecting `/Applications/Xcode.app/Contents/Developer`, confirming Xcode first-launch authorization is complete.
- Targeted `LoginItemServiceTests` passed with 3 tests and 0 failures after wiring launch-at-login registration.
- Targeted `SettingsViewModelTests` passed with 2 tests and 0 failures after covering settings registration and error rollback.
- `scripts/generate-release-screenshots.swift` generated 4 PNG assets; `file`, `sips`, and visual QA confirmed readable 5760x3600 screenshots without real clipboard data.
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
