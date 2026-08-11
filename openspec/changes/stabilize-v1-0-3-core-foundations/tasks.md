## 1. Baseline And Version Guardrails

- [x] 1.1 Run the current full test suite, Debug build, file-reference validation, and privacy log scan; record baseline failures without changing production behavior
- [x] 1.2 Inventory the current version metadata and synthetic migration fixtures, document the missing shipped-build database fixture, and define V1.0.3 upgrade and rollback assumptions
- [x] 1.3 Commit the validated OpenSpec requirements, design, task breakdown, and pending-decision list on `release/v1.0.3`

## 2. Clipboard Source Capture Consistency

- [x] 2.1 Add failing text and image tests proving the source provider is called once and a foreground-app switch after capture-context creation cannot change blocked-app privacy or persisted source; validate RED and commit the test checkpoint
- [x] 2.2 Introduce an immutable capture context and pass it through privacy, text/image persistence, and capture-event creation; validate targeted GREEN and commit the implementation checkpoint
- [x] 2.3 Add unknown-source and duplicate-capture regression coverage, update capture/privacy development docs, and run the capture QA subset

## 3. Sensitive Detector V2

- [x] 3.1 Add table-driven failing positive/negative tests for passwords, API tokens, authorization headers, Luhn-valid/invalid cards, valid/invalid identity values, Git SHA, MD5, UUID, trace IDs, and unlabelled long strings; validate RED and commit the test checkpoint
- [x] 3.2 Add structured detection result and focused local credential, card, identity, secret, and user-rule detector boundaries; adapt PrivacyService policy with minimal caller changes, validate GREEN, and commit the implementation checkpoint
- [x] 3.3 Verify no secret values enter logs, update three-language user feedback where classification is exposed, and update privacy/development documentation

## 4. Storage Reconciliation

- [x] 4.1 Add failing inventory/plan tests for retained missing originals, retained orphaned managed files, missing thumbnails, retained corrupted images, the 24-hour app-owned temporary-file rule, uncertain ownership, per-item failures, and repeat runs; validate RED and commit the test checkpoint
- [x] 4.2 Implement canonical managed-path inventory plus non-mutating reconciliation planning; validate report-only GREEN and commit the checkpoint
- [x] 4.3 Implement only proven-safe idempotent repairs: thumbnail regeneration and deletion of unreferenced app-owned temporary files older than 24 hours; retain missing originals, corrupted images, orphaned images and uncertain files; validate GREEN and commit the checkpoint
- [x] 4.4 Integrate reconciliation at a non-blocking lifecycle boundary, add failure-summary QA, and update storage/database/architecture documentation

## 5. Search Task Lifecycle

- [x] 5.1 Add failing ViewModel tests for explicit superseded-task cancellation, latest-result ownership, pending-result continuity, error preservation, and rapid input; validate RED and commit the test checkpoint
- [x] 5.2 Retain and cancel the ViewModel search Task while preserving SearchCoordinator generation checks and existing visible results; validate targeted GREEN and commit the implementation checkpoint
- [x] 5.3 Run search correctness/performance regression tests and update search architecture/development documentation

## 6. Unified Paste Coordination

- [x] 6.1 Add characterization and failing tests for history restore, action-output paste, clipboard write failure, disabled Automatic Paste, missing Accessibility permission, missing target app, successful dispatch, cancellation, feedback, and exact usage accounting; validate RED and commit the test checkpoint
- [x] 6.2 Implement typed PasteCoordinator outcomes by composing existing writer, policy, permission, target activation, command, and accounting dependencies; validate service-level GREEN and commit the checkpoint
- [x] 6.3 Delegate history and content-action reuse paths to PasteCoordinator without changing shortcuts or UI behavior; validate integration GREEN and commit the checkpoint
- [x] 6.4 Update automatic-paste, Accessibility, architecture, privacy and user-guide documentation plus three-language feedback coverage

## 7. History ViewModel Architecture Convergence

- [ ] 7.1 Add characterization tests for current list loading, selection, filters, search, restore, delete, favorite, derived-item, keyboard and feedback behavior
- [ ] 7.2 Extract focused list/search/selection collaborators behind narrow protocols while preserving the existing View-facing API; run the full ViewModel test suite and commit the refactor checkpoint
- [ ] 7.3 Verify MainActor and cancellation boundaries under rapid UI interaction, update architecture documentation, and confirm no View gained database or paste business logic

## 8. SQLite Concurrency Governance

- [ ] 8.1 Add a representative V1.0.2 build 4 database fixture plus deterministic integration tests for overlapping capture writes/search reads, bounded busy handling, rollback, reopen, sidecar lifecycle, same-second recapture ordering/time precision, and fixture upgrade under the current journal mode
- [ ] 8.2 Run the same matrix with WAL as an isolated experiment and record comparative correctness/performance evidence
- [ ] 8.3 Keep the current journal mode if any gate fails, or implement/document explicit WAL, busy timeout, checkpoint and transaction ownership if every gate passes; commit the evidence-backed decision
- [ ] 8.4 Update immutable migration, schema, architecture and recovery documentation only if the accepted configuration requires them; validate old-database upgrade again

## 9. V1.0.3 Product And Documentation Completion

- [ ] 9.1 Update bundle version/build metadata to V1.0.3, README, English README, User Guide, development log and CHANGELOG without performing external release actions
- [ ] 9.2 Complete English, Simplified Chinese and Traditional Chinese localization coverage and required Accessibility labels for changed user-visible states
- [ ] 9.3 Update privacy policy, database/storage docs and release notes to match the final implementation, or explicitly document why a file was unaffected
- [ ] 9.4 Resolve or retain every entry in `docs/planning/PENDING_DECISIONS.md` with current status and evidence; do not mark externally blocked evidence complete

## 10. QA, Independent Review And Merge Gate

- [ ] 10.1 Run file-reference validation, `git diff --check`, Debug build, complete tests with coverage evidence, migration/upgrade tests, privacy/log scan and relevant release-readiness scripts
- [ ] 10.2 Run manual macOS smoke QA for text/image capture, blocked-app race, search typing, restore, Automatic Paste fallback, actions, cleanup/reconciliation, settings, shortcuts and relaunch; record unavailable hardware/credentials as pending decisions
- [ ] 10.3 Have an independent QA subagent inspect acceptance evidence and an independent reviewer subagent audit correctness, privacy, migration safety, test gaps and documentation consistency
- [ ] 10.4 Fix all blocking review findings, rerun affected and full verification, and obtain clean follow-up reviews
- [ ] 10.5 Confirm all OpenSpec tasks and Definition of Done gates are complete, validate the change with OpenSpec strict mode, review the final diff and confirm a clean worktree
- [ ] 10.6 Merge `release/v1.0.3` back to local `main` only after every non-release gate passes; do not push, tag, publish, sign or notarize without the corresponding external-action approval
