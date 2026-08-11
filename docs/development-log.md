# Development Log

## 2026-08-11

### Added

- Pinned the Sparkle dependency to exact version `2.9.2` and committed the resolved package revision.
- Added a main-actor `UpdateDriving` boundary, Sparkle KVO/Combine driver, shared `UpdateService`, and About controls for manual and automatic update checks.
- Made `AppDelegate` own one updater service and inject the same instance into both Settings entry points.

### Fixed

- Subscribed `UpdateService` to driver-originated `automaticallyChecksForUpdates` changes so Sparkle's authorization UI cannot leave the About toggle stale on a later launch.
- Kept preference synchronization one-way: the explicit user setter writes to Sparkle, while KVO publishers only refresh service state and never write back.

### Architecture and UI ownership

- The app owns updater availability and preference presentation only.
- Sparkle's standard updater controller owns progress, latest-version, release-notes, download, error, authorization, installation and relaunch feedback.

### Security and release readiness

- Feed URL, EdDSA public key and any required sandbox network entitlement remain intentionally absent and are assigned to Task 6.
- The updater dependency and service boundary are not considered release-ready until Task 6 completes and validates that security configuration.

### Verification

- `UpdateServiceTests` passed with 5 tests and 0 failures, including driver-originated automatic-check preference synchronization.
- `BrandAndInteractionTests` and `LocalizationCoverageTests` passed with 10 tests and 0 failures.
- `scripts/validate-xcode-file-references.sh` passed with 175 Swift references checked and 0 missing.
- The full macOS test suite passed with 271 tests and 0 failures while resolving Sparkle `2.9.2`.

### Compatibility

- No database migration, clipboard data change or new system permission is introduced in this phase.

## 2026-08-07

### Added

- Added a persisted `config.appAppearance` preference with Follow System, Light, and Dark choices that apply immediately across the app.
- Added a centralized content-action suitability policy so the action palette only displays operations appropriate for the active content classification.
- Upgraded clipboard capture to persist complete classification, including SQL and shell, and reclassified content when opening actions to support existing records and OCR text.
- Aligned Base64 classification with Unicode text decoding so Base64-encoded Chinese content keeps its decode actions instead of falling back to plain text.

### Verification

- Added appearance default, invalid-value fallback, persistence, immediate-apply, complete capture classification, nine-type action filtering, and OCR classification regressions.
- The targeted appearance, settings, clipboard monitor, and action-panel suite passed with 36 tests and 0 failures.
- The final coverage-enabled suite passed with 240 tests and 0 failures; the new appearance model/service and action suitability policy reached 100%, 90.48%, and 95.65% line coverage respectively, while the updated action panel, clipboard monitor, and configuration paths each remained above 80%.
- The final non-coverage suite, including direct AppKit Aqua/Dark Aqua/system mapping, passed with 241 tests and 0 failures.

### Compatibility

- No database migration, data repair, new system permission, network access, or restart is required.

### Fixed

- Completed the structured content-action set for JSON, JWT, SQL, timestamps, URL values, Base64, and text case conversion, including strict invalid-input handling and action-specific copy variants.
- Routed OCR-backed image records through their recognized text while keeping raw images limited to binary-compatible actions.
- Added an explicit failed-action presentation so invalid transformations cannot be mistaken for an empty successful result.
- Localized action names, detected content types, action summaries, shortcut labels, preview controls, and detailed failure/notices across English, Simplified Chinese, and Traditional Chinese.
- Made the System language option honor the current Apple language preference instead of falling back to the development language.
- Allowed Base64 encoding to accept arbitrary Unicode text through the same validation path used by the action panel.
- Made Base64 validity checks accept binary payloads without incorrectly requiring decoded UTF-8 text.
- Added image-to-Base64 conversion using the original image file bytes, with background file loading and an explicit missing-image failure.
- Completed the audited developer actions: four-space JSON formatting, strict URL decoding, printable-text Base64 decoding, structured JWT claims and expiry status, local-date timestamp parsing, and comment-safe SQL whitespace folding.
- Routed OCR-backed image records through text actions while keeping raw image Base64 encoding on the binary path.
- Added read-only action failure presentation, per-result copy buttons, recommended-first applicable action filtering, expanded syntax highlighting, and complete English/Simplified Chinese/Traditional Chinese action labels.

