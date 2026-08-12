## 1. Requirements And Test Baseline

- [x] 1.1 Validate the change proposal, delta specs, design, and task graph with strict OpenSpec validation.
- [x] 1.2 Add failing tests for local credential validation, atomic owner-only persistence, relaunch reads, deletion, symlink rejection, and no-Keychain default wiring.
- [x] 1.3 Add failing tests for translation target persistence, prompt construction, response/error/cancellation handling, disclosure gating, result lifecycle, and exact-once Token attribution.
- [x] 1.4 Add or update tests proving permission-free restore remains clipboard-only and synthetic cross-app paste remains Accessibility-gated.

## 2. Local AI Credential Store

- [x] 2.1 Implement the Application Support credential path and a bounded, regular-file-only, owner-permission local credential store behind `AICredentialStoring`.
- [x] 2.2 Replace every default and app-composition Keychain credential injection with the same local credential store without reading or deleting legacy Keychain data.
- [x] 2.3 Update settings state, status messages, confirmation copy, and privacy disclosure to describe local non-Keychain storage accurately.

## 3. AI Translation

- [x] 3.1 Add the closed translation-target model, default setting, persistence, settings picker, and three-language localization.
- [x] 3.2 Generalize the DeepSeek request implementation and add a bounded translation request that preserves formatting and returns only translated text.
- [x] 3.3 Implement and register the async AI Translation action for textual and OCR-derived inputs.
- [x] 3.4 Generalize first-use remote-processing consent so all registered remote AI actions are gated consistently.
- [x] 3.5 Reuse editable output, copy, paste, derived-record, cancellation, localized failure, and Token usage flows for translation.

## 4. Automatic Paste Boundary

- [x] 4.1 Preserve the current pasteboard-first architecture and Accessibility gate for universal synthetic paste.
- [x] 4.2 Update settings/help copy to explain that clipboard restore is permission-free while cross-application automatic paste requires Accessibility authorization.
- [x] 4.3 Record the rejected Apple Events/private API/application-specific alternatives and their limitations in the decision log.

## 5. Documentation, QA, And Review

- [x] 5.1 Update README, user guide, privacy policy, changelog, and the pending-decision record for credential storage, AI Translation, and paste permission boundaries.
- [x] 5.2 Regenerate the Xcode project and verify all source/resource references.
- [x] 5.3 Run focused tests, the complete unit suite, Debug/Release builds, privacy scans, and relevant release-readiness checks.
- [ ] 5.4 Perform manual QA for relaunch credential access, translation targets/results, remote disclosure, Token totals, clipboard-only fallback, and authorized automatic paste.
- [x] 5.5 Obtain independent subagent review, resolve all blocking findings, rerun affected validation, and record the checklist state accurately.
