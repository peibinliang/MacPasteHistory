## MODIFIED Requirements

### Requirement: Configurable DeepSeek Model And Credential
The system SHALL default to the `deepseek-v4-flash` API model identifier, SHALL allow the user to save another non-empty DeepSeek-supported model identifier, and SHALL persist the DeepSeek API key in an app-managed local credential file protected by owner-only filesystem permissions rather than macOS Keychain.

#### Scenario: Use the default model
- **WHEN** the user has not saved a custom model identifier
- **THEN** an AI request uses `deepseek-v4-flash`.

#### Scenario: Use a custom model
- **WHEN** the user saves a valid non-empty model identifier
- **THEN** subsequent AI requests use that identifier.

#### Scenario: Save credential locally
- **WHEN** the user saves a valid API key
- **THEN** the system trims it, writes it atomically to the app's Application Support directory with owner-only permissions, never writes it to logs or history, and discloses that it is not protected by Keychain.

#### Scenario: Relaunch with a local credential
- **WHEN** the app relaunches with a valid local credential file
- **THEN** AI actions can read the credential without accessing macOS Keychain or prompting for Keychain access.

#### Scenario: Missing or invalid local credential
- **WHEN** the user invokes an AI action without a valid locally stored API key
- **THEN** no request is sent and the system directs the user to configure the credential.

#### Scenario: Existing Keychain-only installation
- **WHEN** an upgraded installation has a previous Keychain key but no local credential file
- **THEN** the system treats the local credential as missing and neither reads, copies, nor deletes the Keychain item automatically.

### Requirement: AI Usage Data Cleanup
The system SHALL treat local Token-usage records as user-controlled app data and SHALL remove them as part of the confirmed clear-all-data workflow, while the separately managed local API-key file remains controlled through its dedicated remove action.

#### Scenario: Clear all local data
- **WHEN** the user confirms clearing all app data
- **THEN** persisted AI Token-usage records are deleted along with clipboard history while the API-key file is retained until the user explicitly removes it.