### Root Cause

- The action panel treated every image session as binary input, including OCR records that already contained recognized text, and exposed text-only actions for raw images.
- Several user-facing values were rendered from stable enum/action identifiers directly, while newly introduced literal and dynamic localization keys were absent from one or more language bundles.
- Failed actions retained preview controls and an empty output, which made the error indistinguishable from a valid empty transformation.
- The Base64 encoder reused decode validation, so ordinary text such as Chinese was rejected before encoding.
- Base64 validation attempted to render decoded bytes as UTF-8 even though valid Base64 can represent arbitrary binary data.
- Image action sessions supplied an empty text value and had no binary-input execution path.
- Several action categories had only shallow happy-path tests, so incomplete JWT/timestamp behavior, SQL comment handling, invalid URL decoding, missing localization keys, and unusable image recommendations were not detected.
- The preview stored copy variants and failure state but did not render them.

### Verification

- Added regression coverage for all registered action IDs, Unicode Base64, JSON/JWT/SQL/timestamp/URL edge cases, syntax token kinds, OCR/raw-image routing, failed-action state, dynamic localization keys, System-language selection, and localized persisted action summaries.
- Targeted content-action and localization regression tests passed with 25 tests and 0 failures before the full-suite verification.
- The complete coverage-enabled `MacPasteHistory` test suite passed with 232 tests and 0 failures; directly modified action, localization, shortcut, and action-panel logic was covered at 86%–100%, apart from the small detected-type value mapper exercised through localization assertions.
- Localization syntax validation, three-language key parity, literal-key coverage, Xcode file-reference validation, privacy-log scanning, and `git diff --check` all passed.
- Added executor-level Unicode encoding coverage, binary validation coverage, and action-panel image encoding/missing-file coverage.
- Updated presentation assertions to follow the active localization and system byte-count formatting instead of assuming English output.
- Stabilized the concurrent search-generation regression test by advancing each controlled debounce and provider request in deterministic order.
- Targeted `Base64ContentActionsTests`, `ContentActionPanelViewModelTests`, `HistoryRowPresentationTests`, and `SearchCoordinatorTests` passed with 11 tests and 0 failures.
- The complete `MacPasteHistory` test suite passed with 219 tests and 0 failures.
- The expanded action regression suite passed with 27 tests and 0 failures across all 24 registered action IDs, error paths, OCR routing, localization, and syntax highlighting.
- The final coverage-enabled suite passed with 232 tests and 0 failures; audited action logic, action palette, result preview, action ViewModel, and real local OCR paths each reached at least 83% line coverage, with OCR at 96.59%.

### Compatibility

- No database migration, data repair, new permission, or network access is required.

## 2026-08-05

### Changed

- Refreshed the GitHub README and all four release screenshots from the current 粘易 Release build using isolated synthetic clipboard data; the documentation now shows the timeline overlay, image detail, categorized Settings, and Privacy controls.
- Added a centralized Accessibility permission service. An untrusted first launch now shows one reminder, and every blocked automatic-paste attempt keeps the history panel open and shows localized guidance with an “Open System Settings” action.
- Rebuilt the history overlay from the selected Context Timeline design, with a recent-source ribbon, chronological sections, inline keyboard selection, compact filtering, and clearer paste affordances.
- Reorganized Settings into General, Privacy, and Storage and Data categories, and rebuilt history detail as a fixed-header/fixed-action sheet with independently scrolling content.
- Renamed the user-facing product to 粘易 while retaining `com.peibin.MacPasteHistory`, the `MacPasteHistory` Swift module, and the existing Application Support directory.
- Replaced the multi-element clipboard mark with an original graphite folded-paper loop icon and a matching one-color menu bar reduction, improving recognition at Dock and 18-point menu sizes.
- Changed history-row single click to restore the selected clipboard item, dismiss the overlay, reactivate the previous foreground app, and send `Command + V`; details now use a dedicated info button.

### Fixed

