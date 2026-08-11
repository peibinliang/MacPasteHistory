## Context

The current app restores clipboard items and then directly uses `PasteCommandService` after checking `AccessibilityPermissionService`. `AppDelegate` also schedules an Accessibility reminder at every untrusted first launch. There is no persisted Automatic Paste preference, so users cannot choose a clipboard-only workflow.

Local deterministic transforms already use the `ContentAction` registry, executor, action session, and preview UI. Their execution contract is synchronous except for image loading, while AI polishing introduces cancellable network work, credential handling, remote privacy disclosure, and durable usage metrics. SQLite currently has migrations through version 3, and non-secret settings use `UserDefaultsConfig`.

DeepSeek's official API documentation currently identifies `deepseek-v4-flash` as the Flash model and reports billing based on provider token usage. The implementation must treat the server response as the usage authority instead of estimating locally.

## Goals / Non-Goals

**Goals:**

- Centralize the decision to dispatch Command-V so every history and action-output paste path obeys one persisted setting and the live system-permission state.
- Reuse the existing content-action selection, session, preview, copy, derived-save, and paste UI for AI output.
- Add one well-bounded asynchronous action path without converting every deterministic local action to a network abstraction.
- Keep secrets in Keychain and persist only non-secret AI configuration and aggregateable token usage.
- Preserve a fully functional local clipboard workflow when AI is unconfigured, offline, declined, or failing.

**Non-Goals:**

- Building a general agent platform, chat history, prompt editor, provider marketplace, or automatic/background polishing.
- Uploading clipboard history in bulk, sending images, or using history records as conversational memory.
- Supporting arbitrary OpenAI-compatible endpoints in this change; the first implementation targets DeepSeek's HTTPS API.
- Streaming output, local token estimation, cost estimation, or billing reconciliation.
- Revoking macOS Accessibility permission on behalf of the user when the setting is disabled.

## Decisions

1. Gate automatic paste through a shared policy backed by `UserDefaultsConfig`.

   Add a default-off Boolean in `DefaultSettings` and `UserDefaultsConfig`. A small policy/service receives the preference and current Accessibility state and returns one of: clipboard-only, ready-to-auto-paste, or permission-required. `MainPanelView` and action-output paste paths call view-model/service methods that use this policy rather than duplicating permission checks in SwiftUI closures. This preserves the existing restore operation while preventing any synthetic key event when the setting is off.

   The alternative of checking the setting only in `PasteCommandService` was rejected because the caller still needs to decide whether to close/activate the previous application and which feedback to present.

2. Remove launch-time Accessibility guidance and initiate it from the setting transition.

   `AppDelegate` will no longer schedule the launch reminder. Turning Automatic Paste on persists the preference immediately; if trust is missing, settings presents an explanation and an explicit Open System Settings action. The enabled state can remain pending so that granting access in System Settings makes the feature ready without a second toggle. Every actual paste attempt rechecks trust because macOS permission can be revoked while the app is running.

   Automatically opening System Settings without explanation was rejected as disruptive, and silently reverting the toggle was rejected because it hides the user's intended state.

3. Add an asynchronous content-action capability alongside the synchronous one.

   Introduce a narrowly scoped asynchronous action protocol and an async executor entry point. `AITextPolishingAction` participates in registry metadata and suitability filtering, but its network execution is routed to `AITextPolishingService`. `ContentActionPanelViewModel` owns the task, publishes the existing executing/previewing/failed states on the main actor, cancels superseded work, and ignores late results. Existing deterministic actions retain their synchronous execution and tests.

   Converting every `ContentAction.execute` function to `async` was rejected because it creates broad churn with no benefit to local transforms. A completely separate AI window was rejected because it would duplicate preview, editing, copy, save, paste, keyboard, and accessibility behavior.

4. Use a small URLSession-based DeepSeek client and an explicit polishing request contract.

   The client sends an OpenAI-compatible chat-completion request to the centralized DeepSeek HTTPS base URL with the configured model, a fixed versioned system instruction, the user's current text, non-thinking mode when supported, and bounded output. The request/response DTOs expose only the returned text and token usage to the rest of the app. `URLSession` is injected for deterministic tests; no third-party SDK is required.

   The polishing instruction asks for clarity, fluency, grammar, and wording improvements while preserving meaning and source language, and asks for only the revised text. Model output remains untrusted: empty output, malformed JSON, oversized responses, non-success HTTP status, and cancellations map to localized domain errors.

