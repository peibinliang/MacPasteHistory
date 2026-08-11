# Task 7 Report: Reproducible Sparkle Release Artifacts

## Outcome

Task 7 adds explicit-path, fail-closed tooling for the V1.0.1 Sparkle archive,
adjacent SHA-256, release notes, appcast generation, appcast verification, and
strict-final readiness evidence. No remote release, push, GitHub Pages change,
credential change, or private-key operation was performed.

The isolated script fixtures prove verifier and orchestration logic only. They
are explicitly not evidence of a formal Developer ID, Apple-notarized, Sparkle
EdDSA-signed release.

## TDD Evidence

### RED

Command:

```bash
scripts/test-sparkle-release-artifact-tooling.sh
```

Initial result: `FAIL`, 6 failures. The unsigned fixture could not produce the
required `missing sparkle:edSignature` failure because the verifier did not yet
exist, the positive fixture could not run, and formal packaging rejected the
unknown `--formal-update` option.

RED checkpoint commit:

```text
b0751fb test: cover Sparkle release artifact tooling
```

### GREEN

Command:

```bash
bash -n \
  scripts/generate-sparkle-appcast.sh \
  scripts/verify-sparkle-appcast.sh \
  scripts/package-release-qa-build.sh \
  scripts/verify-release-qa-package.sh \
  scripts/release-readiness-report.sh \
  scripts/test-sparkle-release-artifact-tooling.sh

scripts/test-sparkle-release-artifact-tooling.sh
```

Result: `PASS`, 0 failures. Covered results include:

- deliberately unsigned appcast fails with `missing sparkle:edSignature`;
- isolated signed-shape appcast fixture passes strict metadata checks;
- malformed XML, wrong version, wrong URL, wrong length, checksum mismatch,
  bundle-ID mismatch, and public-key mismatch fail;
- generation uses the fixed GitHub URL prefix and `--maximum-versions 10`;
- generation invokes the formal archive gate before Sparkle;
- failed unsigned generation leaves the previously verified docs appcast intact;
- formal packaging and formal archive verification reject unsigned applications.

GREEN implementation commit:

```text
1873506 Add Sparkle release artifact tooling
```

## Verification Evidence

Commands and exact results:

```text
scripts/test-release-configuration-verifiers.sh
Status: PASS; negative cases: 9; positive bundle cases: 1; failures: 0

scripts/verify-sparkle-configuration.sh
Status: PASS; violations: 0; Sparkle: 2.9.2; version/build: 1.0.1 (2)

scripts/verify-release-version-build.sh
Status: PASS; violations: 0; expected and actual: 1.0.1 (2)

scripts/validate-xcode-file-references.sh
Status: PASS; Swift references checked: 175; missing Swift files: 0

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' test
** TEST SUCCEEDED **; executed 271 tests with 0 failures

git diff --check
Exit 0; no output
```

The first sandboxed Xcode attempt could not write SwiftPM/Xcode cache files and
failed during package resolution. It was rerun with the required cache/service
access; the fresh full result above passed.

Strict-final missing-evidence check:

```text
scripts/release-readiness-report.sh \
  --skip-xcodegen \
  --skip-release-smoke \
  --skip-install-preflight \
  --allow-adhoc \
  --strict-final \
  --output /private/tmp/task7-readiness.md

Exit 1, as required.
Sparkle configuration: PASS
Formal update ZIP: SKIP
Embedded Sparkle framework and XPC services: SKIP
Developer ID signature: SKIP
Apple notarization: SKIP
Sparkle appcast: SKIP
V1.0.0 → V1.0.1 upgrade evidence: WARN
Blocker: Strict final mode requires zero warnings.
```

Other pre-existing/incomplete release evidence also blocks that report, including
the unfilled manual QA template. A sandbox-only manual fixture generation attempt
also lacked Swift cache write access; this does not affect the separately rerun
Xcode suite or the Task 7 shell self-test.

## Formal Release Blockers

Formal positive release validation was not and must not be marked complete:

```text
security find-identity -p codesigning -v
0 valid identities found
```

No Developer ID Application identity, notarized V1.0.1 application, genuine
Sparkle EdDSA-signed appcast/archive pair, or completed V1.0.0 → V1.0.1 upgrade
record is available locally. Consequently:

- no formal `粘易-1.0.1-2.zip` was produced;
- no formal adjacent checksum or release notes were produced;
- `docs/appcast.xml` was not generated or committed;
- no GitHub Release, GitHub Pages, push, or other remote modification occurred.

## Documentation

