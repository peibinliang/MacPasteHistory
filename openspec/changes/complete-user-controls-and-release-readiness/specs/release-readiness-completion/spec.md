## ADDED Requirements

### Requirement: Release signing status is explicit
The system SHALL distinguish internal QA ad-hoc packages from final distribution packages that require a valid signing identity and distribution path.

#### Scenario: Internal QA package
- **WHEN** an ad-hoc signed QA package is produced
- **THEN** release evidence MUST label it as internal QA only and MUST NOT mark final distribution signing as complete

#### Scenario: Final distribution package
- **WHEN** the project is marked release-ready for distribution
- **THEN** release evidence MUST show a valid signing identity, Team ID, sandbox entitlement, and notarization or App Store submission path as applicable

### Requirement: Manual QA evidence is complete before release
The system MUST require manual QA evidence for core workflows before final release readiness is marked complete.

#### Scenario: Manual QA record incomplete
- **WHEN** required manual QA rows are still Not run, TBD, or missing evidence
- **THEN** final release readiness MUST fail or remain incomplete

#### Scenario: Manual QA record complete
- **WHEN** required manual QA rows include tester, date, build, result, and evidence
- **THEN** the release readiness report MAY treat manual QA as complete

### Requirement: Compatibility coverage is recorded
The system MUST record compatibility coverage for supported architecture and macOS version targets.

#### Scenario: Architecture not covered
- **WHEN** Intel or Apple Silicon coverage is missing
- **THEN** the release checklist MUST keep that coverage open or record a documented waiver

#### Scenario: macOS version not covered
- **WHEN** a supported macOS major version has not been tested
- **THEN** the release checklist MUST keep that coverage open or record a documented waiver

### Requirement: Store and release assets match the implemented product
The system MUST keep user docs, privacy policy, screenshots, icon assets, and release notes aligned with implemented behavior.

#### Scenario: Asset verification
- **WHEN** release asset verification runs
- **THEN** it MUST confirm required assets exist, are readable, contain no real private clipboard content, and do not claim unimplemented database encryption
