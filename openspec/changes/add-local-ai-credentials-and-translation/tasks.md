## 1. Requirements And Test Baseline

- [ ] 1.1 Validate the change proposal, delta specs, design, and task graph with strict OpenSpec validation.
- [ ] 1.2 Add failing tests for local credential validation, atomic owner-only persistence, relaunch reads, deletion, symlink rejection, and no-Keychain default wiring.
- [ ] 1.3 Add failing tests for translation target persistence, prompt construction, response/error/cancellation handling, disclosure gating, result lifecycle, and exact-once Token attribution.
- [ ] 1.4 Add or update tests proving permission-free restore remains clipboard-only and synthetic cross-app paste remains Accessibility-gated.

## 2. Local AI Credential Store

- [ ] 2.1 Implement the Application Support credential path and a bounded, regular-file-only, owner-permission local credential store behind `AICredentialStoring`.
- [ ] 2.2 Replace every default and app-composition Keychain credential injection with the same local credential store without reading or deleting legacy Keychain data.
- [ ] 2.3 Update settings state, status messages, confirmation copy, and privacy disclosure to describe local non-Keychain storage accurately.

## 3. AI Translation

- [ ] 3.1 Add the closed translation-target model, default setting, persistence, settings picker, and three-language localization.
- [ ] 3.2 Generalize the DeepSeek request implementation and add a bounded translation request that preserves formatting and returns only translated text.
- [ ] 3.3 Implement and register the async AI Translation action for textual and OCR-derived inputs.
- [ ] 3.4 Generalize first-use remote-processing consent so all registered remote AI actions are gated consistently.
- [ ] 3.5 Reuse editable output, copy, paste, derived-record, cancellation, localized failure, and Token usage flows for translation.

## 4. Automatic Paste Boundary

- [ ] 4.1 Preserve the current pasteboard-first architecture and Accessibility gate for universal synthetic paste.
- [ ] 4.2 Update settings/help copy to explain that clipboard restore is permission-free while cross-application automatic paste requires Accessibility authorization.
- [ ] 4.3 Record the rejected Apple Events/private API/application-specific alternatives and their limitations in the decision log.

## 5. Documentation, QA, And Review

- [ ] 5.1 Update README, user guide, privacy policy, changelog, and the pending-decision record for credential storage, AI Translation, and paste permission boundaries.
- [ ] 5.2 Regenerate the Xcode project and verify all source/resource references.
- [ ] 5.3 Run focused tests, the complete unit suite, Debug/Release builds, privacy scans, and relevant release-readiness checks.
- [ ] 5.4 Perform manual QA for relaunch credential access, translation targets/results, remote disclosure, Token totals, clipboard-only fallback, and authorized automatic paste.
- [ ] 5.5 Obtain independent subagent review, resolve all blocking findings, rerun affected validation, and mark the OpenSpec checklist complete.
