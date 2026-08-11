# CHANGELOG

## Unreleased

### Fixed

- Made inline history-row actions use the same content suitability rules as All Actions, so URL records only show URL-specific operations while plain text retains AI polishing.

## 1.0.2 - 2026-08-11

### Added

- Added opt-in Automatic Paste, disabled by default, with Accessibility guidance only after enablement and clipboard-only fallback on every paste path.
- Added explicit DeepSeek AI text polishing with configurable default model `deepseek-v4-flash`, Keychain-backed API credentials, first-use remote-processing disclosure, cancellable preview flow, localized errors, and provider-reported token statistics.
- Added migration-backed exact-once AI token accounting and clear-all-data integration without silently deleting the separately managed Keychain credential.

## 1.0.1 - 2026-08-11

### Added

- Added a user-controlled sensitive-content filter that remains enabled by default and requires an explicit local-storage risk confirmation before first being disabled.
- Added an About & Updates settings page with Bundle-derived application name, version, and build information.
- Added automatic and on-demand update checks plus Sparkle-based verification, installation, and relaunch support for formally published GitHub-hosted updates.

### Fixed

- Fixed intentional local capture of long technical text, including multiline cURL-style commands and documentation containing URLs, Chinese text, quotes, and Emoji, when sensitive-content filtering has been explicitly disabled.
- Kept ordinary long text eligible while filtering is enabled; length alone is not treated as a sensitive-content match.

### Security

- Preserved sensitive filtering as the missing-preference default for new and upgraded installations.
- Added a warning that disabling filtering may save password- or token-like text in the local unencrypted SQLite history database.
- Kept clipboard payloads out of application logs and update requests; update checks contact only the configured GitHub-hosted update endpoints.
- Added fail-closed Sparkle configuration, sandbox, archive, checksum, appcast, version, and bundle verification tooling. Developer ID signing, notarization, genuine EdDSA release artifacts, and end-to-end public upgrade evidence remain release gates rather than claimed completion.

## 1.0.0 - 2026-08-10

### Added

- Added persistent Follow System, Light, and Dark appearances with immediate whole-app updates.
- Added classification-driven content action sets for plain text, images, JSON, URL, Base64, JWT, timestamps, SQL, shell, and OCR text.
- Added structured clipboard search, developer-content classification, local content transformations, editable action sessions, derived-history metadata, and local manual image OCR.
- Added progressive action-panel layouts, keyboard navigation, syntax-aware editing, usage attribution, and OCR-aware image search.

- Added an Accessibility permission reminder on first launch and whenever direct paste is blocked, with a shortcut to the correct System Settings pane.
- Added the Context Timeline interface: recent-source ribbon, chronological record groups, inline keyboard selection, compact filters, and persistent paste shortcuts.
- Added timeline organization coverage for recent, today, and earlier groups plus deduplicated recent application sources.
- Redesigned the 粘易 app icon as an original monochrome folded-paper loop mark, with a matching simplified menu bar template icon for clear small-size rendering.
- Added single-click direct paste from the history list, including clipboard replacement, previous-app reactivation, and Command+V dispatch.
- Initialized macOS SwiftUI app project foundation.
- Added XcodeGen project configuration.
- Added menu bar app shell with main and settings windows.
- Added Application Support directory creation and SQLite database opening.
- Added initial unit tests.
- Added text clipboard monitoring, local SQLite persistence, hash deduplication, search, restore, delete, and clear support.
- Added migration tracking and `clipboard_history` table.
- Added text history unit tests.
- Added bounded previews, friendly time display, detail viewing, favorites, favorites-only filtering, content type filtering, and paginated history loading.
- Added PNG/TIFF image history capture, local image and thumbnail storage, image metadata persistence, image restore, image delete cleanup, and image previews.
- Added Finder image file copy detection for supported local image files.
- Added persisted total storage cap configuration for cleanup rules.
- Added user guide and privacy policy drafts for release preparation.
- Added XcodeGen-managed sandbox entitlements and Release build settings for local release validation.
- Added a local Release smoke-test script for synthetic text and image clipboard capture validation.
- Extended Release smoke validation to cover large text, large images, and expired image cleanup.
- Extended Release smoke validation to cover installed-copy launch, restart persistence, count-limit cleanup, favorite preservation, and storage-cap cleanup with an isolated temporary App Support directory.
- Extended Release smoke validation to cover oversized-image skip behavior without database or file residue.
- Added an Application Support override path for isolated release smoke and test runs.
- Added a Release preview helper script with optional isolated data mode for manual QA.
- Added a manual release QA record template for device, common-app, restore, privacy, and final decision evidence.
- Added a release environment report script and local environment snapshot for signing, Xcode, architecture, macOS, and common-app QA readiness.
- Added cleanup regression tests for text count limits, image count limits, favorite preservation, and image storage limits.
- Added service-level coverage for clearing all history records and image files.
- Added system login item registration for the settings launch-at-login toggle, backed by service and ViewModel tests.
- Added reproducible synthetic App Store screenshot assets for release preparation.
- Added double-click paste from the history list, including previous-app reactivation and Command+V dispatch after restore.
- Added manual Release QA coverage for double-click paste and made the QA validator require that workflow row.
- Added manual Release QA validation for required environment, common-app, and privacy/safety matrix rows.
- Added section-scoped manual Release QA row validation so misplaced required rows are rejected.
- Added release screenshot asset verification for expected PNG dimensions.
- Added synthetic manual QA fixture verification for common-app and large-content testing inputs.
- Added Info.plist privacy usage description verification to release readiness checks.
- Added Release install preflight coverage to the final release readiness report.
- Added Release smoke-test coverage to the final release readiness report.
- Added ordered static-check and readiness-report guidance to generated manual Release QA session READMEs.
- Added machine-readable JSON output support for release readiness reports.
- Added strict final release readiness mode that treats warnings as blockers.
- Added supported macOS target consistency verification to release readiness checks.
- Added release version/build consistency verification to release readiness checks.
- Added release entitlement boundary verification to release readiness checks.
- Added release identity verification to release readiness checks.
- Added explicit Xcode authorization verification to release readiness checks.
- Added explicit signing identity verification with internal QA ad-hoc warnings.
- Added explicit Release app signature verification with formal distribution blocking.
- Added manual Release QA session directory verification.
- Added release readiness validation for generated manual QA session directories.
- Added Release QA baseline evidence verification.
- Added Release QA package manifest verification.
- Added Package manifest tracking to manual Release QA records.
- Added Package manifest file validation to manual Release QA record checks.
- Added dirty-worktree manifest blocking for manual Release QA records.
- Added App path to Packaged app cross-checking for manual Release QA records.
- Added Package SHA-256 cross-checking for manual Release QA records.
- Added Package verification summary cross-checking for manual Release QA records.
- Added Fixture directory validation for manual Release QA records.
- Added Git commit cross-checking against Package manifests for manual Release QA records.
- Added Version / build cross-checking against Package manifests for manual Release QA records.
- Added Signing identity cross-checking against Package manifests for manual Release QA records.
- Added `Filled` placeholder rejection for manual Release QA records.
- Added required final Decision row validation for manual Release QA records.
- Added OpenSpec remaining-task reporting to release readiness summaries.