- Suppressed the history list's default keyboard focus effect while keeping arrow-key and Enter navigation available.
- Kept track of the last non-粘易 foreground application and force-activated it before dispatching the paste command.
- Reused the application-level shortcut service in both Settings entry points, eliminating duplicate Carbon hotkey registration conflicts.
- Replaced the standard clipboard history window with a rounded, translucent top overlay.
- Prevented global shortcut invocation from activating a normal app window and switching away from the current fullscreen Space.
- Added outside-click and Escape dismissal while preserving keyboard navigation and double-click paste behavior.
- Fixed the history panel becoming unresponsive after opening a record detail Sheet.

### Root Cause

- The keyboard-focusable history `ScrollView` drew its system focus ring across the full list bounds, leaving a blue line at both edges.
- Paste targeting only sampled the current foreground app when the panel opened; after 粘易 became foreground, the previous target could be lost, and activation used no options.
- Each Settings view created its own `ShortcutService`; the app delegate already owned the registered global shortcut, so the second Carbon registration returned a hotkey-exists conflict.
- `AppDelegate` created history with a standard titled `NSWindow` and called `NSApp.activate(ignoringOtherApps:)`; macOS therefore activated the app on its own Space when invoked over a fullscreen application.
- The overlay initially hid itself synchronously from `resignKey()`. Opening a SwiftUI detail Sheet also makes the parent resign key status, so the parent was hidden while its modal Sheet remained active.

### Verification

- Added five unit tests covering one-time launch reminders, repeat reminders on blocked paste, granted-permission behavior, the Accessibility System Settings URL, and the system authorization adapter.
- The final full test suite passed with 120 tests and 0 failures after the permission reminder integration; the new service reached 87.88% line coverage.
- Added regression coverage for focus-ring suppression, previous-app selection and activation, and application-level shortcut-service reuse; the targeted suite passed with 7 tests and 0 failures.
- The final full test suite passed with 115 tests and 0 failures.
- Added timeline organization tests for recent/today/earlier grouping, empty-group omission, and deduplicated source ordering; the targeted suite passed with 8 tests and 0 failures.
- Completed a same-canvas visual comparison against design option 3; `design-qa.md` records a passing result with no actionable P0/P1/P2 findings.
- Added brand and row-interaction regression tests; the final full test suite passed with 107 tests and 0 failures.
- App icon verification passed for all 10 macOS icon slots and both 18/36-pixel menu bar template assets.
- Release identity and Xcode file-reference validation passed after regenerating the project.
- Added `HistoryPanelWindowTests` for nonactivating style, fullscreen auxiliary behavior, cross-Space behavior, popup level, key input support, transparency, and top-center positioning.
- Added focus-policy regression tests covering attached Sheets, regained key status, and genuine outside focus changes.
- Targeted window tests passed with 7 tests and 0 failures; the window module remains above 96% line coverage.
- The overlay regression test suite passed with 105 tests and 0 failures before the branding and direct-paste additions.
- Manual fullscreen verification remains required against representative native and third-party applications.

### Compatibility

- No database migration, data repair, new permission, or clipboard-history format change is required.

## 2026-07-02

### Added

