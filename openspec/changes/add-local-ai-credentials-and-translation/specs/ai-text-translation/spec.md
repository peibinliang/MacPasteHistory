## Purpose

Let users explicitly translate selected local text through DeepSeek into a configured target language while retaining control over disclosure, cancellation, output, and usage data.

## ADDED Requirements

### Requirement: User-Initiated AI Translation
The system SHALL offer AI Translation only for textual content and SHALL send the current text to DeepSeek only after the user explicitly invokes the action and has accepted the remote-processing disclosure.

#### Scenario: Translate textual content
- **WHEN** the user invokes AI Translation for text or OCR text
- **THEN** the system sends the current action text to the configured DeepSeek model and presents an in-progress state.

#### Scenario: Image without recognized text
- **WHEN** an image record has no saved OCR text
- **THEN** AI Translation is not offered for that record.

### Requirement: Configurable Translation Target
The system SHALL let the user select a supported target language, persist that selection locally, and instruct DeepSeek to preserve meaning, structure, formatting, code, URLs, and proper nouns while returning only the translated text.

#### Scenario: Use configured target language
- **WHEN** the user invokes AI Translation after selecting a target language
- **THEN** the request instructs the provider to translate into that language and the original record remains unchanged.

#### Scenario: No saved target
- **WHEN** no translation target has been saved
- **THEN** the system uses Simplified Chinese as the default target language.

### Requirement: Translation Result Lifecycle
The system SHALL make successful translation output editable and available to the existing copy, paste, action-chain, and save-as-derived-record workflows.

#### Scenario: Successful translation
- **WHEN** DeepSeek returns a non-empty translation
- **THEN** the system displays only the translated text as editable output and does not overwrite the source record.

#### Scenario: Cancel or fail translation
- **WHEN** translation is cancelled, times out, fails authentication, is rate-limited, or returns no usable output
- **THEN** no late output replaces the active session, the original text remains available, and the system presents an actionable localized state.

### Requirement: Translation Token Accounting
The system SHALL display and persist provider-reported Token usage for successful translation requests using the same exact-once, model-attributed, body-free accounting rules as AI Polishing.

#### Scenario: Translation response includes usage
- **WHEN** a successful translation includes provider-reported usage
- **THEN** the result shows input, output, and total Tokens and cumulative model totals include the request exactly once.

#### Scenario: Translation response omits usage
- **WHEN** a usable translation omits usage
- **THEN** the translation remains usable and the system marks usage unavailable without estimating it.
