# User Controls And Release Readiness Audit

Change: `complete-user-controls-and-release-readiness`

## Current Findings

- Pause recording exists in `PrivacyService`, and `ClipboardMonitor` checks `recordingPaused`, but the state is in-memory only and has no visible user control.
- Blocked app matching exists in `PrivacyService`, and `ClipboardMonitor` checks source bundle IDs, but blocked apps are in-memory only and have no settings UI.
- Source app metadata is captured and displayed through `ClipboardHistoryItem`, but history queries cannot filter by time range or source application.
- Dock icon visibility is persisted in `UserDefaultsConfig.showDockIcon`, but startup and runtime activation-policy application are not centralized or tested.
- `ShortcutService` registers Command + Shift + V directly through `registerDefaultShortcut()` and does not persist or validate a custom shortcut.
- Release readiness automation exists, but final distribution remains blocked by signing identity, manual QA, and cross-device/cross-system evidence.

## Implementation Direction

- Persist privacy controls in `UserDefaultsConfig` and use that persisted state as the capture-chain source of truth.
- Store blocked apps as structured settings records keyed by bundle ID.
- Add an app-preferences service for Dock activation policy.
- Introduce a `ShortcutConfiguration` model and refactor shortcut registration around it.
- Extend `HistoryQuery` and repository SQL to support time and source filters.
- Keep database encryption documented as P2 and unshipped until a dedicated change implements it.
