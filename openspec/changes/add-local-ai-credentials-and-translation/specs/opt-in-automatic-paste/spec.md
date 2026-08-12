## MODIFIED Requirements

### Requirement: Paste Behavior Respects The Setting
The system SHALL always restore selected content to the general pasteboard, SHALL allow that restore without Accessibility authorization, and SHALL dispatch a cross-application synthetic paste command only when Automatic Paste is enabled and Accessibility access is currently available.

#### Scenario: Permission-free restore
- **WHEN** the user activates a history item without Accessibility access
- **THEN** the content is restored to the pasteboard, no synthetic keyboard event is sent, and the app communicates that the user can press `Command-V` manually.

#### Scenario: Paste an action output while automatic paste is enabled
- **WHEN** the user chooses Paste for an action output while Automatic Paste is enabled and Accessibility access is available
- **THEN** the output is written to the pasteboard and the app sends the paste command to the previously active application.

#### Scenario: Permission is missing or revoked
- **WHEN** an automatic paste is attempted while the setting is enabled but Accessibility access is unavailable
- **THEN** the content remains restored to the pasteboard, no paste command is sent, and the app shows authorization guidance plus a manual-paste fallback.

#### Scenario: No alternative universal permission-free injection
- **WHEN** Accessibility access is unavailable
- **THEN** the app does not use private APIs, per-target Apple Events, or application-specific automation as if they were an equivalent universal automatic-paste path.
