## Purpose

在完全本地处理的前提下，以结构化检测结果阻止高可信敏感文本持久化，同时避免将常见开发者标识符和普通长字符串误判为秘密。

## ADDED Requirements

### Requirement: Structured Sensitive Detection Result
The system SHALL represent a sensitive-content match with a category, confidence, and non-secret reason while preserving a non-sensitive result for unmatched input.

#### Scenario: Detect a credential assignment
- **WHEN** copied text contains a password, API key, access token, or authorization credential in a supported context
- **THEN** the detector returns a credential category with confidence and a reason that does not include the secret value

#### Scenario: No detector matches
- **WHEN** copied text does not meet any enabled sensitive rule
- **THEN** the detector returns a non-sensitive result and recording may continue

### Requirement: Default Filtering Uses High-Confidence Decisions
When sensitive filtering is enabled, the system MUST prevent persistence for high-confidence sensitive results and MUST NOT prevent persistence solely because of a medium-confidence, low-confidence, or unmatched result.

#### Scenario: High-confidence credential match
- **WHEN** a supported credential detector produces a high-confidence result while sensitive filtering is enabled
- **THEN** the clipboard text is not persisted

#### Scenario: Medium-or-lower confidence candidate
- **WHEN** detection produces only medium-confidence or low-confidence candidates
- **THEN** the content remains recordable unless another detector produces a high-confidence result

#### Scenario: Sensitive filtering is disabled
- **WHEN** the user has explicitly disabled sensitive filtering and acknowledged the risk
- **THEN** a high-confidence local detection result does not independently prevent persistence

### Requirement: Validated Financial And Identity Detection
The system SHALL validate bank-card candidates with a checksum and identity candidates with format, date, and check-digit rules before treating them as high-confidence sensitive data.

#### Scenario: Valid bank-card candidate
- **WHEN** a supported card-number candidate passes normalization, length, and Luhn validation
- **THEN** the detector classifies it as sensitive bank-card data

#### Scenario: Invalid digit sequence
- **WHEN** a 16-to-19 digit sequence fails Luhn validation
- **THEN** the sequence is not classified as a bank card solely because of its length

#### Scenario: Invalid identity candidate
- **WHEN** an identity-number-shaped value contains an impossible date or invalid check digit
- **THEN** the value is not classified as a valid identity number

### Requirement: Developer Identifier False-Positive Protection
The system SHALL NOT classify a value as sensitive solely because it is a Git SHA, MD5 hash, UUID, trace identifier, or long random-looking string.

#### Scenario: Copy common developer identifiers
- **WHEN** the user copies a Git SHA, MD5 hash, UUID, trace identifier, or unlabelled long string
- **THEN** the content remains recordable unless another contextual detector identifies a supported secret pattern

### Requirement: Local-Only Detection And Safe Diagnostics
The system MUST perform sensitive detection locally and MUST NOT log or transmit the inspected text or matched secret.

#### Scenario: Evaluate sensitive clipboard text
- **WHEN** any sensitive detector evaluates copied text
- **THEN** no network request is made and diagnostics contain at most the category, confidence, and safe reason code
