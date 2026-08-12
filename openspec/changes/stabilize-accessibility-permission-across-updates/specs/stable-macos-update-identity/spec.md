## Purpose

Ensure public macOS updates preserve a stable, verifiable application identity so previously granted privacy permissions can remain valid across compatible releases.

## ADDED Requirements

### Requirement: Public releases use a stable distribution identity
The release system SHALL reject a public release candidate unless the app is signed with a Developer ID Application identity, has a non-empty Team ID, retains the production bundle identifier, and is accepted by macOS as notarized software.

#### Scenario: Ad-hoc candidate is rejected
- **WHEN** a release candidate has an ad-hoc signature or no Team ID
- **THEN** the public release gate fails and identifies the missing stable distribution identity

#### Scenario: Developer ID candidate is accepted
- **WHEN** a release candidate is Developer ID signed, notarized, and has the expected bundle identifier and Team ID
- **THEN** the distribution identity gate passes

### Requirement: Consecutive releases are identity compatible
The release system SHALL compare the installed previous public release with the candidate and reject the candidate when their bundle identifiers, Team IDs, or designated requirements cannot represent compatible versions of the same application.

#### Scenario: Version-specific CDHash identities are rejected
- **WHEN** either release relies on a designated requirement pinned only to its build-specific CDHash
- **THEN** the compatibility gate fails because permission continuity cannot be established

#### Scenario: Stable signed versions are compatible
- **WHEN** the previous release and candidate use the same production bundle identifier and compatible Developer ID designated requirements from the expected Team ID
- **THEN** the compatibility gate passes

### Requirement: Accessibility continuity is verified through a real update
Final release approval SHALL include a recorded update from the previous Developer ID release to the candidate in which Accessibility permission is granted before the update and remains trusted after the update.

#### Scenario: Permission survives the update
- **WHEN** the authorized previous release updates to the compatible candidate through the production update channel
- **THEN** the candidate remains an Accessibility-trusted client and Automatic Paste succeeds without another authorization action

#### Scenario: First migration from ad-hoc identity
- **WHEN** a user updates from an ad-hoc release to the first Developer ID release
- **THEN** release communication states that one final authorization may be required and does not claim seamless permission migration

### Requirement: Internal builds do not claim permission continuity
The release tooling SHALL allow ad-hoc builds only in an explicitly selected internal QA mode and SHALL report that such builds cannot validate Accessibility permission continuity.

#### Scenario: Internal ad-hoc QA
- **WHEN** an operator explicitly selects internal ad-hoc QA mode
- **THEN** local verification may continue with a warning and public release approval remains blocked