5. Store the API key in Keychain and only non-secret settings in UserDefaults.

   A dedicated credential store uses a stable service/account identifier and supports save, read, replace, and delete. Settings exposes only whether a key exists and a transient entry field; it never loads the full key into persistent observable state. The model identifier and disclosure acknowledgment can use `UserDefaultsConfig` because they are not secrets.

   UserDefaults and SQLite were rejected for the API key because both are inappropriate plaintext secret stores. Environment variables were rejected for the shipped GUI configuration flow.

6. Persist provider-reported usage in a migration-backed table.

   Add the next SQLite migration with an `ai_token_usage` table containing an ID, provider, model identifier, prompt/input tokens, completion/output tokens, total tokens, optional cached-input tokens, and creation timestamp. Constraints reject negative counts; indexes support time/model aggregation. A repository inserts at most one record per completed response and queries cumulative totals. No source history ID, prompt, source text, response text, or API key is stored in this table.

   A durable table was chosen over UserDefaults counters because per-response atomic insertion prevents partial counter updates, supports grouping by model/time later, and can participate in clear-all-data. Local tokenization was rejected because DeepSeek states actual usage is determined by the model response and local estimates could differ from billing.

7. Separate a usable model result from optional usage metadata.

   If a successful response contains polished text but omits usage, the preview succeeds and clearly marks usage unavailable; no estimated record is written. Failed and cancelled requests do not create records unless an authoritative successful response was already accepted. This prevents accounting failures from discarding useful text while keeping statistics honest.

8. Make remote processing consent explicit and scope it to the action.

   Before the first network request, show a disclosure that the selected text goes to DeepSeek and may incur provider charges. Declining cancels the action without weakening local functionality. A persisted acknowledgment avoids repetitive prompts, while the AI settings and privacy documentation keep the boundary visible. Clipboard monitoring never calls the AI service.

## Risks / Trade-offs

- [Risk] A user enables Automatic Paste but does not grant Accessibility access. → Mitigation: show a persistent pending/permission-required status, retain clipboard-only fallback, and recheck live trust on every attempt.
- [Risk] A new paste path bypasses the setting. → Mitigation: route all Command-V dispatch through the shared policy/service and add regression tests covering history items, keyboard activation, and action outputs.
- [Risk] Model identifiers or request behavior change remotely. → Mitigation: centralize the default and API contract, allow a non-empty custom DeepSeek model ID, surface provider errors, and avoid silently changing the user's saved model.
- [Risk] Remote text may contain sensitive information. → Mitigation: require an explicit action and first-use disclosure, never invoke AI during capture, never log bodies, and keep the original local workflow available.
- [Risk] Token statistics diverge from charges because pricing, caching, or provider semantics change. → Mitigation: report tokens rather than currency, label them provider-reported, store optional cache fields, and do not estimate missing usage.
- [Risk] Keychain access can fail because of OS or signing state. → Mitigation: expose typed credential errors, leave existing credentials untouched on failed replacement, and never fall back to plaintext storage.
- [Risk] Network latency makes the action panel appear stuck. → Mitigation: show progress, enforce a timeout, support cancellation, and discard stale task results.

## Migration Plan

1. Add failing tests for the default-off preference, launch behavior, permission transitions, paste fallback, Keychain adapter, DeepSeek decoding/errors, cancellation, usage aggregation, and clear-all-data behavior.
2. Add the non-secret settings keys with defaults: Automatic Paste `false`, model `deepseek-v4-flash`, and remote-processing acknowledgment `false`. Existing users therefore stop receiving launch reminders and remain clipboard-only until opting in.
3. Add the token-usage database migration and repository, verify migration from both a new database and the current version-3 schema, and update database documentation.
4. Introduce automatic-paste policy wiring and remove the launch reminder before adding the setting UI.
5. Add Keychain credential storage, DeepSeek client, polishing service/action, async view-model integration, settings, localization, privacy disclosure, and token display.
6. Regenerate the Xcode project, run focused tests, full tests, file-reference validation, privacy log scanning, and manual QA against an input-capable application.
7. Update architecture, configuration, privacy policy, user guide, changelog, and development log before marking implementation complete.

Rollback can remove the UI/action and ignore the new UserDefaults keys. The additive token table can remain harmlessly on disk for forward compatibility; a rollback build must not delete it implicitly. The API key remains in Keychain until the user removes it or a later explicitly authorized migration handles credential cleanup.
