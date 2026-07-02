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
- Extended Release smoke validation to cover installed-copy launch, restart persistence, count-limit cleanup, favorite preservation, and storage-cap cleanup with app data backup/restore.
- Added cleanup regression tests for text count limits, image count limits, favorite preservation, and image storage limits.

### Fixed

- Stabilized image dimension tests across Retina and non-Retina environments.
- Fixed cleanup storage-limit wiring to use the total storage cap instead of the single-image size limit.
- Fixed expired image cleanup so original and thumbnail files are removed with expired database records.
- Fixed cleanup count-limit eviction so favorites count toward the configured total limit while remaining protected from deletion.
- Fixed main-list restore actions so mouse restore writes the selected item before showing feedback.
