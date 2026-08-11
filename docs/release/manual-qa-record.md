# Manual Release QA Record

Use this file to record manual evidence that cannot be proven by local automation. Do not mark an OpenSpec task complete until the matching evidence below is filled in with tester, date, build path, environment, and result.

Generate a current machine/build baseline before testing:

```bash
scripts/release-qa-baseline.sh --build
```

Copy the generated build, environment, signing, sandbox, and common-app availability values into the tables below, then replace each `Not run` result only after direct manual evidence exists.

Recommended one-command session setup:

```bash
scripts/start-manual-release-qa-session.sh
```

This creates a timestamped directory under `build/manual-release-qa-session/` with a QA package, package verification, baseline, synthetic fixtures, this record template, and a session `README.md`. Use the generated files as evidence inputs only; manual results still require direct tester confirmation.

Verify a generated session directory before manual testing:

```bash
scripts/verify-manual-release-qa-session.sh build/manual-release-qa-session/<session>
```

This also validates `release-qa-baseline.md`. To check only the baseline evidence file, run:

```bash
scripts/verify-release-qa-baseline.sh build/manual-release-qa-session/<session>/release-qa-baseline.md
```

To check only the package manifest and its embedded baseline, run:

```bash
scripts/verify-release-qa-manifest.sh build/manual-release-qa-session/<session>/package/MacPasteHistory-*-manifest.md
```

The session command pre-fills objective build, package, signing, current-machine, and fixture fields in the generated record copy. To pre-fill another record manually, run:

```bash
scripts/prefill-manual-qa-record.sh \
  --record /path/to/manual-qa-record.md \
  --baseline /path/to/release-qa-baseline.md \
  --verification /path/to/package-verification.md \
  --checksum /path/to/MacPasteHistory.zip.sha256 \
  --fixture-dir /path/to/fixtures
```

Pre-fill does not change any manual scenario result from `Not run`.

After filling this record, validate that no obvious placeholders or final-approval blockers remain:

```bash
scripts/validate-manual-qa-record.sh docs/release/manual-qa-record.md
```

For internal QA before distribution signing exists, use `--allow-adhoc`; do not use that flag for final release approval.

For QA on another Mac, create a zip package and use the generated manifest:

```bash
scripts/package-release-qa-build.sh
```

Verify the received QA zip before testing:

```bash
scripts/verify-release-qa-package.sh /path/to/MacPasteHistory-*.zip
```

The formal Sparkle update is a separate artifact. It must be named
`粘易-1.0.1-2.zip`, have an adjacent `.sha256`, and pass the strict verifier:

```bash
scripts/verify-release-qa-package.sh \
  --formal-update \
  /path/to/粘易-1.0.1-2.zip

scripts/verify-sparkle-appcast.sh \
  --appcast /path/to/appcast.xml \
  --archive /path/to/粘易-1.0.1-2.zip \
  --expected-public-key "$(/usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' MacPasteHistory/Resources/Info.plist)"
```

The verifiers reject unsafe archive paths, a top-level app symlink, and bundle
symlinks that resolve outside the extracted application. The appcast verifier
also requires the exact Sparkle namespace and canonical Base64 encoding of a
64-byte Ed25519 signature. That shape check is not cryptographic authenticity:
formal evidence must show the appcast came from Sparkle's official
`generate_appcast` workflow, and Sparkle performs the archive signature check
against the embedded `SUPublicEDKey` during the real update.

Do not paste a private Sparkle key into any command, record, or log. The public
key argument above is safe evidence and must match the committed Info.plist.

Run the install preflight before manual workflow testing:

```bash
scripts/release-install-preflight.sh
```

This launches a copied Release app from a temporary install directory, verifies isolated local storage initialization, and confirms quit behavior. Manual menu bar, restore, clear-all, and login-item checks still require direct tester evidence.

The final readiness report runs the same install preflight by default:

```bash
scripts/release-readiness-report.sh \
  --manual-record build/manual-release-qa-session/<session>/manual-qa-record.md \
  --qa-session build/manual-release-qa-session/<session> \
  --output build/release-readiness-report.md
```

The final readiness report also runs the synthetic Release smoke test by default. Use `--skip-release-smoke` or `--skip-install-preflight` only for temporary diagnostics, not for final release approval.

Generate synthetic, non-private copy fixtures for common-app and large-content testing:

```bash
scripts/generate-manual-qa-fixtures.swift
scripts/verify-manual-qa-fixtures.sh
```

Before final approval, run the static log privacy scan:

```bash
scripts/scan-privacy-log-safety.sh
scripts/verify-privacy-usage-descriptions.sh
```

This checks app Swift sources for direct console logging, public OSLog messages, and obvious clipboard-content fields in log calls. It is an automated guardrail; the manual Logs row below still requires runtime review.

Verify the App Icon asset catalog before release packaging:

```bash
scripts/verify-app-icon-assets.sh
```

Verify generated screenshot assets before release packaging:

```bash
scripts/verify-release-screenshot-assets.sh
```

## Build Under Test

| Field | Value |
|---|---|
| Date | TBD |
| Tester | TBD |
| Git commit | TBD |
| App path | TBD |
| Version / build | `1.0.1 (2)` |
| Signing identity | TBD |
| Package SHA-256 | TBD |
| Package manifest | TBD |
| Package verification | TBD |
| Formal update ZIP | TBD |
| Formal update SHA-256 | TBD |
| Verified appcast | TBD |
| Fixture directory | TBD |
| Notes | TBD |

## Environment Coverage