- `docs/release/RELEASE_PREP_GUIDE.md` documents explicit formal packaging,
  verification, generation, remote-action boundaries, publish ordering, and
  strict-final invocation.
- `docs/release/manual-qa-record.md` adds formal artifact fields and direct
  V1.0.0 → V1.0.1 manual/automatic upgrade, restart, and preservation evidence.

No database migration or user-data compatibility change is introduced by this
task.

## Independent Review Hardening

An independent Task 7 review identified archive-boundary, XML namespace,
signature-shape, and packaging-path gaps. Each issue received a regression test
before its implementation.

### Review RED

Command:

```bash
scripts/test-sparkle-release-artifact-tooling.sh
```

Initial review result: `FAIL`, 11 failures. The failures demonstrated that the
old tooling accepted or insufficiently rejected a synthetic text signature, an
evil Sparkle namespace, a symlink-only app archive, traversal entries, an
escaping bundle symlink, app/output path aliases, and an unverified staged
package.

RED checkpoint commit:

```text
7341977 test: cover release archive boundary hardening
```

A narrower symlink regression was then run before its implementation: a bundle
link resolving to an allowed `__MACOSX` entry stayed inside the extraction root
but outside the application bundle. Exact result: `FAIL`, 2 failures before the
fixture was narrowed to the appcast case; the appcast verifier unexpectedly
passed, and the formal package fixture exposed `ditto`'s `__MACOSX` extraction
behavior. The final regression creates the complete archive with `ditto` and
proves the appcast verifier rejects that link while still accepting an internal
`Contents/InternalInfoLink -> Info.plist` fixture.

### Review GREEN

Implementation commit:

```text
2f31199 Harden release archive verification
```

The implementation now:

- preflights every ZIP entry and rejects empty/invalid archives, absolute paths,
  Windows absolute paths, and any `..` component before `ditto` extraction;
- rejects a top-level app symlink, requires a physical/canonical app under the
  extraction root, and rejects broken or escaping symlinks; links lexically
  inside the app must resolve inside the app, while legitimate internal
  framework-style links remain supported;
- binds `shortVersionString`, `version`, and `edSignature` to the exact Sparkle
  namespace URI and rejects wrong-namespace lookalikes;
- requires canonical Base64 for exactly 64 decoded Ed25519-signature bytes, so
  arbitrary non-empty text fails closed;
- canonicalizes the formal app and output directory, rejects app symlink input
  (including a trailing slash), rejects output equal to or inside the app even
  through an alias, and verifies a staged formal ZIP before publishing final
  local filenames.

The 64-byte Base64 fixture is a structural positive only. It is not a valid
Sparkle signature and is not formal release evidence. Sparkle 2.9.2's official
`sign_update --verify` does not provide public-key-only verification: it derives
the public key by accessing a private key file or the keychain. The project
verifier therefore does not invoke it, never accepts or reads private material,
and explicitly reports that cryptographic authenticity is deferred to the
official `generate_appcast` signing workflow and Sparkle client verification
against the embedded `SUPublicEDKey`.

### Review Verification

Commands and exact results:

```text
bash -n scripts/generate-sparkle-appcast.sh \
  scripts/verify-sparkle-appcast.sh \
  scripts/package-release-qa-build.sh \
  scripts/verify-release-qa-package.sh \
  scripts/release-readiness-report.sh \
  scripts/test-sparkle-release-artifact-tooling.sh
Exit 0; no output

scripts/test-sparkle-release-artifact-tooling.sh
Status: PASS; failures: 0

scripts/test-release-configuration-verifiers.sh
Status: PASS; negative cases: 9; positive bundle cases: 1; failures: 0

scripts/verify-sparkle-configuration.sh
Status: PASS; violations: 0; Sparkle: 2.9.2; version/build: 1.0.1 (2)

scripts/verify-release-version-build.sh
Status: PASS; violations: 0; expected and actual: 1.0.1 (2)

scripts/validate-xcode-file-references.sh
Status: PASS; Swift references checked: 175; missing Swift files: 0

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project MacPasteHistory.xcodeproj \
  -scheme MacPasteHistory \
  -destination 'platform=macOS,arch=arm64' test
** TEST SUCCEEDED **; executed 271 tests with 0 failures

git diff --check
Exit 0; no output
```

The first sandboxed Xcode run exited 74 because it could not write Xcode,
SwiftPM, or Clang caches. The same command was immediately rerun with the needed
local cache/service access and produced the passing 271-test result above.

The fresh strict-final missing-evidence audit remained fail-closed:

