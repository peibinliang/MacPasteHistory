# Development Log

## 2026-07-02

### Added

- Initialized git repository.
- Installed and used XcodeGen to generate `MacPasteHistory.xcodeproj`.
- Added initial macOS SwiftUI app structure under `MacPasteHistory/`.
- Added menu bar status item, main window, settings window, Application Support directory setup, SQLite opening, logging, and default settings.
- Added initial unit tests for default settings.

### Verification

- `xcodebuild build` passed for `MacPasteHistory`.
- `xcodebuild test` passed with 2 tests and 0 failures.

### Risks

- Global `xcode-select` still points to Command Line Tools because switching requires administrator password. Commands currently use `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer`.
- App icon assets are only scaffolded; real icon artwork still needs to be added.
- Database migrations and `UserDefaults` settings persistence are not implemented yet.
