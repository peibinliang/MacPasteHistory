## Purpose

为历史、动作输出和未来复用入口提供一致的 clipboard restore、自动粘贴、权限 fallback、统计和用户反馈语义。

## ADDED Requirements

### Requirement: Clipboard Restore Precedes Optional Paste
The system SHALL first write the requested content to the clipboard and SHALL only attempt a synthetic paste after a successful clipboard write.

#### Scenario: Restore text with automatic paste disabled
- **WHEN** the user activates text while Automatic Paste is disabled
- **THEN** the text is restored to the clipboard, no synthetic paste is sent, and manual-paste feedback is available

#### Scenario: Clipboard write fails
- **WHEN** requested content cannot be written to the clipboard
- **THEN** no synthetic paste is attempted and the user receives an actionable failure

### Requirement: Automatic Paste Uses Safe Fallback
The system SHALL dispatch a synthetic paste only when the user enabled Automatic Paste, Accessibility permission is available, and a valid target application can be activated; otherwise restored content SHALL remain on the clipboard.

#### Scenario: Accessibility permission is unavailable
- **WHEN** Automatic Paste is enabled but Accessibility permission is missing or revoked
- **THEN** the content remains restored, no paste command is sent, and the user receives permission guidance plus a manual-paste fallback

#### Scenario: Target application cannot be activated
- **WHEN** the previous target application is no longer available
- **THEN** no paste command is sent and the restored clipboard content remains available for manual use

### Requirement: Usage Accounting Reflects Actual Outcome
The system SHALL record paste usage only after an actual paste dispatch and SHALL record clipboard-only outcomes as restore or copy usage instead.

#### Scenario: Synthetic paste succeeds
- **WHEN** the coordinator successfully dispatches the paste command
- **THEN** paste usage is incremented exactly once

#### Scenario: Automatic paste falls back
- **WHEN** content is restored but a paste command is not dispatched
- **THEN** paste usage is not incremented and the clipboard restore is still reported as successful

### Requirement: All Reuse Entrypoints Share Coordination Semantics
The system SHALL apply the same permission, fallback, accounting, cancellation, and feedback rules to history items and content-action outputs.

#### Scenario: Paste an action output
- **WHEN** the user chooses Paste for a textual content-action result
- **THEN** the same coordination rules used by history restore determine clipboard and automatic-paste behavior
