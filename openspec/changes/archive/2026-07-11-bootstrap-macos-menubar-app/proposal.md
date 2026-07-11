## Why

The app needs a runnable macOS foundation before clipboard history features can be implemented. This change establishes the menu bar app shell, local storage foundation, and basic windows required by every later phase.

## What Changes

- Create a macOS SwiftUI application that can launch successfully.
- Add app metadata, icon assets, and a menu bar `NSStatusItem`.
- Open the main history panel from the menu bar item.
- Provide an entry point for the settings window.
- Create the Application Support data directory.
- Integrate SQLite database initialization.
- Add lightweight logging and `UserDefaults` configuration helpers.

## Capabilities

### New Capabilities
- `bootstrap-macos-menubar-app`: macOS menu bar app foundation, window entry points, local data directory, SQLite initialization, logging, and settings persistence.

### Modified Capabilities

## Impact

- Affects the SwiftUI app target, app delegate or scene lifecycle, menu bar integration, local filesystem setup, SQLite setup, and shared utility modules.
