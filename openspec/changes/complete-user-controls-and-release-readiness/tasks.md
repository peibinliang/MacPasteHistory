## 1. Baseline Verification

- [x] 1.1 Audit current pause, blocked-app, Dock icon, shortcut, source metadata, and release-readiness code paths against the new specs
- [x] 1.2 Add failing tests or documented manual checks for the currently missing user-facing pause and blocked-app controls
- [x] 1.3 Add failing tests for Dock icon runtime activation-policy application and launch-time preference loading
- [x] 1.4 Add failing tests for custom shortcut persistence, validation, conflict reporting, and reset-to-default behavior
- [x] 1.5 Add failing tests for history time/source filters composing with search, content type, and favorites

## 2. User-Operable Privacy Controls

- [x] 2.1 Persist pause recording state through the shared settings/config layer with defaults that preserve current recording behavior
- [x] 2.2 Wire the persisted pause state into `PrivacyService` and `ClipboardMonitor` so UI state and capture behavior use the same source of truth
- [x] 2.3 Add a visible pause/resume control to the settings UI or approved quick-access surface with localized copy and state feedback
- [x] 2.4 Implement blocked-app storage entries with bundle ID, display name, enabled state, and created/updated metadata if the current storage is only in-memory
- [x] 2.5 Add blocked-app management UI for viewing, adding, enabling/disabling, and removing entries
- [x] 2.6 Support adding the current frontmost app or manually entering a validated bundle ID
- [x] 2.7 Verify text and image capture skip behavior for paused recording and enabled blocked apps without logging clipboard payloads

## 3. Runtime App Preferences

- [x] 3.1 Introduce an app-preferences service that applies persisted Dock icon visibility to `NSApp` activation policy
- [x] 3.2 Apply Dock icon visibility during app startup before the user opens settings
- [x] 3.3 Update the settings Dock icon toggle to call the runtime app-preferences service after saving
- [x] 3.4 Show a localized restart-required message if macOS does not apply the Dock policy change immediately
- [x] 3.5 Add automated tests or manual QA evidence for persisted launch behavior and runtime Dock icon toggling

## 4. Custom Shortcuts

- [x] 4.1 Add a `ShortcutConfiguration` model for key code, modifiers, display label, default value, and validation
- [x] 4.2 Persist the configured shortcut with migration from the existing fixed Command + Shift + V behavior
- [x] 4.3 Refactor `ShortcutService` to register an injected or loaded shortcut configuration instead of only `registerDefaultShortcut()`
- [x] 4.4 Implement safe re-registration that unregisters previous handlers only after preserving a last known-good configuration
- [x] 4.5 Add a settings shortcut recorder control with validation errors, conflict feedback, and reset-to-default
- [x] 4.6 Verify custom shortcut, conflict state, reset behavior, and restart persistence in tests

## 5. History Filtering UI

- [x] 5.1 Extend `HistoryQuery` or equivalent query state with time range and source application criteria
- [x] 5.2 Add repository support for filtering by created-at range and source app or bundle ID
- [x] 5.3 Expose available source filter options, including safe handling for missing source metadata
- [x] 5.4 Add time range and source filters to the history UI without disrupting existing search, type, and favorites controls
- [x] 5.5 Ensure filters update cleanly when matching records are deleted or all data is cleared
- [x] 5.6 Verify composed filter behavior and responsiveness with representative text and image history data

## 6. Release Readiness Completion

- [x] 6.1 Update release documentation to state that local database encryption is planned P2 and not included in the current release
- [x] 6.2 Ensure screenshots, usage docs, privacy policy, and release notes do not claim unimplemented database encryption
- [x] 6.3 Generate a fresh QA package after the user-control and filtering fixes are implemented
- [x] 6.4 Run package verification, release smoke test, install preflight, and readiness report against the fresh package
- [ ] 6.5 Complete or explicitly waiver Intel, Apple Silicon, and supported macOS compatibility evidence
- [ ] 6.6 Complete manual QA records for Chrome, Safari, VS Code, chat apps, large text, large image, cleanup, pause, blocked apps, Dock icon, shortcuts, and filters
- [ ] 6.7 Resolve final signing identity and distribution path, or keep final release blocked while allowing clearly labeled internal QA packages
- [ ] 6.8 Update `prepare-release-testing-and-store-assets` progress only after evidence exists for each remaining release task

## 7. Final Validation

- [x] 7.1 Run `xcodegen generate`
- [x] 7.2 Run `scripts/validate-xcode-file-references.sh`
- [x] 7.3 Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild -project MacPasteHistory.xcodeproj -scheme MacPasteHistory -destination 'platform=macOS,arch=arm64' test`
- [x] 7.4 Run relevant release verification scripts for the produced QA package
- [x] 7.5 Review `git diff` for unintended changes, privacy regressions, and stale localization strings before commit
