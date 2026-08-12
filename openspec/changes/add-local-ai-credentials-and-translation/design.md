## Context

The app currently stores one DeepSeek key through Security.framework, exposes one remote AI action, and implements automatic paste by restoring the pasteboard before posting `Command-V` through `CGEvent`. See `proposal.md` and the delta specs for changed behavior.

The app remains ad-hoc signed for v1.0.5. Keychain behavior is therefore inconvenient for this distribution phase, but moving the key out of Keychain necessarily reduces at-rest protection. macOS does not expose a public, universal API that inserts pasteboard content into arbitrary third-party controls without either user input or an authorization such as Accessibility.

## Goals / Non-Goals

**Goals:**

- Remove all runtime Keychain reads and writes from the default AI path.
- Keep the local credential implementation replaceable through the existing storage protocol.
- Add one parameterized AI translation action with a persisted target-language setting.
- Reuse the proven request lifecycle, disclosure, result preview, cancellation, error mapping, and Token ledger.
- Make the automatic-paste permission boundary explicit in product copy and tests.

**Non-Goals:**

- Claiming encryption or Keychain-equivalent protection for the local credential file.
- Reading, migrating, or deleting an existing Keychain item automatically.
- Using AppleScript, private APIs, application-specific plugins, or Accessibility bypasses.
- Adding another AI provider or per-operation Token aggregation.

## Decisions

### Store the API key in a dedicated Application Support file

Use a single UTF-8 file beneath the app's existing Application Support directory. Writes use a sibling temporary file, owner-only POSIX permissions, then atomic replacement. Reads reject empty, non-regular, symlinked, oversized, or invalid UTF-8 content. This is more auditable than `UserDefaults`, avoids accidental preference export, and keeps credentials separate from SQLite history. The settings UI clearly calls it local plaintext protected by macOS file permissions.

Alternatives considered: Keychain retains stronger protection but does not meet the requested launch behavior; reversible obfuscation creates a misleading security claim; local encryption with a colocated key does not provide a meaningful trust boundary.

### Generalize the DeepSeek request around a text instruction

Keep a typed polishing method for compatibility while adding typed translation. Both share a private request builder/decoder and return the existing result and Token structures. Translation target values are a closed enum with stable persisted identifiers and prompt-only provider labels, preventing arbitrary prompt injection through the target-language setting.

### Use one configured translation target

Expose a target-language picker in AI settings and one `AI Translation` action. The default is Simplified Chinese. This avoids duplicating actions for every language and lets the action remain available in the same recommended-action pipeline.

### Treat both remote actions uniformly

Introduce a marker protocol/property for remote AI actions so the first-use disclosure cannot accidentally protect polishing but omit translation. Both actions use the same executor state, cancellation identity, output preview, and usage notification.

### Preserve Accessibility as the universal automatic-paste gate

Writing `NSPasteboard.general` needs no Accessibility permission, but posting keyboard events into another app does. Apple Events would exchange one TCC prompt for per-target Automation permissions and incomplete application support. The implementation therefore retains clipboard-only restore as the reliable permission-free behavior and documents the limitation rather than adding a fragile bypass.

## Risks / Trade-offs

- [Local API key is readable by the logged-in user or malware running as that user] → Use mode `0600`, prohibit symlinks and logging, disclose the limitation, and retain the abstraction for a future Keychain/secure-provider option.
- [Existing users believe their Keychain key migrated] → Show the local-store status as missing and require one explicit save; do not touch the old item.
- [Translation prompt alters code or formatting] → Explicitly instruct preservation and keep the output editable without overwriting source history.
- [A future AI action bypasses disclosure] → Gate by the shared remote-AI action marker rather than a single action ID.
- [Users interpret clipboard restore as automatic paste] → Keep distinct feedback for clipboard-only restore and dispatched paste.

## Migration Plan

1. Ship the local-file store as the only default injection for settings and AI services.
2. Existing Keychain data remains outside the new runtime path and untouched.
3. Users save the key once into the local store after updating.
4. Rollback to v1.0.4 leaves the prior Keychain item available if it existed; the older release ignores the new local file.