| Item | Environment | Result | Evidence / Notes |
|---|---|---|---|
| Apple Silicon | TBD | ⬜ Not run | Release smoke covers local automation; manual menu bar and restore still needed. |
| Intel Mac | TBD | ⬜ Not run | Required hardware or equivalent CI evidence. |
| macOS 14.x | TBD | ⬜ Not run | Minimum supported version. |
| macOS 15.x | TBD | ⬜ Not run | Additional supported version. |
| Current macOS | TBD | ⬜ Not run | Record exact `sw_vers` output. |

## Release App Workflow

| Scenario | Steps | Expected Result | Result | Evidence / Notes |
|---|---|---|---|---|
| First launch | Open Release app from Finder or `scripts/preview-release-app.sh` | Menu bar icon appears and app stays running. | ⬜ Not run | TBD |
| Open history | Click menu bar icon, choose Open History if needed | History window opens and is usable. | ⬜ Not run | TBD |
| Quit and relaunch | Quit from menu, reopen Release app | App exits cleanly and relaunches. | ⬜ Not run | TBD |
| Restart persistence | Copy sample text/image, quit, relaunch | Existing history remains visible. | ⬜ Not run | TBD |
| Restore text | Click restore on a text item, paste into TextEdit | Pasted text matches source. | ⬜ Not run | TBD |
| Double-click paste | Open history from a text-field app, double-click a text history item | History window closes, focus returns to the original app, and matching text is pasted; grant Accessibility permission first if prompted. | ⬜ Not run | TBD |
| Restore image | Click restore on an image item, paste into Preview/Notes | Pasted image matches source. | ⬜ Not run | TBD |
| Clear all data | Settings -> Clear All Data -> confirm | Database records and image files are removed; list refreshes. | ⬜ Not run | TBD |
| Launch at login | Enable setting, log out/in or restart | App starts automatically if setting remains enabled. | ⬜ Not run | TBD |

## Common App Copy Matrix

| App | Text Copy | Image Copy | Restore Back | Notes |
|---|---|---|---|---|
| Google Chrome | ⬜ Not run | ⬜ Not run | ⬜ Not run | TBD |
| Safari | ⬜ Not run | ⬜ Not run | ⬜ Not run | TBD |
| VS Code | ⬜ Not run | N/A | ⬜ Not run | Verify code text preserves content. |
| WeChat | ⬜ Not run | ⬜ Not run | ⬜ Not run | Use non-private test account/chat only. |
| DingTalk | ⬜ Not run | ⬜ Not run | ⬜ Not run | Use non-private test account/chat only. |

## Privacy And Safety Checks

| Scenario | Expected Result | Result | Evidence / Notes |
|---|---|---|---|
| Pause recording | New clipboard content is not saved while paused. | ⬜ Not run | TBD |
| Sensitive text | Password/token-like sample is skipped. | ⬜ Not run | TBD |
| Blocked app | Content from blocked app is skipped. | ⬜ Not run | TBD |
| Logs | Logs contain no full clipboard content or sensitive data. | ⬜ Not run | TBD |
| Local storage | History and images stay under app Application Support. | ⬜ Not run | TBD |

## Enhanced Search, Actions And OCR

| Scenario | Expected Result | Result | Evidence / Notes |
|---|---|---|---|
| Structured search | `app:terminal type:shell docker`, `fav:true`, and `before:7d` produce expected tokens and results. | ⬜ Not run | TBD |
| Action panel layouts | Wide display keeps history and action panel visible; narrow display uses Back/overlay behavior. | ⬜ Not run | TBD |
| Action categories | JSON, URL, Base64, JWT, timestamp, SQL, shell and text actions produce expected local output. | ⬜ Not run | TBD |
| JWT warning | Unsigned JWT displays signature-not-verified warning and any expiry state. | ⬜ Not run | TBD |
| Editable chain | Base64 decode → JSON format can edit, move back and branch. | ⬜ Not run | TBD |
| Result attribution | Copy/direct-paste/save produce the expected reuse/paste counters and derived record. | ⬜ Not run | TBD |
| Manual OCR | Synthetic English/简体/繁體 image is only recognized after click, remains editable, then searchable after Save. | ⬜ Not run | TBD |
| Derived origin | Deleting an origin retains the derived summary and indicates missing source. | ⬜ Not run | TBD |

## V1.0.0 → V1.0.1 Upgrade Evidence

Use a real V1.0.0 installation and the Developer ID signed, notarized, EdDSA-signed
formal update. A synthetic fixture, direct app replacement, or ad-hoc build is not
valid evidence for this section. Record the source installation path, pre/post
counts, timestamps, screenshots or logs that contain no clipboard payloads, and
the tester for every passed row.

| Scenario | Expected Result | Result | Evidence / Notes |
|---|---|---|---|
| V1.0.0 baseline captured | Installed app reports V1.0.0 and pre-upgrade history, favorites, settings, and shortcut values are recorded. | ⬜ Not run | TBD |
| Manual update check | Check for Updates reaches the fixed HTTPS appcast and offers V1.0.1 (2). | ⬜ Not run | TBD |
| Automatic update prompt | Sparkle's scheduled check offers the same signed V1.0.1 update without a second updater instance. | ⬜ Not run | TBD |
| Download, install, and restart | Sparkle downloads, verifies, replaces, and restarts the app as V1.0.1 (2). | ⬜ Not run | TBD |
| History and favorites preserved | Post-upgrade history count and favorite state match the recorded V1.0.0 baseline. | ⬜ Not run | TBD |
| Settings and shortcut preserved | Sensitive-filter preference, other settings, and configured shortcut match the recorded V1.0.0 baseline. | ⬜ Not run | TBD |

## Decision

| Item | Value |
|---|---|
| Ready for distribution? | ⬜ No |
| Blocking issues | TBD |
| Follow-up issues | TBD |
| Approver | TBD |