```text
scripts/release-readiness-report.sh \
  --skip-xcodegen \
  --skip-release-smoke \
  --skip-install-preflight \
  --allow-adhoc \
  --strict-final \
  --output /private/tmp/task7-review-readiness.md

Exit 1, as required.
Formal update ZIP: SKIP
Developer ID signature: SKIP
Apple notarization: SKIP
Sparkle appcast: SKIP
V1.0.0 → V1.0.1 upgrade evidence: WARN
Blocker: Strict final mode requires zero warnings.
```

Formal positive evidence is still blocked and was not claimed:

```text
security find-identity -p codesigning -v
0 valid identities found
```

No Developer ID Application identity, notarized artifact, genuine Sparkle
EdDSA-signed archive/appcast pair, or completed upgrade record is available.
No GitHub Release, Pages update, push, credential operation, or other remote
modification was performed.

## Final Review: V1.0.1 OpenSpec Progress

Final branch review found that `release-readiness-report.sh` still invoked and
serialized `prepare-release-testing-and-store-assets`, so a V1.0.1 readiness
report could show the wrong change or `0/0` when the OpenSpec CLI was absent.

### Progress RED

Command:

```text
scripts/test-release-readiness-openspec-progress.sh
```

Exact result before implementation: `Status: FAIL`, 3 failures:

- default JSON reported `prepare-release-testing-and-store-assets` with `0/0`;
- explicit `--openspec-change add-v1-0-1-sensitive-filter-and-updates` did not
  produce JSON because the option did not exist;
- explicit `--openspec-change prepare-release-testing-and-store-assets` also
  did not produce JSON.

RED checkpoint:

```text
1508740 test: cover V1.0.1 readiness progress
```

### Progress GREEN

Implementation commit:

```text
9e6ab44 Fix V1.0.1 readiness task progress
```

The report now defaults to
`add-v1-0-1-sensitive-filter-and-updates`, reads checkbox state directly from
the selected `openspec/changes/<change>/tasks.md`, and emits the same selected
change/counts/tasks in Markdown and JSON. The explicit `--openspec-change NAME`
option remains available for historical diagnostics; the change name is
restricted to one safe directory component.

The current V1.0.1 Markdown source reports `24/32` complete with 8 remaining
tasks: `6.1`–`6.5` and `8.2`–`8.4`. Explicit selection of the historical change
reports its actual `4/19` complete with 15 remaining tasks. Missing or failing
OpenSpec CLI validation remains a warning even though Markdown progress is
preserved. Pending tasks are also warnings, so `--strict-final` converts either
condition into a blocker instead of allowing a report based on the old change
to pass.

### Progress Verification

```text
bash -n scripts/*.sh
Exit 0; no output

scripts/test-release-readiness-openspec-progress.sh
Status: PASS; failures: 0
Default: add-v1-0-1-sensitive-filter-and-updates, 24/32, 8 remaining
Explicit legacy: prepare-release-testing-and-store-assets, 4/19, 15 remaining

scripts/test-release-configuration-verifiers.sh
Status: PASS; negative cases: 9; positive bundle cases: 1; failures: 0

scripts/test-sparkle-release-artifact-tooling.sh
Status: PASS; failures: 0

scripts/validate-xcode-file-references.sh
Status: PASS; Swift references checked: 175; missing Swift files: 0

scripts/scan-privacy-log-safety.sh
Status: PASS; Swift files scanned: 110; direct console calls: 0

scripts/verify-privacy-usage-descriptions.sh
Status: PASS; violations: 0

scripts/verify-supported-macos-targets.sh
Status: PASS; violations: 0

scripts/verify-release-version-build.sh
Status: PASS; violations: 0; version/build: 1.0.1 (2)

scripts/verify-release-entitlements.sh
Status: PASS; violations: 0

scripts/verify-release-identity.sh
Status: PASS; violations: 0

scripts/verify-sparkle-configuration.sh
Status: PASS; violations: 0; Sparkle: 2.9.2

scripts/verify-app-icon-assets.sh
Status: PASS; violations: 0

scripts/verify-release-screenshot-assets.sh
Status: PASS; violations: 0

scripts/verify-xcode-authorization.sh
Status: PASS; violations: 0

scripts/verify-manual-qa-fixtures.sh
Status: PASS; text fixtures: 7/7; image fixtures: 2/2; violations: 0

scripts/verify-signing-identities.sh --allow-adhoc
Status: WARN; 0 valid identities; formal distribution remains blocked

git diff --check
Exit 0; no output
```

