## ADDED Requirements

### Requirement: Sensitive filtering remains safe by default
The system SHALL enable sensitive-content filtering when no user preference exists.

#### Scenario: User accepts the disable warning
- **WHEN** the user confirms disabling sensitive-content filtering
- **THEN** matching text SHALL be eligible for normal local persistence without truncation

#### Scenario: User cancels the disable warning
- **WHEN** the user cancels the confirmation to disable sensitive-content filtering
- **THEN** sensitive-content filtering SHALL remain enabled and matching text SHALL continue to be skipped

#### Scenario: User re-enables filtering
- **WHEN** the user enables sensitive-content filtering after it was disabled
- **THEN** matching text SHALL again be skipped without requiring a confirmation

### Requirement: Filtering state is persisted and applied at capture time
The system SHALL persist the user's filtering preference and SHALL read its current value for every text capture.

#### Scenario: User changes filtering while the monitor is running
- **WHEN** the user confirms a change to the filtering preference while clipboard monitoring is already running
- **THEN** the next eligible text capture SHALL use the new preference without requiring an application restart

### Requirement: Enabled filtering preserves the existing privacy gate
The system SHALL run the existing sensitive-content detector before local text persistence while filtering is enabled.

#### Scenario: Copied text matches a sensitive rule while filtering is enabled
- **WHEN** eligible copied text matches an existing password, token, identity, or bank-card rule and filtering is enabled
- **THEN** the system SHALL not persist the text and SHALL not log its copied payload

### Requirement: Disabling filtering does not alter non-sensitive text processing
The system SHALL retain existing allowed text cleanup, classification, deduplication, and local persistence behavior when filtering is disabled, except that it SHALL bypass the sensitive-content detector.

#### Scenario: User saves multiline technical text with filtering disabled
- **WHEN** filtering is disabled and eligible copied text contains internal newlines, quotes, URLs, Chinese text, or Emoji
- **THEN** the system SHALL persist the complete text without changing those internal characters
