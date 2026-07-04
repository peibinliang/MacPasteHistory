# CHANGELOG

## Unreleased

### Added

- Initialized macOS SwiftUI app project foundation.
- Added XcodeGen project configuration.
- Added menu bar app shell with main and settings windows.
- Added Application Support directory creation and SQLite database opening.
- Added initial unit tests.
- Added text clipboard monitoring, local SQLite persistence, hash deduplication, search, restore, delete, and clear support.
- Added migration tracking and `clipboard_history` table.
- Added text history unit tests.
- Added bounded previews, friendly time display, detail viewing, favorites, favorites-only filtering, content type filtering, and paginated history loading.
- Added PNG/TIFF image history capture, local image and thumbnail storage, image metadata persistence, image restore, image delete cleanup, and image previews.
- Added Finder image file copy detection for supported local image files.
- Added persisted total storage cap configuration for cleanup rules.
- Added user guide and privacy policy drafts for release preparation.
- Added XcodeGen-managed sandbox entitlements and Release build settings for local release validation.
- Added a local Release smoke-test script for synthetic text and image clipboard capture validation.
- Extended Release smoke validation to cover large text, large images, and expired image cleanup.
- Extended Release smoke validation to cover installed-copy launch, restart persistence, count-limit cleanup, favorite preservation, and storage-cap cleanup with an isolated temporary App Support directory.
- Extended Release smoke validation to cover oversized-image skip behavior without database or file residue.
- Added an Application Support override path for isolated release smoke and test runs.
- Added a Release preview helper script with optional isolated data mode for manual QA.
- Added a manual release QA record template for device, common-app, restore, privacy, and final decision evidence.
- Added a release environment report script and local environment snapshot for signing, Xcode, architecture, macOS, and common-app QA readiness.
- Added cleanup regression tests for text count limits, image count limits, favorite preservation, and image storage limits.
- Added service-level coverage for clearing all history records and image files.
- Added system login item registration for the settings launch-at-login toggle, backed by service and ViewModel tests.
- Added reproducible synthetic App Store screenshot assets for release preparation.
- Added double-click paste from the history list, including previous-app reactivation and Command+V dispatch after restore.
- Added manual Release QA coverage for double-click paste and made the QA validator require that workflow row.
- Added manual Release QA validation for required environment, common-app, and privacy/safety matrix rows.
- Added section-scoped manual Release QA row validation so misplaced required rows are rejected.
- Added release screenshot asset verification for expected PNG dimensions.
- Added synthetic manual QA fixture verification for common-app and large-content testing inputs.
- Added Info.plist privacy usage description verification to release readiness checks.
- Added Release install preflight coverage to the final release readiness report.
- Added Release smoke-test coverage to the final release readiness report.
- Added ordered static-check and readiness-report guidance to generated manual Release QA session READMEs.

### Fixed

- Stabilized image dimension tests across Retina and non-Retina environments.
- Fixed cleanup storage-limit wiring to use the total storage cap instead of the single-image size limit.
- Fixed expired image cleanup so original and thumbnail files are removed with expired database records.
- Fixed cleanup count-limit eviction so favorites count toward the configured total limit while remaining protected from deletion.
- Fixed main-list restore actions so mouse restore writes the selected item before showing feedback.
- Fixed launch-at-login settings behavior so failures roll back the toggle instead of silently persisting an unavailable state.
- Fixed image capture so the single-image size limit setting is applied dynamically when saving images.
