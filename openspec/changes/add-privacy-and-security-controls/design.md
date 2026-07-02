## Context

The app records clipboard contents locally. Privacy controls need to run before persistence so sensitive or disallowed content does not enter storage.

## Goals / Non-Goals

**Goals:**
- Explain local recording on first launch.
- Filter sensitive text by default.
- Allow temporary pause.
- Let users configure blocked apps.
- Detect foreground app source and skip blocked apps.
- Provide privacy policy documentation.

**Non-Goals:**
- Local database encryption is deferred.
- Cloud sync and remote storage are not part of this app version.

## Decisions

- Evaluate pause state, recording toggles, blocked apps, and sensitive filters before saving a clipboard item.
- Start with deterministic keyword and pattern rules for sensitive text because they are explainable and local.
- Persist blocked apps in a `blocked_apps` table with app name, bundle id, and enabled state.
- Use foreground app detection to populate source metadata and enforce blacklist behavior.
- Keep all privacy processing local.

## Risks / Trade-offs

- Sensitive filtering can miss unknown formats -> make rules easy to extend and include common keywords from the requirements document.
- Sensitive filtering can false-positive useful snippets -> provide a setting to disable filtering while defaulting to privacy-preserving behavior.
- Foreground app detection may be unavailable in some contexts -> fail closed for known blocked apps when bundle id is available and log uncertainty.
