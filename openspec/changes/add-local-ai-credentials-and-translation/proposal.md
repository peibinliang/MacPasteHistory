## Why

The current AI credential path depends on Keychain access, which can interrupt repeated launches in ad-hoc builds, while the product has no dedicated translation action. The release also needs an explicit, evidence-backed boundary for whether universal automatic paste can work without macOS Accessibility authorization.

## What Changes

- **BREAKING** Replace the default Keychain-backed DeepSeek API-key store with an app-managed local credential file under Application Support, protected with owner-only file permissions and excluded from logs, history, exports, and update traffic.
- Do not silently copy the existing Keychain item into the new store; users with an existing key enter it once in the new version, and the previous Keychain item remains untouched unless explicitly removed by a separate migration decision.
- Add an explicit AI Translation content action for text and OCR text, with a user-selected target language, the existing first-use remote-processing disclosure, cancellable execution, editable results, derived-history support, paste support, and provider-reported Token accounting.
- Assess and document the macOS permission boundary for automatic paste. Preserve clipboard-only restore as the permission-free fallback and do not replace Accessibility with less reliable per-application Automation prompts or private APIs.
- Update localized UI, user/privacy documentation, and release QA coverage for the new storage disclosure and translation flow.

## Capabilities

### New Capabilities

- `ai-text-translation`: Explicit DeepSeek-backed translation with target-language selection, privacy disclosure, result handling, cancellation, and Token reporting.

### Modified Capabilities

- `ai-text-polishing`: Change the credential persistence contract from macOS Keychain to an owner-readable app-managed local file and accurately disclose the reduced at-rest protection.
- `opt-in-automatic-paste`: Clarify that permission-free operation restores content to the pasteboard, while universal cross-application keystroke injection remains gated by Accessibility authorization.

## Impact

- AI credential persistence, settings state and copy, DeepSeek request abstraction, content-action registration, action panel state, translations, privacy policy, user guide, and tests.
- Existing Keychain credentials are not automatically migrated or deleted.
- No new external provider or network endpoint is introduced; AI text continues to be sent only to the configured DeepSeek endpoint after explicit user action and disclosure.
- The local credential file is more convenient for ad-hoc builds but less secure than Keychain and must be documented as plaintext protected only by filesystem permissions and device security.
