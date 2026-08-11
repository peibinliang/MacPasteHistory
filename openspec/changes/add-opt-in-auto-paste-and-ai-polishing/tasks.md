## 1. Baseline And Failing Tests

- [x] 1.1 Record the current launch Accessibility reminder and every history/action-output path that dispatches `PasteCommandService`, then add regression test seams for those paths.
- [x] 1.2 Add failing `UserDefaultsConfig` and `SettingsViewModel` tests for a default-off Automatic Paste preference, persistence, pending permission state, and disabling behavior.
- [x] 1.3 Add failing policy/view-model tests proving clipboard restore succeeds without Command-V when Automatic Paste is off or permission is unavailable, and paste accounting increments only after dispatch.
- [x] 1.4 Add failing tests for the default model identifier, model validation, remote-processing acknowledgment, credential status, and token-summary settings state.

## 2. Opt-In Automatic Paste

- [x] 2.1 Add the centralized default and persisted `automaticPasteEnabled` configuration with `false` as the fallback for new and existing installations.
- [x] 2.2 Introduce a testable automatic-paste policy/service that combines the saved preference with the live Accessibility trust state and returns clipboard-only, permission-required, or ready outcomes.
- [x] 2.3 Remove the launch-time Accessibility reminder from `AppDelegate` while preserving the permission service and System Settings deep link for explicit enablement and blocked attempts.
- [x] 2.4 Add the localized Automatic Paste settings toggle, explanation, enabled-but-permission-required status, and Open System Settings action.
- [x] 2.5 Route history-item activation, keyboard activation, and action-output paste through the shared policy so all paths restore first, dispatch only when allowed, and show manual-paste fallback consistently.
- [x] 2.6 Update reuse copy/paste accounting so clipboard-only outcomes never increment successful paste counts.

## 3. Token Usage Persistence

- [x] 3.1 Add failing migration tests for upgrading a version-3 database and initializing a new database with the additive `ai_token_usage` table, constraints, and aggregation indexes.
- [x] 3.2 Add the next `MigrationManager` migration with provider, model, input, output, total, optional cached-input tokens, and timestamp fields while storing no prompt or response content.
- [x] 3.3 Add an `AITokenUsageRecord` model and repository with validated single-response insertion, per-model/all-model aggregation, and deletion APIs.
- [x] 3.4 Add repository tests for exact-once insertion, non-negative validation, missing optional cache counts, aggregation, failure rollback, and deletion.
- [x] 3.5 Extend the confirmed clear-all-data flow and tests to delete AI token-usage records without silently deleting the separately managed Keychain credential.

## 4. Credential And DeepSeek Client

- [x] 4.1 Add a Keychain credential-store protocol and Security-framework adapter for save, read, replace, existence, and delete operations using stable service/account identifiers.
- [x] 4.2 Add credential-store tests with an in-memory fake plus focused adapter verification; ensure failed replacement preserves the last valid key and no plaintext fallback exists.
- [x] 4.3 Add request/response models for DeepSeek chat completion, including returned polished text and provider-reported input, output, total, and cached-input usage fields.
- [x] 4.4 Implement an injected-`URLSession` DeepSeek client using the centralized HTTPS endpoint, configured model, bounded timeout/output, versioned polishing instruction, and non-thinking mode when supported.
- [x] 4.5 Add mock-network tests for request authorization/model/body, success decoding, missing usage, empty/malformed/oversized output, authentication failure, rate limiting, server/network failure, timeout, and cancellation.
- [x] 4.6 Add a privacy-focused logging test or scan assertion proving request bodies, source text, responses, prompts, and API keys are absent from diagnostics.

## 5. AI Polishing Action And Usage Accounting

- [x] 5.1 Add a narrowly scoped asynchronous content-action contract and executor path without changing the synchronous contract used by existing local actions.
- [x] 5.2 Implement `AITextPolishingService` to load the credential/model, execute one request, validate the result, insert authoritative usage at most once, and return usable output even when usage is absent.
- [x] 5.3 Register AI Polishing only for textual detected types and add localized action metadata and accessibility labels.
- [x] 5.4 Extend `ContentActionPanelViewModel` to own and cancel remote execution tasks, ignore stale results, and reuse existing executing, previewing, failed, editing, copy, derived-save, and paste flows.
- [x] 5.5 Add action/service/view-model tests for applicability, missing credentials, first-use disclosure acceptance/decline, successful preview, editable output, cancellation, stale response suppression, retryable errors, and no usage insert on failed requests.
- [x] 5.6 Display per-request provider-reported input/output/total tokens in the result surface, or an explicit unavailable state when the provider omits usage.

## 6. AI Settings And Privacy UX

- [x] 6.1 Add non-secret configuration keys for the default `deepseek-v4-flash` model, custom non-empty model identifier, and remote-processing acknowledgment.
- [x] 6.2 Add an AI settings section for model editing/reset, transient API-key entry, stored-key status, replacement, and confirmed removal without revealing the full credential.
- [x] 6.3 Add locally aggregated all-model and per-model input/output/total token summaries to settings with explicit provider-reported labeling.
- [x] 6.4 Add the first-use remote-processing disclosure and ensure declining it sends no request and leaves all local clipboard features available.
- [x] 6.5 Add Simplified Chinese, Traditional Chinese, and English strings for settings, disclosure, progress, token labels, permission states, manual-paste fallback, and actionable AI errors.
- [x] 6.6 Add localization coverage and accessibility-presentation tests for every new user-facing string and interactive control.

## 7. Documentation And Project Integration

- [x] 7.1 Update `project.yml` only if required for new files, regenerate `MacPasteHistory.xcodeproj`, and verify every Swift source reference resolves.
- [x] 7.2 Update architecture and database documentation with the automatic-paste policy, remote AI data flow, Keychain boundary, migration schema, and token aggregation behavior.
- [x] 7.3 Update configuration documentation with key names, types, defaults, editable values, runtime behavior, and restart requirements for Automatic Paste and AI settings.
- [x] 7.4 Update the privacy policy and user guide to distinguish local history from explicitly initiated DeepSeek processing, document manual paste, credential removal, and token statistics, and remove the obsolete launch-permission guidance.
- [x] 7.5 Update README files, changelog, and `docs/development-log.md` after implementation without claiming AI text remains local.

## 8. Verification

- [x] 8.1 Run focused unit tests for settings, automatic-paste policy, permission handling, Keychain, DeepSeek client, AI action/view model, migration, repository, clear-all-data, localization, and logging safety.
- [x] 8.2 Run `scripts/validate-xcode-file-references.sh` and the complete macOS XCTest suite with the repository's documented `xcodebuild` command.
- [x] 8.3 Run privacy usage-description and log-safety verification scripts, then inspect `git diff` for leaked credentials, clipboard bodies, prompts, model responses, accidental dependencies, and unrelated changes.
- [ ] 8.4 Manually verify first launch without Accessibility prompts; toggle enablement with permission granted/declined/revoked; clipboard-only fallback; AI consent decline; successful polishing with a synthetic non-sensitive sample; cancellation; offline/auth/rate-limit feedback; token totals; and clear-all-data behavior.