### Fixed

- Completed the developer content actions with strict JSON, JWT, SQL, timestamp, URL, Base64, and text handling, including useful copy variants and explicit validation failures.
- Fixed OCR image records using image bytes for text actions, raw images offering inapplicable text actions, and failed actions exposing empty success controls.
- Fixed untranslated action names, extracted-content labels, detected types, action summaries, shortcut keys, preview controls, notices, and errors in Chinese environments.
- Fixed the System language option ignoring the current Simplified or Traditional Chinese preference.
- Fixed Base64 actions for Unicode text, binary validity checks, and direct image-file encoding.
- Fixed intelligent action filtering for Base64 values that decode to Chinese or other printable Unicode text.
- Completed JWT claim/expiry inspection, date-to-timestamp conversion, SQL comment preservation, strict URL decoding, four-space JSON formatting, and non-printable Base64 rejection.
- Fixed OCR-backed image actions, action failure presentation, per-variant copy controls, applicable-action filtering, syntax highlighting, and missing action localizations.
- Fixed URL query-value encoding so reserved characters and Unicode text are percent-encoded.
- Removed the blue keyboard focus ring that appeared as two horizontal dividers around the history list.
- Fixed direct paste by retaining the last external foreground application, bringing it back to the front, and allowing focus to settle before sending `Command + V`.
- Fixed custom shortcut registration by sharing the app's single `ShortcutService` with every Settings entry point instead of registering a competing Carbon hotkey.
- Fixed the clipboard history overlay becoming unresponsive when opening a record detail Sheet.
- Moved record details to a dedicated button so row clicks can paste without conflicting with the detail Sheet gesture.

### Changed

- Renamed the user-facing application and executable from MacPasteHistory to 粘易 while preserving the bundle identifier, Swift module, and Application Support path for compatibility.
- Fixed history shortcut invocation over fullscreen applications by presenting a nonactivating top overlay in the current Space instead of activating a standard window.
- Stabilized image dimension tests across Retina and non-Retina environments.
- Fixed cleanup storage-limit wiring to use the total storage cap instead of the single-image size limit.
- Fixed expired image cleanup so original and thumbnail files are removed with expired database records.
- Fixed cleanup count-limit eviction so favorites count toward the configured total limit while remaining protected from deletion.
- Fixed main-list restore actions so mouse restore writes the selected item before showing feedback.
- Fixed launch-at-login settings behavior so failures roll back the toggle instead of silently persisting an unavailable state.
- Fixed image capture so the single-image size limit setting is applied dynamically when saving images.