- Initialized git repository.
- Installed and used XcodeGen to generate `MacPasteHistory.xcodeproj`.
- Added initial macOS SwiftUI app structure under `MacPasteHistory/`.
- Added menu bar status item, main window, settings window, Application Support directory setup, SQLite opening, logging, and default settings.
- Added initial unit tests for default settings.
- Added text clipboard monitoring based on pasteboard `changeCount`.
- Added plain text reading, text hash normalization, restore skip guard, and clipboard writing.
- Added SQLite migration tracking and the `clipboard_history` table.
- Added `ClipboardHistoryRepository` for text save, dedupe, search, delete, and clear operations.
- Added main panel text history list with search, previews, relative time, restore, delete, and clear actions.
- Added unit tests for text hash, pasteboard reading/writing, monitor behavior, and repository behavior.
- Added bounded history previews, friendly time formatting, detail viewing, favorite/unfavorite actions, favorites-only filtering, content type filtering, and paginated history loading.
- Added unit tests for history display formatting, favorite persistence, repository filters, repository pagination, and ViewModel filter/loading behavior.
- Added PNG/TIFF image clipboard reading, TIFF-to-PNG normalization, image file and thumbnail storage, image metadata persistence, image hash deduplication, image restore, delete cleanup, and image history previews/detail display.
- Added Finder image file copy detection through pasteboard file URLs, with non-image file URLs ignored.
- Added tests for image reading, storage limits, thumbnail creation, repository metadata, monitor image capture, recording gating, restore, and cleanup.
- Added tests for Finder image file URL reading and non-image file URL skipping.
- Added persisted total storage cap configuration and wired cleanup to use the total storage cap instead of the single-image size limit.
- Stabilized image dimension tests by generating deterministic pixel-sized bitmap fixtures.
- Added tests for total storage cap defaults and persistence.
- Added release user guide and privacy policy drafts.
- Added XcodeGen-managed entitlements wiring and Release build optimization/signing settings for local release validation.
- Added a local Release smoke-test script for sandbox entitlement, launch, text capture, image capture, and quit validation.
- Extended the Release smoke-test script to cover large text, large image metadata, and expired image startup cleanup.
- Extended the Release smoke-test script to launch a temporary installed app copy, verify restart persistence, and validate Release startup cleanup for count limits, favorite preservation, and storage caps.
- Extended the Release smoke-test script to verify oversized images are skipped without database records, original files, or thumbnail files.
- Updated the Release smoke-test script to launch the Release app with an isolated temporary App Support directory so synthetic QA data does not touch the user's real history database.
- Added an `ApplicationSupportService` override path for isolated release and test runs.
- Added `scripts/preview-release-app.sh` for repeatable local Release preview, with optional isolated data mode for manual QA.
- Added `scripts/seed-preview-data.sh` and `scripts/preview-release-app.sh --seed-preview-data` so local Release previews can launch with synthetic text and image history in an isolated App Support directory.
- Added `docs/release/manual-qa-record.md` to capture manual release evidence that cannot be proven by automation.
- Added `scripts/release-qa-baseline.sh` to generate Markdown baseline evidence for manual Release QA records.
- Added `scripts/package-release-qa-build.sh` to create a zipped Release QA package, checksum, and manifest for cross-machine compatibility testing.
- Added `scripts/verify-release-qa-package.sh` to validate QA package checksums, app bundle metadata, architectures, signing, and Sandbox entitlement before manual testing.
- Added `scripts/generate-manual-qa-fixtures.swift` to create synthetic text, code, chat, large-text, and image fixtures for manual common-app Release QA.
- Added `scripts/start-manual-release-qa-session.sh` to prepare a timestamped manual Release QA session workspace with package artifacts, verification output, baseline evidence, fixtures, and a QA record copy.
- Added `scripts/validate-manual-qa-record.sh` to catch incomplete manual Release QA records before final release approval.
- Added `scripts/validate-xcode-file-references.sh` to regenerate the Xcode project and verify Swift file references resolve to real files.
- Wired Xcode file-reference validation into Release preview, QA packaging, and Release smoke-test build entry points, with a lock around XcodeGen so concurrent release scripts do not corrupt or race project generation.
- Added `scripts/release-readiness-report.sh` to aggregate Xcode file references, Xcode authorization, signing identities, release docs, screenshot assets, manual QA record validation, and git status into a final Markdown readiness report.
- Added `scripts/prefill-manual-qa-record.sh` and wired it into manual Release QA session setup so objective build, package, signing, current-machine, and fixture fields are filled without marking manual QA scenarios as passed.
- Added `scripts/scan-privacy-log-safety.sh`, switched the central Logger wrapper to OSLog private privacy by default, and wired the scan into the release readiness report.
- Added `scripts/verify-privacy-usage-descriptions.sh` and wired Info.plist privacy usage description validation into the release readiness report.
- Added `scripts/release-install-preflight.sh` to copy a Release app into a temporary install directory, launch it with isolated sandbox-container data, verify SQLite schema initialization, and confirm quit behavior.
- Wired the Release install preflight into `scripts/release-readiness-report.sh` so the final readiness gate launches a copied Release app, verifies isolated local storage initialization, and confirms quit behavior by default.
- Wired `scripts/release-smoke-test.sh` into `scripts/release-readiness-report.sh` so the final readiness gate also runs sandbox, synthetic clipboard capture, restart persistence, large-content, oversized-image, and cleanup checks by default.
- Required explicit double-click paste evidence in the manual Release QA record and validator.
- Required manual Release QA records to retain the expected environment, common-app, and privacy/safety evidence rows.
- Scoped manual Release QA required-row validation to the matching Markdown sections so misplaced rows do not satisfy the checklist.
- Added reproducible App Icon generation and verification scripts, generated the macOS AppIcon PNG set, and wired icon verification into the release readiness report.
- Added `scripts/verify-release-screenshot-assets.sh` and wired screenshot PNG dimension validation into the release readiness report.
- Added `scripts/verify-manual-qa-fixtures.sh` and wired synthetic manual QA fixture generation validation into the release readiness report.
- Updated manual Release QA session README generation to list the required static release checks, install preflight, manual-record validation, and final readiness report in execution order.
- Added `--json-output` to `scripts/release-readiness-report.sh` so release gates can emit a machine-readable status, checks, blockers, warnings, and remaining evidence summary alongside Markdown.
- Added `--strict-final` to `scripts/release-readiness-report.sh` so final distribution checks fail when any warning remains.
- Added `scripts/verify-supported-macos-targets.sh` and wired it into release readiness checks to keep project, Info.plist, release docs, and macOS QA matrix support targets aligned.
- Added `scripts/verify-release-version-build.sh` and wired it into release readiness checks to keep Info.plist, release docs, and manual QA version/build declarations aligned.
- Added `scripts/verify-release-entitlements.sh` and wired it into release readiness checks to keep App Sandbox enabled while broad network, USB, and user-selected file access entitlements remain disabled.
- Added `scripts/verify-release-identity.sh` and wired it into release readiness checks to keep Bundle ID, product name, Info.plist path, and menu bar app identity aligned.
- Added `scripts/verify-xcode-authorization.sh` and wired release readiness Xcode authorization to its real PASS/FAIL status instead of reporting authorization as PASS when blockers exist.
- Added `scripts/verify-signing-identities.sh` and wired release readiness signing checks to report formal distribution failures and internal QA ad-hoc warnings consistently.
- Added `scripts/verify-release-app-signature.sh` and wired release readiness to verify the built Release app's signature, Team ID, Bundle ID, and Sandbox entitlement.
- Added `scripts/verify-manual-release-qa-session.sh` and wired manual QA session creation to generate `session-verification.md` for package, checksum, manifest, baseline, fixture, record, and README completeness.
- Added `--qa-session` to `scripts/release-readiness-report.sh` so final readiness checks can validate the generated manual QA session directory and warn when the session evidence is omitted.
- Added `scripts/verify-release-qa-baseline.sh` and wired manual QA session verification to validate the build, toolchain, signing, Sandbox, common-app, and remaining-evidence baseline fields.
- Added `scripts/verify-release-qa-manifest.sh` and wired manual QA session verification to validate package manifest fields, artifact paths, SHA-256 integrity, and embedded baseline evidence.
- Added the package manifest to manual QA record prefill and validation so final records reference the exact QA package manifest under test.
- Wired manual QA record validation to verify the referenced Package manifest file instead of only checking that the field is present.
- Wired manual QA record validation to reject Package manifests whose embedded baseline was generated from a dirty git worktree.
- Wired manual QA record validation to verify App path exists and matches the Packaged app listed in the Package manifest.
- Wired manual QA record validation to compare the recorded Package SHA-256 against the checksum file referenced by the Package manifest.
- Wired manual QA record validation to compare the Package verification summary against the manifest signature, Team ID, Sandbox, and checksum success result.
- Wired manual QA record validation to verify the referenced Fixture directory exists and contains the generated manual QA samples.
- Wired manual QA record validation to compare the recorded Git commit against the Package manifest commit.
- Wired manual QA record validation to compare the recorded Version / build against the Package manifest version.
- Wired manual QA record validation to compare the recorded Signing identity against the Package manifest signature, Team, and Sandbox state.
- Wired manual QA record validation to reject `Filled` placeholders in addition to `TBD` and `Not run`.
- Wired manual QA record validation to require the final Decision rows for readiness, blockers, follow-ups, and approver.
- Added OpenSpec release-change progress to `scripts/release-readiness-report.sh` so readiness reports and JSON output list the exact remaining release tasks.
- Added double-click paste from the history list: a successful restore closes the history window, reactivates the previous foreground app, and sends `Command + V`.
- Added `PasteCommandService` and tests for restore success/failure reporting plus paste command dispatch.
- Added a local release environment report script and snapshot for Xcode status, signing identities, machine architecture, macOS version, and common-app availability.
- Added `DataCleanupServiceTests` coverage for expired image file cleanup.
- Added `DataCleanupServiceTests` coverage for text count limits, image count limits, favorite-preserving image count limits, and image storage cap cleanup.
- Added `ClipboardDataClearService` and unit coverage for clearing all database records plus image and thumbnail files.
- Added `LoginItemService` using `SMAppService.mainApp` for the settings launch-at-login toggle, with service and ViewModel regression tests.
- Added reproducible release screenshot generation with synthetic, non-private App Store screenshot assets under `docs/release/screenshots/`.
- Fixed expired image cleanup so original and thumbnail files are removed before expired database rows are deleted.
- Fixed cleanup count-limit eviction so favorites count toward the configured total limit while remaining protected from deletion.
- Fixed main-list restore actions so mouse restore and Enter restore both write the selected item to the clipboard before showing feedback.
- Fixed image capture so the single-image size limit setting is read dynamically when saving images.

