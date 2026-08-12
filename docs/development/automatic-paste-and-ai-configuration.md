# Automatic Paste And AI Configuration

| Key / storage | Type | Default | Editable | Runtime behavior | Restart |
| --- | --- | --- | --- | --- | --- |
| `config.automaticPasteEnabled` | UserDefaults Boolean | `false` | General settings toggle | Re-evaluated with live Accessibility trust for every paste attempt | No |
| `config.aiModelIdentifier` | UserDefaults String | `deepseek-v4-flash` | AI settings text field/reset | Read for every AI request; blank values fall back to default | No |
| `config.aiTranslationTarget` | UserDefaults String | `zh-Hans` | AI settings picker | Read for every AI translation request; invalid values fall back to Simplified Chinese | No |
| `config.hasAcknowledgedAIRemoteProcessing` | UserDefaults Boolean | `false` | Set after first-use acceptance | Prevents repeat disclosure; decline does not set it | No |
| `Application Support/MacPasteHistory/ai-credential` | Owner-only plaintext file | none | Save, replace, confirmed remove | Read only for an explicit AI request; never written to UserDefaults, SQLite, logs, or history | No |

Automatic Paste states are `clipboardOnly`, `permissionRequired`, and `ready`. `PasteCoordinator` evaluates the live state for every history or action-output attempt. Only `ready` may close the panel for dispatch, activate the captured target and send synthetic `Command-V`; all states write the clipboard first. Disabled settings, missing permission, missing target, dispatch failure and cancellation use typed outcomes, preserve a manual-paste fallback whenever the clipboard write succeeded, and record usage exactly once.

AI polishing and translation requests target the centralized DeepSeek HTTPS chat-completions endpoint with a bounded timeout/output and non-thinking mode. The selected text is the only user content sent. Translation uses a closed target-language enum so user text is always sent as the user message, not interpolated into the system instruction. Diagnostics must not include request bodies, source text, response text, prompts, or credentials. Provider-reported token fields are inserted exactly once by request ID into `ai_token_usage`; missing usage is never estimated.

The API key no longer uses the default Keychain runtime path. `LocalFileAICredentialStore` writes the trimmed key to a same-directory temporary file, sets `0600` permissions, then replaces the managed credential file. Reads reject missing, oversized, blank, non-UTF-8, symlink, and non-regular credential files. This avoids Keychain prompts after relaunch but does not provide Keychain-equivalent at-rest protection; the signed-in user or software with equivalent file access can read the plaintext file. Existing historical Keychain items are not read, migrated, or deleted automatically.
