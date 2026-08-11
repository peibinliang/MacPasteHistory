## ADDED Requirements

### Requirement: Runtime version information
The system SHALL display `CFBundleShortVersionString` and `CFBundleVersion` from the running application bundle.

#### Scenario: User opens About & Updates
- **WHEN** the user opens the About & Updates settings category
- **THEN** the system SHALL display the running application's name, marketing version, and build number without hard-coding a release value

### Requirement: Version information is provided through a testable boundary
The system SHALL obtain application display information through an injectable version-information provider backed by the running Bundle in production.

#### Scenario: Version provider supplies test values
- **WHEN** a test injects a version-information provider with a marketing version and build number
- **THEN** the associated settings state SHALL present those supplied values