### Verification

- `xcodebuild build` passed for `MacPasteHistory`.
- `xcodebuild test` passed with 49 tests and 0 failures.
- `xcodebuild -configuration Release build` passed and produced a locally signed Release app.
- `codesign -d --entitlements :-` confirmed the Release app includes App Sandbox entitlements.
- `scripts/release-smoke-test.sh` passed on the current Apple Silicon Mac with a temporary installed app copy, isolated App Support directory, synthetic clipboard text, large text, PNG, large PNG, oversized-image skip, restart persistence, expired image cleanup, count-limit cleanup, favorite preservation, and storage-cap cleanup data.
- `scripts/preview-release-app.sh --help` and `scripts/preview-release-app.sh --build-only` passed, confirming the preview helper can build Release and print the current app path.
- `scripts/seed-preview-data.sh build/preview-seed-verify.*` generated an isolated preview database with 4 text items, 2 image items, and matching image/thumbnail files.
- `openspec validate prepare-release-testing-and-store-assets --strict` passed after adding the manual QA evidence template and final checklist corrections.
- Targeted `ApplicationSupportServiceTests` passed with 1 test and 0 failures after adding isolated App Support override coverage.
- Targeted `ImageStorageServiceTests` passed with 3 tests and 0 failures after adding dynamic single-image limit coverage.
- `scripts/release-environment-report.sh` confirmed Xcode is selected and licensed, the current machine is Apple Silicon, Chrome/Safari/VS Code/WeChat/DingTalk are installed, and no valid code signing identities are currently available.
- `xcodebuild -checkFirstLaunchStatus` exited with 0 after selecting `/Applications/Xcode.app/Contents/Developer`, confirming Xcode first-launch authorization is complete.
- Targeted `LoginItemServiceTests` passed with 3 tests and 0 failures after wiring launch-at-login registration.
- Targeted `SettingsViewModelTests` passed with 2 tests and 0 failures after covering settings registration and error rollback.
- `scripts/generate-release-screenshots.swift` generated 4 PNG assets; `file`, `sips`, and visual QA confirmed readable 5760x3600 screenshots without real clipboard data.
- `scripts/start-manual-release-qa-session.sh --help` and `scripts/start-manual-release-qa-session.sh --no-build --output-dir build/manual-release-qa-session-verify` passed, confirming the manual QA session helper can prepare package artifacts, verification output, baseline evidence, fixtures, and a QA record copy from the current Release build.
- `scripts/start-manual-release-qa-session.sh --no-build --output-dir build/manual-release-qa-session-prefill-verify` generated a prefilled QA record copy, and `scripts/validate-manual-qa-record.sh` correctly kept it failing because manual scenarios and distribution signing remain incomplete.
- `scripts/validate-manual-qa-record.sh docs/release/manual-qa-record.md` correctly failed on the unfilled template, and the same script passed against a filled synthetic record in `build/manual-qa-record-validate-pass.md`.
- `scripts/validate-xcode-file-references.sh` passed after regenerating `MacPasteHistory.xcodeproj`, checking that all Swift references, including `MacPasteHistory/Services/PrivacyService.swift`, resolve to existing files.
- `scripts/release-readiness-report.sh --output build/release-readiness-report.md` correctly failed on the current unfilled manual QA record and missing signing identities while passing Xcode, docs, and screenshot checks.
- `scripts/release-readiness-report.sh --allow-adhoc --manual-record build/manual-qa-record-validate-pass.md --output build/release-readiness-pass.md` passed against a filled synthetic record, with missing signing identities downgraded to an internal-QA warning.
- `scripts/scan-privacy-log-safety.sh` passed on current app sources, and a temporary violating Swift sample correctly failed for direct console logging and raw clipboard-content logging.
- `scripts/verify-privacy-usage-descriptions.sh` passed, confirming Info.plist includes non-placeholder pasteboard and accessibility usage descriptions.
- `scripts/release-install-preflight.sh --no-build` passed, confirming a copied Release app can launch from a temporary install directory, create isolated local storage in the app sandbox container, and quit cleanly.
- `scripts/release-readiness-report.sh` now includes the Release install preflight by default; final release remains blocked until signing identities and filled manual QA evidence are available.
- `scripts/release-smoke-test.sh` now emits `Status: PASS`, and the readiness report includes it by default before running install preflight with the existing Release build.
- `scripts/validate-manual-qa-record.sh --allow-adhoc build/manual-qa-record-validate-pass.md` correctly failed until the synthetic record included the required double-click paste workflow row.
- `scripts/validate-manual-qa-record.sh --allow-adhoc build/manual-qa-record-missing-matrices.md` correctly failed when required environment, common-app, or privacy rows were removed.
- `scripts/validate-manual-qa-record.sh --allow-adhoc build/manual-qa-record-wrong-section-row.md` correctly failed when a required common-app row appeared outside the Common App Copy Matrix section.
- `scripts/generate-app-icon.swift` generated all 10 macOS AppIcon PNG slots, and `scripts/verify-app-icon-assets.sh` confirmed unique filenames and expected pixel dimensions.
- `scripts/verify-release-screenshot-assets.sh` confirmed all 4 release screenshots are readable 5760x3600 PNG files.
- `scripts/verify-manual-qa-fixtures.sh` generated and validated the browser, VS Code, chat, large-text, standard-image, large-image, and README fixtures.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-green.json --output build/release-readiness-green.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with 13 checks and expected internal-QA warnings.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-template-fail.json --output build/release-readiness-template-fail.md --skip-release-smoke --skip-install-preflight --manual-record docs/release/manual-qa-record.md` exited 1 and produced a valid `fail` JSON summary listing missing signing identity and incomplete manual QA record blockers.
- `scripts/release-readiness-report.sh --strict-final --json-output build/release-readiness-strict-fail.json --output build/release-readiness-strict-fail.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` exited 1 and produced a valid `fail` JSON summary because strict final mode treats warnings as blockers.
- `scripts/verify-supported-macos-targets.sh` passed, confirming project.yml, Info.plist, release guide, and manual QA record all align on the macOS 14.0+ support target and required macOS coverage rows.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-macos-targets.json --output build/release-readiness-macos-targets.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with the Supported macOS targets check included.
- `scripts/verify-release-version-build.sh` passed, confirming Info.plist, release guide, and manual QA record all align on version `0.1.0 (1)`.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-version-build.json --output build/release-readiness-version-build.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with the Release version and build check included.
- `scripts/verify-release-entitlements.sh` passed, confirming `project.yml` binds `MacPasteHistory/MacPasteHistory.entitlements`, App Sandbox is enabled, and broad network, USB, and user-selected file access entitlements are disabled.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-entitlements.json --output build/release-readiness-entitlements.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with the Release entitlements check included.
- `scripts/verify-release-identity.sh` passed, confirming `com.peibin.MacPasteHistory`, `MacPasteHistory`, the handwritten Info.plist path, and `LSUIElement = true`.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-identity.json --output build/release-readiness-identity.md --skip-release-smoke --skip-install-preflight --allow-adhoc --manual-record build/manual-qa-record-double-click-pass.md` produced a valid `pass` JSON summary with the Release identity check included.
- `scripts/verify-xcode-authorization.sh` passed, confirming `/Applications/Xcode.app/Contents/Developer`, Xcode first-launch authorization, and Xcode license acceptance.
- `scripts/verify-signing-identities.sh --allow-adhoc` returned `WARN`, confirming the current machine still has `0 valid identities found` and formal distribution remains blocked until an Apple signing identity is installed.
- `scripts/verify-release-app-signature.sh --allow-adhoc` returned `WARN`, confirming the current Release app is `Signature=adhoc`, `TeamIdentifier=not set`, and Sandbox-entitled for internal QA only.
- `scripts/verify-manual-release-qa-session.sh <session-dir>` passed for a generated internal QA session, confirming package, checksum, manifest, package verification, baseline, fixtures, manual record copy, and README are present before manual testing.
- `scripts/release-readiness-report.sh --qa-session <session-dir> ...` produced a valid JSON summary with a passing Manual QA session check, while omitting `--qa-session` keeps a warning for strict final gates.
- `scripts/verify-release-qa-baseline.sh <baseline.md>` passed for a generated internal QA baseline and failed against an intentionally incomplete sample.
- `scripts/verify-release-qa-manifest.sh <manifest.md>` passed for a generated internal QA manifest and failed against an intentionally incomplete sample.
- `scripts/validate-manual-qa-record.sh --allow-adhoc build/manual-qa-record-double-click-pass.md` now fails when the required Package manifest field is absent.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when Package manifest points to a missing file and passes when it points to a valid generated manifest.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when the referenced Package manifest embeds a dirty Git worktree baseline.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when App path is missing, not a `.app`, or does not match the manifest Packaged app.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when Package SHA-256 differs from the manifest checksum file and passes when both values match.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when Package verification reports a mismatched signature, Team, Sandbox, or missing checksum success result.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when Fixture directory points to a missing or invalid generated fixture set.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when the record Git commit differs from the referenced Package manifest commit.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when the record Version / build differs from the referenced Package manifest version.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when the record Signing identity differs from the referenced Package manifest signature, Team, or Sandbox state.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when table rows still contain `Filled` placeholders.
- `scripts/validate-manual-qa-record.sh --allow-adhoc <record>` now fails when a required final Decision row is missing.
- `scripts/release-readiness-report.sh --json-output build/release-readiness-openspec-green.json ...` produced `openSpecProgress` as 4/19 with 15 remaining tasks and an OpenSpec progress warning.
- Targeted `ClipboardHistoryViewModelTests` and `PasteCommandServiceTests` passed with 9 tests and 0 failures after adding double-click paste support.
- `scripts/preview-release-app.sh --build-only` and `scripts/package-release-qa-build.sh --output-dir build/release-qa-entry-verify` passed in parallel after wiring Xcode file-reference validation into release entry points and serializing XcodeGen.
- `scripts/release-smoke-test.sh` passed after wiring Xcode file-reference validation into the Release smoke build entry point.
- Targeted `ClipboardDataClearServiceTests` passed with 1 test and 0 failures after extracting clear-all behavior into a service.
- Targeted `DataCleanupServiceTests` passed with 5 tests and 0 failures after adding count-limit and storage-cap cleanup coverage.
- Targeted `DataCleanupServiceTests` passed after reproducing and fixing expired image file cleanup.
- Targeted `ClipboardReaderTests` passed with 7 tests and 0 failures after adding Finder image file URL coverage.
- Targeted `ClipboardReaderTests`, `ClipboardMonitorTests`, and `UserDefaultsConfigTests` passed with 14 tests and 0 failures after fixing image fixture dimensions and storage cap persistence.

### Risks

- Text history still needs manual GUI verification for real app copy, restart, restore, delete, and clear workflows.
- History experience still needs manual GUI verification for large-list scroll smoothness and detail interaction polish.
- Image history still needs manual GUI verification for screenshot capture, browser-copied images, and pasting restored images into real apps.
- Release preparation still needs Apple Developer signing certificates, manual sandbox runtime QA, compatibility, common-app QA, and screenshot verification.
