## ADDED Requirements

### Requirement: Explicit Remote AI Processing Boundary
The system SHALL keep clipboard capture and history local by default and SHALL disclose that explicitly selected text is sent to DeepSeek only when the user invokes AI Polishing.

#### Scenario: First AI polishing attempt
- **WHEN** the user invokes AI Polishing before acknowledging its remote-processing disclosure
- **THEN** the system explains what text is sent, that DeepSeek processes it remotely, and that provider terms and charges may apply before allowing the request.

#### Scenario: Decline remote processing
- **WHEN** the user declines the remote-processing disclosure
- **THEN** no request is sent and all local clipboard functionality remains available.

### Requirement: AI Credential And Logging Safety
The system MUST store AI credentials in macOS Keychain rather than ordinary preferences or SQLite, and MUST NOT log API keys, submitted text, prompts, or model responses.

#### Scenario: Persist AI credential
- **WHEN** the user saves a DeepSeek API key
- **THEN** the secret is stored in Keychain and only non-secret credential status is exposed to settings state.

#### Scenario: Diagnose AI request failure
- **WHEN** a polishing request fails
- **THEN** diagnostic output is limited to non-sensitive metadata such as error category, HTTP status, model identifier, latency, and token counts when safely available.
