## ADDED Requirements

### Requirement: Release Build Configuration
The system SHALL support sandboxed, signed Release builds suitable for distribution.

#### Scenario: Build release
- **WHEN** a Release build is produced
- **THEN** it is signed, sandbox-configured, and launches successfully.

### Requirement: Platform Compatibility Testing
The system SHALL be tested on Intel Mac, Apple Silicon Mac, and supported macOS versions where available.

#### Scenario: Run compatibility test
- **WHEN** the app is tested on a supported platform
- **THEN** launch, menu bar, capture, restore, and quit behavior work.

### Requirement: Common App Copy Testing
The system SHALL be validated against common copy sources.

#### Scenario: Copy from common app
- **WHEN** the user copies from Chrome, Safari, VS Code, WeChat, DingTalk, or similar common apps
- **THEN** expected text or image history behavior works.

### Requirement: Large Content Testing
The system SHALL handle large text and large image copy scenarios without unacceptable slowdown or crashes.

#### Scenario: Copy large content
- **WHEN** the user copies large text or a large image
- **THEN** the app handles the content according to configured limits and remains stable.

### Requirement: Release Documentation And Assets
The system SHALL include user help, privacy policy, and App Store screenshot assets.

#### Scenario: Prepare release materials
- **WHEN** release preparation is complete
- **THEN** help documentation, privacy policy, and screenshots are available.
