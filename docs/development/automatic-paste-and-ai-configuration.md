# Automatic Paste And AI Configuration

| Key / storage | Type | Default | Editable | Runtime behavior | Restart |
| --- | --- | --- | --- | --- | --- |
| `config.automaticPasteEnabled` | UserDefaults Boolean | `false` | General settings toggle | Re-evaluated with live Accessibility trust for every paste attempt | No |
| `config.aiModelIdentifier` | UserDefaults String | `deepseek-v4-flash` | AI settings text field/reset | Read for every AI request; blank values fall back to default | No |
| `config.hasAcknowledgedAIRemoteProcessing` | UserDefaults Boolean | `false` | Set after first-use acceptance | Prevents repeat disclosure; decline does not set it | No |
| `com.peibin.MacPasteHistory.ai` / `deepseek-api-key` | macOS Keychain secret | none | Save, replace, confirmed remove | Read only for an explicit AI request; never mirrored to plaintext settings | No |

Automatic Paste states are `clipboardOnly`, `permissionRequired`, and `ready`. `PasteCoordinator` evaluates the live state for every history or action-output attempt. Only `ready` may close the panel for dispatch, activate the captured target and send synthetic `Command-V`; all states write the clipboard first. Disabled settings, missing permission, missing target, dispatch failure and cancellation use typed outcomes, preserve a manual-paste fallback whenever the clipboard write succeeded, and record usage exactly once.

AI requests target the centralized DeepSeek HTTPS chat-completions endpoint with a bounded timeout/output and non-thinking mode. The selected text is the only user content sent. Diagnostics must not include request bodies, source text, response text, prompts, or credentials. Provider-reported token fields are inserted exactly once by request ID into `ai_token_usage`; missing usage is never estimated.
