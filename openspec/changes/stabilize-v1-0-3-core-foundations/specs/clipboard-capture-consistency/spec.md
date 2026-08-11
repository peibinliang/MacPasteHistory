## Purpose

保证一次剪贴板变化在隐私判断、内容读取、历史持久化和捕获统计的完整生命周期中使用同一份不可变来源应用快照。

## ADDED Requirements

### Requirement: Capture Source Once Per Pasteboard Change
The system SHALL resolve source application name, bundle identifier, and capture time exactly once for each pasteboard change that enters the capture pipeline.

#### Scenario: Foreground app changes during text capture
- **WHEN** a text copy begins in a blocked app and the foreground app changes before persistence finishes
- **THEN** the system uses the original blocked-app source and does not save the content

#### Scenario: Foreground app changes during image capture
- **WHEN** an image copy begins in one app and the foreground app changes before persistence finishes
- **THEN** the saved image metadata retains the source captured at the start of that pasteboard change

### Requirement: Source Metadata Remains Consistent
The system SHALL use the same captured source identity for privacy validation, the primary history record, and every capture event created by one capture attempt.

#### Scenario: Persist accepted content
- **WHEN** accepted clipboard content is saved with a known source application
- **THEN** the history record and capture event contain the same source application name and bundle identifier

#### Scenario: Source application is unavailable
- **WHEN** macOS does not provide a foreground application for a pasteboard change
- **THEN** the capture continues with a single unknown-source snapshot without inventing application metadata
