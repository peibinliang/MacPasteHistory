## Why

Clipboard tools can accidentally capture secrets, passwords, tokens, and content from apps where recording is inappropriate. This phase makes the product trustworthy by adding privacy notice, sensitive filtering, pause, blocked apps, and privacy documentation.

## What Changes

- Show a first-launch privacy notice explaining local recording.
- Add sensitive text recognition rules for passwords, tokens, codes, IDs, bank cards, and related keywords.
- Prevent sensitive content from being saved by default.
- Add a sensitive filtering toggle.
- Add pause recording behavior.
- Add blocked-app configuration.
- Detect the current foreground app.
- Skip saving content copied from blocked apps.
- Add automatic cleanup for expired history.
- Add privacy policy documentation.

## Capabilities

### New Capabilities
- `add-privacy-and-security-controls`: Privacy notice, sensitive content filtering, pause recording, blocked-app configuration, foreground app detection, blacklist enforcement, cleanup, and privacy documentation.

### Modified Capabilities

## Impact

- Affects clipboard capture gates, sensitive content service, blocked app storage, foreground app detection, settings UI, cleanup service, onboarding, and documentation.
