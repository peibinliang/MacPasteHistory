## Context

See `proposal.md` for motivation. The current capture pipeline reads the source application once for privacy gating and again during text/image persistence; sensitive detection is a broad Boolean regex list; search generation control lives in an actor while the ViewModel does not retain or cancel its Task; restore and paste behavior is spread across the history ViewModel; SQLite configures a busy timeout but has no WAL evidence gate. Existing V1.0.2 databases, user preferences, clipboard-only behavior, shortcuts and UI must remain compatible.

## Goals / Non-Goals

**Goals:**

- Establish one immutable capture context per pasteboard change.
- Make privacy detection composable, explainable, locally testable and safer for developer content.
- Reconcile managed image storage without risking uncertain user files.
- Centralize reuse/paste outcomes and make search cancellation explicit.
- Reduce History ViewModel responsibilities behind narrow protocols without changing user-visible behavior.
- Decide SQLite journal configuration from repeatable concurrency and upgrade evidence.

**Non-Goals:**

- V1.1 Slots, Tags, Smart Collections, App Rules or FTS5.
- Cloud sync, telemetry, remote sensitive detection, shell/SQL execution or new third-party dependencies.
- Developer ID signing, notarization, GitHub Release, Sparkle publication or rewriting historical tags.
- Destructive cleanup of files whose ownership or database relationship is uncertain.

## Decisions

### 1. Pass an immutable capture context through the pipeline

`ClipboardMonitor` will resolve source application metadata and capture time once after accepting a new pasteboard change. Privacy gates and text/image save functions receive that value instead of querying the workspace again. This is preferred over caching a mutable “current source” property because overlapping or delayed work could associate the wrong source.

### 2. Compose focused sensitive detectors behind one result model

Use a value result containing category, confidence and a safe reason code. Credential detection remains context-aware; cards use Luhn; identity values use format/date/check-digit validation; secret detection requires stronger context than length alone. `PrivacyService` may continue exposing a Boolean policy answer for callers, but it derives it from the structured result. A monolithic replacement regex was rejected because it cannot express validation or explain safe false-positive decisions.

### 3. Separate reconciliation scan, plan and apply

Reconciliation first builds a typed inventory from repository metadata and canonical app-managed directories, then produces a repair plan, then applies only proven-safe actions. Missing thumbnails may be regenerated; uncertain orphans are retained and reported. Separating planning from mutation makes dry-run tests, idempotency checks and future user review possible.

### 4. Make PasteCoordinator outcome-oriented

The coordinator accepts content plus target/policy dependencies and returns a typed outcome such as pasted, clipboard-only, permission-required or failed. It owns sequencing and accounting, while UI layers translate outcomes into localized feedback. Existing writer, Automatic Paste policy, permission and command services are injected rather than duplicated.

### 5. Retain and cancel the ViewModel search Task

The Search actor generation remains a final stale-result guard. The ViewModel additionally retains one `Task<Void, Never>`, cancels it before starting another, and does not clear visible results during debounce. The two layers solve different races: cancellation avoids wasted work, generation prevents late commits from dependencies that ignore cancellation.

### 6. Split History ViewModel incrementally behind compatibility-preserving APIs

First extract search task/state and list operations into focused collaborators, then delegate existing public methods so Views and keyboard handling do not require a simultaneous rewrite. A full UI rewrite was rejected because it expands regression risk and violates the stable-version scope.

### 7. Treat WAL as an experiment with a release gate

Add deterministic tests for overlapping reads/writes, busy timeout, rollback, reopen and V1.0.2 upgrade. Record results for DELETE journal mode and WAL. Enable WAL only if the full matrix passes and lifecycle ownership for checkpoints is explicit; otherwise retain the existing mode and document the evidence. This avoids treating a theoretical performance improvement as an automatic production change.

### 8. Use task-sized TDD checkpoints

Each behavior task follows RED → minimal GREEN → optional refactor, with checkpoint commits reachable from `release/v1.0.3`. Documentation, localization and verification are part of the same version branch. Manual evidence requiring external credentials or hardware remains unchecked and is referenced from `docs/planning/PENDING_DECISIONS.md`.

## Risks / Trade-offs

- [Existing tests may rely on the broad sensitive regex behavior] → Add explicit positive and negative sample tables first, then document intentional classification changes.
- [Reconciliation could delete valid data] → Default to scan/report, restrict paths to canonical managed roots, make actions idempotent, and never delete uncertain files.
- [Coordinator extraction could change feedback or usage counts] → Capture current behavior in characterization tests before moving code and assert typed outcomes at every fallback.
- [ViewModel split can cause Swift concurrency/sendability regressions] → Extract one responsibility at a time and keep MainActor boundaries explicit.
- [WAL may leave sidecar files or create upgrade surprises] → Test reopen/checkpoint/recovery and retain DELETE mode unless every gate passes.
- [Version scope is large] → Execute one numbered task at a time and require targeted QA plus independent review before moving to the next capability.

## Migration Plan

1. Add behavior tests and capture-context/sensitive-result models without changing persisted schema.
2. Land source consistency and Sensitive Detector V2, then run privacy regression checks.
3. Add reconciliation in report-first form; enable only proven-safe repair actions.
4. Extract search cancellation and PasteCoordinator with characterization tests.
5. Split ViewModel responsibilities without changing the public View contract.
6. Run SQLite experiments; apply a configuration change only when evidence passes. If schema changes become necessary, add the next immutable migration and an old-database upgrade fixture.
7. Update V1.0.3 metadata, three localizations, docs and CHANGELOG; run full verification and independent review.
8. Merge the completed release branch back to `main` only after all non-release gates pass. Tag creation and external release actions remain separate and require their own approval/gates.

Rollback is commit-based per TDD task. No published database migration will be edited, and any new migration must be forward-compatible so reverting application code does not destroy existing user history.

## Open Questions

- Tag capitalization and treatment of historical manual release evidence are tracked as PD-002 and PD-003 in `docs/planning/PENDING_DECISIONS.md`; neither changes this implementation design.
