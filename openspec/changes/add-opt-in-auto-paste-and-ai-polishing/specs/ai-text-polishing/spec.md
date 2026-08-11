## Purpose

Let users explicitly send selected text to DeepSeek for concise polishing, review the result, and understand the provider-reported token consumption.

## ADDED Requirements

### Requirement: User-Initiated Text Polishing
The system SHALL offer AI Polishing only for textual content and SHALL send text to the remote model only after the user explicitly invokes the action.

#### Scenario: Invoke polishing for text
- **WHEN** the user chooses AI Polishing for a text history item or textual derived output
- **THEN** the system sends that current text to the configured DeepSeek model and shows an in-progress state.

#### Scenario: Browse history without invoking polishing
- **WHEN** the user captures, browses, searches, restores, or copies clipboard history without invoking AI Polishing
- **THEN** no clipboard text is sent to DeepSeek.

#### Scenario: Image-only content
- **WHEN** the selected item has no textual content
- **THEN** AI Polishing is not offered as an applicable action.

### Requirement: Configurable DeepSeek Model And Credential
The system SHALL default to the `deepseek-v4-flash` API model identifier and SHALL allow the user to save another non-empty DeepSeek-supported model identifier and a DeepSeek API key.

#### Scenario: Use the default model
- **WHEN** the user has not saved a custom model identifier
- **THEN** a polishing request uses `deepseek-v4-flash`.

#### Scenario: Use a custom model
- **WHEN** the user saves a valid non-empty model identifier
- **THEN** subsequent polishing requests use that identifier.

#### Scenario: Missing credential
- **WHEN** the user invokes AI Polishing without a stored API key
- **THEN** no request is sent and the system directs the user to configure the credential.

### Requirement: Polishing Preserves User Intent
The system SHALL instruct the model to improve clarity, fluency, grammar, and wording while preserving the source meaning and language, and SHALL return only the polished text for preview.

#### Scenario: Receive a polished result
- **WHEN** DeepSeek returns a non-empty successful result
- **THEN** the system presents the polished text as editable output without automatically overwriting the original history item.

#### Scenario: Use a polished result
- **WHEN** the polished result is available
- **THEN** the user can edit it and use the existing copy, save-as-derived-item, or paste workflows.

### Requirement: Safe Request Lifecycle And Failure Feedback
The system SHALL provide cancellable asynchronous execution, bound request duration and output size, and distinguish actionable remote failures without exposing source text or credentials.

#### Scenario: Authentication failure
- **WHEN** DeepSeek rejects the API credential
- **THEN** the system shows a credential-specific error and does not log the key or submitted text.

#### Scenario: Rate limit or transient service failure
- **WHEN** the provider rate-limits the request or a network/service error occurs
- **THEN** the original text remains unchanged and available, and the system shows a retryable failure state.

#### Scenario: Cancel polishing
- **WHEN** the user closes the action panel or cancels while polishing is in progress
- **THEN** the request task is cancelled and no late response updates the closed or superseded session.

#### Scenario: Empty provider output
- **WHEN** a successful response contains no usable polished text
- **THEN** the system reports an invalid-result error and retains the original text.

### Requirement: Provider-Reported Token Accounting
The system SHALL use token counts returned by DeepSeek and persist non-negative input, output, total, and available cached-input counts with the model identifier and timestamp, without persisting prompt or response bodies in usage records.

#### Scenario: Successful response with usage
- **WHEN** a polishing response includes token usage
- **THEN** the request view shows its input, output, and total tokens and the local cumulative totals include the request exactly once.

#### Scenario: Response omits usage
- **WHEN** a usable response does not include provider-reported token usage
- **THEN** the polished result remains usable, the usage is marked unavailable, and the system does not estimate or invent token counts.

#### Scenario: Failed or cancelled request
- **WHEN** a request fails before producing a successful response or is cancelled
- **THEN** no token-usage record is added unless the provider returned authoritative usage for that response.

#### Scenario: View cumulative usage
- **WHEN** the user opens AI settings
- **THEN** the system shows locally aggregated input, output, and total tokens, grouped at least by configured model or across all models.

### Requirement: AI Usage Data Cleanup
The system SHALL treat local token-usage records as user-controlled app data and SHALL remove them as part of the confirmed clear-all-data workflow.

#### Scenario: Clear all local data
- **WHEN** the user confirms clearing all app data
- **THEN** persisted AI token-usage records are deleted along with clipboard history while the Keychain credential is handled according to the credential-removal control.
