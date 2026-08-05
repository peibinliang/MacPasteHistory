# App Store Screenshot Assets

These PNGs show the current 粘易 Release UI with synthetic, non-private example data. They are also used by the repository README.

## Current assets

- `01-history-overview.png`: top overlay, recent-source ribbon, timeline groups, search, filtering, and row actions.
- `02-image-history.png`: image detail, dimensions, format, source application, favorite, delete, and copy actions.
- `03-settings-controls.png`: General settings, recording options, launch behavior, shortcut customization, and language.
- `04-local-privacy.png`: pause recording and application blocklist controls.

## Refresh workflow

1. Run `scripts/preview-release-app.sh --seed-preview-data` to build and launch the current Release app with isolated synthetic history.
2. Capture the four views from the running app. Do not use personal clipboard history or user files.
3. Export each image as a 5760 × 3600 PNG, preserving the filenames above.
4. Run `scripts/verify-release-screenshot-assets.sh` and visually review every image before committing.

The legacy static screenshot generator does not reflect the live SwiftUI layout and is not the source of truth for README or release screenshots. Screenshots and captions must not claim local database encryption for the current release; encrypted local storage is a future P2 capability.
