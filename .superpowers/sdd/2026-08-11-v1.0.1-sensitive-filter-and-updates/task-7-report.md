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
