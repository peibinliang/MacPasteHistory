## Context

The final phase prepares the app for real distribution. It focuses on packaging correctness, platform compatibility, user-facing documentation, privacy material, and release validation.

## Goals / Non-Goals

**Goals:**
- Produce a signed Release build.
- Configure sandboxing and distribution settings.
- Validate compatibility across CPU architectures and macOS versions.
- Test common app copy flows and large content.
- Prepare user help, privacy policy, and App Store screenshots.

**Non-Goals:**
- New product features should not be introduced in this phase except fixes required to pass release testing.

## Decisions

- Treat the Release build as the artifact under test so QA matches distribution behavior.
- Keep a checklist for app launch, install, quit, restart, copy scenarios, cleanup, and privacy material.
- Test both Intel and Apple Silicon where hardware or CI access is available.
- Prepare privacy policy and screenshots as explicit release artifacts, not ad hoc marketing tasks.

## Risks / Trade-offs

- Sandbox configuration may restrict file or pasteboard behavior -> test capture and restore after sandboxing is enabled.
- Signing and notarization can fail late -> configure certificates and Release builds before final QA.
- Hardware/macOS coverage may be limited -> document tested environments and any untested combinations.
