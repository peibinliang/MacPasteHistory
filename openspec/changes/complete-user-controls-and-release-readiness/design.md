## Context

The app already has many of the lower-level pieces needed for privacy controls, shortcuts, source metadata, settings persistence, release packaging, and QA reporting. The current gap is that some functionality is not user-operable, not fully wired at runtime, or not reflected honestly in release readiness status.

Relevant current state:

- `PrivacyService` supports pause state and blocked bundle IDs, and `ClipboardMonitor` checks pause and blocked-app state before persisting clipboard changes.
- `SettingsView` exposes recording, cleanup, language, startup, Dock icon, and clear-data controls, but pause and blocked-app management are not visible there.
- `ShortcutService` registers a fixed default shortcut through `registerDefaultShortcut()`, while the previous planning artifacts describe customization.
- `ClipboardHistoryItem` stores `sourceApp` and `sourceBundleID`; the UI displays source metadata in rows/details, but no time/source filters are available.
- `showDockIcon` is persisted through `UserDefaultsConfig`, but runtime activation-policy behavior needs explicit verification and tests.
- `prepare-release-testing-and-store-assets` is partially complete and blocked by signing identity, manual QA, compatibility coverage, and final evidence.

## Goals / Non-Goals

**Goals:**

- Make pause recording and blocked-app management visible and operable from the settings surface.
- Ensure settings that affect app runtime behavior, especially Dock icon visibility, are applied immediately or clearly tell the user when a restart is required.
- Implement configurable global shortcuts with validation, persistence, conflict feedback, and a reset path.
- Add time range and source application filters to the history UI and data/query layer.
- Keep release readiness status accurate by completing or explicitly documenting signing, QA, compatibility, and store-asset blockers.
- Add tests and release evidence for each fixed gap.

**Non-Goals:**

- Do not implement local database encryption in this change. It remains a P2 feature and must not be represented as shipped.
- Do not add cloud sync, remote storage, analytics, or network behavior.
- Do not redesign the main app UI beyond the controls required for these workflows.
- Do not change the app's privacy promises except to make current behavior more visible and testable.

## Decisions

1. Treat pause and blocked apps as settings-backed privacy controls.

   The app should expose pause recording as a first-class toggle and blocked apps as a list editor using the existing privacy/capture concepts. Persisting this state makes behavior predictable across restart. The alternative, a transient-only pause button, is useful for quick access but insufficient for settings verification and release QA.

2. Keep blocked app matching based on bundle ID, with app name as display metadata.

   `SourceApplicationProvider` already captures bundle IDs and names. Bundle ID matching is more stable than display-name matching across localization and renamed apps. The alternative, name-only matching, would be easier to type manually but less reliable.

3. Apply Dock icon changes through a dedicated app-preferences service.

   Activation policy is an application lifecycle concern, so `SettingsViewModel` should not directly own AppKit policy details. A small service can translate persisted `showDockIcon` into `.regular` or `.accessory`, report whether the change took effect, and be testable. If macOS requires restart for a specific transition, the UI should show an explicit restart prompt.

4. Model shortcuts as data rather than a hard-coded service method.

   Store key code, modifiers, and display string in a `ShortcutConfiguration` value. `ShortcutService` should register the current configuration, unregister before re-registering, and expose success or conflict status. A recorder-style control should reject empty, modifier-only, Escape-only, and reserved combinations. The alternative, a fixed set of shortcut presets, would be simpler but would not satisfy the customization requirement.

5. Add filter criteria to the view model and repository query boundary.

   Time/source filters should compose with search text, content type, and favorites. The repository should accept a structured query rather than having the view filter large unbounded result sets. For the first implementation, available source options can be derived from loaded history or a repository distinct-source query; either path must keep UI state stable when records are deleted.

6. Treat database encryption as explicitly out of scope for the current release.

   The app stores clipboard history locally and has privacy controls, but encryption is not implemented. Release documentation and UI must avoid claiming encrypted local storage until a dedicated P2 change is implemented and verified.

7. Finish release readiness through evidence, not checklist wording.

   Release tasks should only be checked off when scripts, package manifests, signing output, manual QA records, and compatibility evidence exist. For internal QA, ad-hoc signing is acceptable only when clearly labeled; final distribution requires a valid signing identity and notarization/App Store path decision.

## Risks / Trade-offs

- [Risk] Runtime Dock policy changes can behave differently across macOS versions. → Mitigation: centralize activation-policy application, add restart messaging fallback, and include manual QA on supported macOS versions.
- [Risk] Shortcut capture can conflict with system or third-party shortcuts. → Mitigation: validate combinations, preserve the last known-good shortcut, and show conflict status without breaking existing registration.
- [Risk] Source filtering can hide expected items when source metadata is missing. → Mitigation: include an "Unknown source" option and keep "All sources" as the default.
- [Risk] Blocked app UI could encourage users to type invalid bundle IDs. → Mitigation: support adding the current frontmost app when possible and validate manual bundle IDs before saving.
- [Risk] Release readiness may look stalled because signing and cross-device tests are external dependencies. → Mitigation: separate automated evidence from manual blockers and document remaining owner/action/date fields.

## Migration Plan

1. Add tests for each missing user-visible behavior before implementation.
2. Introduce any new settings keys with defaults that preserve current behavior: recording active, no blocked apps, current default shortcut Command + Shift + V, all history visible, Dock icon hidden unless already configured otherwise.
3. Implement UI and service wiring in small slices: privacy controls, Dock policy service, shortcut customization, then filters.
4. Regenerate the Xcode project after adding files and run unit tests plus the Xcode file-reference validator.
5. Rebuild the QA package and update release evidence after behavior passes.

Rollback is straightforward for UI/service changes: revert the change and retain existing defaults. Any newly introduced settings keys should be ignored safely by older builds.

## Open Questions

- Which UI should be the primary quick pause entry point: settings only, menu bar menu, main panel toolbar, or both settings and quick access?
- Should blocked app management support app picking from `/Applications`, adding the current frontmost app, manual bundle ID entry, or all three?
- Which macOS versions must be manually covered before final release beyond the current minimum target of macOS 14.0+?
- Is final distribution intended for the Mac App Store, direct Developer ID distribution, or both?
