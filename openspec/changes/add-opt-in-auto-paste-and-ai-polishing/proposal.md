## Why

Automatic paste currently asks for Accessibility access at launch even though clipboard capture and restore do not require that permission. Users need a permission-minimizing mode, and they also need an optional, explicit way to polish text with AI without leaving the clipboard workflow or obscuring the privacy and token-cost implications.

## What Changes

- Add an **Automatic Paste** setting that is disabled by default. Clipboard items and action outputs still restore to the clipboard when it is off, but the app does not synthesize Command-V or request Accessibility access.
- Request or guide the user to grant Accessibility access only when they enable Automatic Paste; if authorization is declined or later revoked, keep the content copied and provide a manual-paste fallback.
- Add an AI text-polishing action with editable output, copy, save-as-derived-item, and optional paste behavior integrated into the existing content-action workflow.
- Use the official `deepseek-v4-flash` API model identifier by default while allowing the user to enter another DeepSeek-supported model identifier.
- Add AI configuration for the model, secure API-key storage, and clear privacy disclosure before text is sent to DeepSeek.
- Record provider-reported input, output, cached-input when available, and total token counts locally for successful requests; expose per-request and cumulative usage without storing prompt or response bodies in usage records or logs.
- Update privacy and user documentation to distinguish local clipboard history from user-initiated remote AI processing.

## Capabilities

### New Capabilities

- `opt-in-automatic-paste`: Default-off automatic paste, deferred Accessibility authorization, manual-paste fallback, and behavior when permission is declined or revoked.
- `ai-text-polishing`: User-initiated remote text polishing, configurable model access, preview and output actions, safe failure handling, and local token-usage accounting.

### Modified Capabilities

- `add-settings-center`: Persist and present Automatic Paste and AI provider/model settings, secure credential status, and token-usage summaries.
- `add-privacy-and-security-controls`: Clarify that clipboard history remains local by default and require disclosure and explicit user action before selected text is sent to a configured AI provider.

## Impact

- Affected UI: `SettingsView`, `SettingsViewModel`, `MainPanelView`, and the content-action command palette/preview.
- Affected app behavior: startup Accessibility reminders are removed; paste commands are gated by the persisted Automatic Paste setting.
- New services and models: DeepSeek client, polishing agent, Keychain-backed credential store, model configuration, request state, and token-usage repository/aggregation.
- Data and configuration: new `UserDefaultsConfig` keys for non-secret settings; API keys must use macOS Keychain; token usage requires a local persisted schema and migration or another documented durable local store.
- Network boundary: selected text is sent only after the user invokes AI polishing, over HTTPS, to the DeepSeek API. No clipboard payload, AI prompt, response, or API key may be logged.
- Tests and docs: focused service/view-model/settings tests, mock-network contract tests, permission-state tests, migration tests if applicable, localized strings, privacy policy, user guide, architecture/configuration documentation, and development log.
