## Why

Several planned capabilities are partially implemented or documented as complete while the current product still lacks user-facing controls and verification for important workflows. This change closes the gap between lower-level services, visible settings, filtering tools, configurable shortcuts, and release readiness so the app can be tested and shipped with behavior users can actually control.

## What Changes

- Add visible settings controls for pause recording and application blacklist management, wired to the existing capture checks.
- Verify and, if needed, complete runtime application of the Dock icon visibility setting via `NSApp` activation policy.
- Replace the fixed Command + Shift + V shortcut with a user-configurable shortcut flow, including persistence, validation, re-registration, and conflict feedback.
- Add history filtering UI for time range and source application, integrated with current search and content-type filtering.
- Define the local database encryption boundary as a planned P2 capability rather than implying it is present in the current release.
- Continue release readiness work by documenting the remaining signing, QA, cross-device, cross-system, packaging, and store-asset tasks.

## Capabilities

### New Capabilities

- `user-operable-privacy-controls`: User-visible controls for pause recording and application blacklist management, including persisted state and capture-chain verification.
- `runtime-app-preferences`: Runtime application of app-level preferences such as Dock icon visibility without requiring users to manually restart unless macOS behavior makes that unavoidable.
- `custom-shortcuts`: User-configurable global shortcut capture, validation, persistence, registration, conflict messaging, and reset-to-default behavior.
- `history-filtering-ui`: Time range and source application filters in the history UI, composed with search, favorites, and content-type filters.
- `release-readiness-completion`: Remaining release tasks for signing, notarization or QA signing boundaries, manual QA, OS/device verification, packaging, and store assets.

### Modified Capabilities

- None. There are no archived baseline specs yet, so this change defines new specs for the missing behavior.

## Impact

- Affected UI: `MacPasteHistory/Views/MainPanelView.swift`, `MacPasteHistory/Views/SettingsView.swift`, related settings panels or reusable controls.
- Affected state and services: settings persistence, pause recording state, blocked app storage, shortcut registration service, source application metadata, filtering logic, and app activation policy handling.
- Affected tests: settings view model tests, shortcut service tests, filtering tests, capture-chain tests for pause and blocked apps, and release script verification.
- Affected release artifacts: QA package scripts, signing documentation, manual QA checklist, store asset checklist, and release OpenSpec task tracking.
