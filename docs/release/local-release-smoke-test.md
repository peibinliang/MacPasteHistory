# Local Release Smoke Test

## Purpose

This smoke test verifies the Release build on the current Mac without using real clipboard data. It is intended to catch packaging, sandbox, install-copy launch, restart persistence, text capture, image capture, large-content, oversized-image skip, startup cleanup, and quit regressions before manual QA.

## Command

```bash
scripts/release-smoke-test.sh
```

The script performs these steps:

1. Regenerates `MacPasteHistory.xcodeproj` with XcodeGen.
2. Builds the `MacPasteHistory` scheme in Release mode for Apple Silicon.
3. Confirms the built app contains the App Sandbox entitlement.
4. Copies the built app to a temporary install directory and launches that Release app copy.
5. Writes a unique synthetic text marker to the clipboard and verifies it appears in `clipboard.db`.
6. Writes a synthetic large text sample and verifies the persisted character count.
7. Writes a synthetic 1x1 PNG to the clipboard and verifies image and thumbnail paths are persisted.
8. Writes a synthetic 1024x768 PNG and verifies persisted dimensions.
9. Temporarily lowers the single-image size limit, writes a synthetic oversized PNG, and verifies no database record, original file, or thumbnail file is created.
10. Quits and relaunches the app, then verifies captured history remains available after restart.
11. Removes only the synthetic records and files created by the capture test.
12. Inserts an expired synthetic image record with files, relaunches the Release app, and verifies startup cleanup removes both the database row and files.
13. Backs up the app database, image files, and sandbox preferences before controlled cleanup-limit checks.
14. Writes cleanup limits into the sandbox preferences and verifies Release startup trims text/image count limits while preserving favorites.
15. Verifies Release startup evicts older image files when the configured storage cap is exceeded.
16. Restores the backed-up app data and preferences before exiting.

The text and image clipboard writes are retried while the script waits for database evidence. This avoids a launch race where an already-existing sandbox database appears before the clipboard monitor has finished initializing.

## Current Coverage

This test provides machine-verifiable evidence for local Release build health on the current Apple Silicon Mac. It does not replace:

- Developer ID or App Store signing certificate validation.
- Intel Mac hardware testing.
- macOS 14/15 compatibility testing.
- Manual menu bar visibility, window interaction, restore, screenshot, and common-app copy QA.
- Manual large-list scrolling and visual performance checks.
- User-triggered clear-all behavior in the Settings UI.
- Chat app testing that requires real test accounts.

## Expected Output

Successful runs end with:

```text
Release smoke test passed.
```

If the output includes `Signature=adhoc` and `TeamIdentifier=not set`, the app is only signed for local running. Install an Apple Developer signing identity before distribution.
