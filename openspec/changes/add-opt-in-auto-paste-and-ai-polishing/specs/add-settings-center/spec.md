## ADDED Requirements

### Requirement: Automatic Paste Setting
The system SHALL provide a persisted Automatic Paste toggle that is off by default and displays the current Accessibility readiness when enabled.

#### Scenario: Persist automatic paste choice
- **WHEN** the user changes the Automatic Paste toggle and restarts the app
- **THEN** the saved choice remains in effect without changing the default for users who never enabled it.

### Requirement: AI Polishing Settings
The system SHALL provide settings for the DeepSeek model identifier, secure API-key entry/replacement/removal, and local token-usage totals.

#### Scenario: Save AI settings
- **WHEN** the user saves a non-empty model identifier and API key
- **THEN** the model preference is persisted and the UI indicates that a credential is stored without displaying the full key.

#### Scenario: Remove API key
- **WHEN** the user confirms credential removal
- **THEN** the stored API key is deleted and subsequent polishing attempts require configuration.

#### Scenario: View token usage
- **WHEN** the user opens the AI settings section
- **THEN** the latest locally aggregated provider-reported token totals are displayed.
