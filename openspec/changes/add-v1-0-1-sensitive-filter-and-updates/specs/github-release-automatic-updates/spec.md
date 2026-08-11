## ADDED Requirements

### Requirement: Secure application updates
The system SHALL check a fixed HTTPS appcast automatically and on demand, and SHALL install only updates accepted by Sparkle signature and application code-signing validation.

#### Scenario: User checks for an update
- **WHEN** the user requests a manual update check from About & Updates
- **THEN** the system SHALL request a foreground Sparkle check using the fixed HTTPS appcast and SHALL prevent concurrent manual checks

#### Scenario: A valid newer update is available
- **WHEN** the fixed appcast identifies a newer build with a valid HTTPS enclosure, Sparkle signature, and application code signature
- **THEN** the system SHALL present Sparkle's standard update flow and SHALL install and restart only after the user accepts it

#### Scenario: The app is already current
- **WHEN** a manual update check finds no newer build
- **THEN** the system SHALL provide understandable feedback that the installed version is current

#### Scenario: Update validation fails
- **WHEN** the appcast, download, Sparkle signature, or application code-signing validation fails
- **THEN** the system SHALL reject installation, preserve the current application and local data, and continue clipboard monitoring

#### Scenario: User cancels an update
- **WHEN** the user cancels an update download, authorization, or installation
- **THEN** the system SHALL preserve the current application and local data

### Requirement: Update networking preserves the app sandbox boundary
The system SHALL keep the main application sandboxed with `com.apple.security.network.client` disabled and SHALL use Sparkle's sandbox-supported XPC services for update retrieval and installation.

#### Scenario: Release build includes the updater services
- **WHEN** a Release build is assembled for distribution
- **THEN** the application bundle SHALL include the required Sparkle framework and XPC services with the entitlement configuration required for secure update retrieval and installation

### Requirement: Release metadata is consistent and verifiable
The system SHALL publish V1.0.1 as marketing version `1.0.1` and build `2` through a valid fixed appcast that references an HTTPS GitHub Release ZIP signed with Sparkle EdDSA.

#### Scenario: Release appcast is checked
- **WHEN** the V1.0.1 appcast and referenced ZIP are verified before release
- **THEN** their version and build metadata SHALL match and the enclosure signature SHALL validate the ZIP
