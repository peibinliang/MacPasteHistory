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
- Fixed main-list restore actions so mouse restore and Enter restore both write the selected item to the clipboard before showing feedback.

### Verification

- `xcodebuild build` passed for `MacPasteHistory`.
- `xcodebuild test` passed with 43 tests and 0 failures.
- Targeted `ClipboardReaderTests` passed with 7 tests and 0 failures after adding Finder image file URL coverage.
- Targeted `ClipboardReaderTests`, `ClipboardMonitorTests`, and `UserDefaultsConfigTests` passed with 14 tests and 0 failures after fixing image fixture dimensions and storage cap persistence.

### Risks

- App icon assets are only scaffolded; real icon artwork still needs to be added.
- Text history still needs manual GUI verification for real app copy, restart, restore, delete, and clear workflows.
- History experience still needs manual GUI verification for large-list scroll smoothness and detail interaction polish.
- Image history still needs manual GUI verification for screenshot capture, browser-copied images, and pasting restored images into real apps.
- Release preparation still needs signed Release build, sandbox, compatibility, common-app QA, and screenshot verification.
