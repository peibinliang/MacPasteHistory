## Why

Users need control over what the app records, how much data it keeps, startup behavior, and destructive cleanup. This phase turns the settings window into a complete control center for first-version behavior.

## What Changes

- Build the settings page layout.
- Add switches for text recording and image recording.
- Add startup launch configuration.
- Add Dock icon visibility configuration.
- Add retention day, text count, image count, image size, and total storage limit settings.
- Add a clear-all-data action.
- Persist settings so they survive restart.

## Capabilities

### New Capabilities
- `add-settings-center`: Settings UI and persistence for recording toggles, startup, Dock icon visibility, retention, storage limits, and clearing all data.

### Modified Capabilities

## Impact

- Affects settings UI, settings model, persistence helpers, clipboard monitor enablement, cleanup configuration, local data deletion, and launch behavior.
