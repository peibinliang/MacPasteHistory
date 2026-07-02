# Project Initialization

## Background

The first project phase establishes a runnable macOS SwiftUI menu bar app foundation.

## Implemented

- Initialized the repository as a git repository.
- Added XcodeGen project configuration in `project.yml`.
- Generated `MacPasteHistory.xcodeproj`.
- Added a macOS SwiftUI app target and unit test target.
- Added a retained `NSStatusItem` menu bar entry.
- Added main history and settings window entry points.
- Added Application Support directory creation for app data, images, thumbnails, and logs.
- Added SQLite database opening at startup.
- Added lightweight logging and default settings.

## Verification

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory -destination 'platform=macOS,arch=arm64' build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory -destination 'platform=macOS,arch=arm64' test
```

Both commands pass. The test run launches the app host and logs successful SQLite initialization.

## Remaining Phase 1 Work

- Add real app icon image assets.
- Add database migration tracking.
- Add a persisted `UserDefaults` settings helper.
- Manually verify menu bar icon and window behavior in the GUI.
