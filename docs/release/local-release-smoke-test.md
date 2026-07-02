# Local Release Smoke Test

## Purpose

This smoke test verifies the Release build on the current Mac without using real clipboard data. It is intended to catch packaging, sandbox, launch, text capture, image capture, large-content, startup cleanup, and quit regressions before manual QA.

## Command

```bash
scripts/release-smoke-test.sh
```

The script performs these steps:

1. Regenerates `MacPasteHistory.xcodeproj` with XcodeGen.
2. Builds the `MacPasteHistory` scheme in Release mode for Apple Silicon.
3. Confirms the built app contains the App Sandbox entitlement.
4. Launches the Release app.
5. Writes a unique synthetic text marker to the clipboard and verifies it appears in `clipboard.db`.
6. Writes a synthetic large text sample and verifies the persisted character count.
7. Writes a synthetic 1x1 PNG to the clipboard and verifies image and thumbnail paths are persisted.
8. Writes a synthetic 1024x768 PNG and verifies persisted dimensions.
9. Quits the app.
10. Removes only the synthetic records and files created by the test.
11. Inserts an expired synthetic image record with files, relaunches the Release app, and verifies startup cleanup removes both the database row and files.

The text and image clipboard writes are retried while the script waits for database evidence. This avoids a launch race where an already-existing sandbox database appears before the clipboard monitor has finished initializing.

## Current Coverage

This test provides machine-verifiable evidence for local Release build health on the current Apple Silicon Mac. It does not replace:

- Developer ID or App Store signing certificate validation.
- Intel Mac hardware testing.
- macOS 14/15 compatibility testing.
- Manual menu bar visibility, window interaction, restore, screenshot, and common-app copy QA.
- Manual large-list scrolling and visual performance checks.
- Release validation for count-limit cleanup, storage-cap cleanup, and user-triggered clear-all behavior.
- Chat app testing that requires real test accounts.

## Expected Output

Successful runs end with:

```text
Release smoke test passed.
```

If the output includes `Signature=adhoc` and `TeamIdentifier=not set`, the app is only signed for local running. Install an Apple Developer signing identity before distribution.