Fresh expected-failure gate:

```text
env PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  scripts/release-readiness-report.sh \
  --skip-xcodegen \
  --skip-release-smoke \
  --skip-install-preflight \
  --allow-adhoc \
  --strict-final \
  --output /private/tmp/task7-openspec-readiness.md \
  --json-output /private/tmp/task7-openspec-readiness.json

Exit 1, as required.
OpenSpec change: add-v1-0-1-sensitive-filter-and-updates
OpenSpec progress: WARN; 24/32 complete; 8 remaining
OpenSpec CLI: not available; Markdown progress retained
Strict-final blocker: requires zero warnings
JSON remaining IDs: 6.1, 6.2, 6.3, 6.4, 6.5, 8.2, 8.3, 8.4
```

No Swift source changed in this review fix, so the fresh verification used the
complete shell syntax, focused self-test, and release static/verifier suite.
The earlier Task 7 full XCTest evidence remains 271 tests with 0 failures; the
final integration controller will rerun the full suite. The Developer ID,
notarization, genuine Sparkle artifact, upgrade evidence, and remote-action
blockers are unchanged, and no remote operation was performed.

## Readiness Review Round 1: JSON and Markdown Fences

Review found two additional fail-closed gaps: `emit_json_summary` interpolated
shell-controlled strings into Python source through an unquoted heredoc, and the
Markdown task parser counted checkbox-looking lines inside fenced code blocks.

### Round 1 RED

Regression checkpoint:

```text
e61bfac test: cover readiness JSON and fenced tasks
```

Initial command and exact result:

```text
scripts/test-release-readiness-openspec-progress.sh
Status: FAIL; failures: 5
```

The failures proved that:

- a manual-record/appcast value containing quotes, backslashes, newlines,
  Unicode, and Python-like text prevented JSON generation;
- a deliberately valid Python-expression injection in `--manual-record`
  created an isolated marker file and changed the JSON object rather than
  remaining inert data;
- four fake task checkboxes inside backtick and tilde fences were counted,
  producing `3/7` instead of the hand-derived fixture result `2/3`;
- the remaining-task list incorrectly included fenced task IDs `9.1`, `9.2`,
  and `9.4`.

### Round 1 GREEN

Implementation checkpoint:

```text
6fc38c4 Harden readiness JSON serialization
```

`emit_json_summary` now uses a quoted `<<'PY'` heredoc. All scalar dynamic
values are passed as quoted argv entries, and arrays are transferred through
NUL-delimited temporary files so quotes, backslashes, tabs, newlines, and
Unicode never become Python source. Python constructs the object and
`json.dump` performs the only JSON serialization. No `eval` or equivalent
dynamic execution is used.

The Markdown parser now maintains fenced-block state for both backtick and
tilde markers. A closing fence must use the same marker and be at least as long
as the opener. The existing policy remains unchanged for nested/indented
checkboxes: only column-zero task checkboxes are counted. The committed fixture
also verifies a shorter false close, a different-marker false close, quotes,
one backslash, an em dash, and Unicode task text.

### Round 1 Verification

```text
bash -n scripts/release-readiness-report.sh \
  scripts/test-release-readiness-openspec-progress.sh
Exit 0; no output

scripts/test-release-readiness-openspec-progress.sh
Status: PASS; failures: 0
Default V1.0.1 progress: 24/32; 8 remaining
JSON escaping/injection fixtures: inert exact round-trip; no marker side effect
Fenced checkbox fixture: 2/3; only task 1.2 remains
Remaining text: Pending "quoted" \\ path — 雪
```

Fresh strict-final expected failure:

```text
env PATH=/usr/bin:/bin:/usr/sbin:/sbin \
  scripts/release-readiness-report.sh \
  --skip-xcodegen \
  --skip-release-smoke \
  --skip-install-preflight \
  --allow-adhoc \
  --strict-final \
  --output /private/tmp/task7-json-review-readiness.md \
  --json-output /private/tmp/task7-json-review-readiness.json

Exit 1, as required.
OpenSpec change: add-v1-0-1-sensitive-filter-and-updates
OpenSpec progress: WARN; 24/32 complete; 8 remaining
JSON remaining IDs: 6.1, 6.2, 6.3, 6.4, 6.5, 8.2, 8.3, 8.4
Strict-final blocker: requires zero warnings
```

No Swift source, release artifact, credential, private key, remote release, or
GitHub state was changed. Existing Developer ID, notarization, genuine Sparkle
artifact, upgrade-evidence, and explicit remote-authorization blockers remain.
