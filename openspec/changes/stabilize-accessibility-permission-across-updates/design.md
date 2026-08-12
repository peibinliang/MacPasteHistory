## Context

See `proposal.md` for motivation. Historical public artifacts use the stable bundle identifier `com.peibin.MacPasteHistory`, but their ad-hoc designated requirements are CDHash-based. The measured V1.0.0 and V1.0.3 CDHashes differ, so macOS cannot establish a stable client identity across replacement. The existing Accessibility services correctly query `AXIsProcessTrusted()` and must not attempt to edit or bypass TCC state.

The repository already contains formal-update checks for Developer ID signing and notarization, but the public V1.0.3 artifacts were produced through the ad-hoc QA path. The current machine reports zero valid code-signing identities.

## Goals / Non-Goals

**Goals:**

- Make code identity continuity a machine-checked release invariant.
- Separate internal ad-hoc QA from public distribution unambiguously.
- Require evidence from a real update after credentials are available.
- Keep signing keys and notarization credentials outside the repository.

**Non-Goals:**

- Resetting, editing, or migrating the macOS TCC database.
- Suppressing the legitimate first authorization required when moving from historical ad-hoc builds to Developer ID.
- Changing Accessibility prompts or Automatic Paste behavior without evidence of an application bug.

## Decisions

### Use Developer ID identity rather than application-side permission workarounds

All public builds will be signed using `Developer ID Application` under one expected Team ID and notarized. TCC identity is a platform security boundary; application code cannot safely transfer its own authorization. Self-signed or ad-hoc alternatives remain build-specific and do not solve the identity problem.

### Compare consecutive release identities before publication

A verifier will inspect both app bundles with `codesign`, verify the production bundle identifier and expected Team ID, reject ad-hoc/CDHash-only designated requirements, and confirm the candidate's notarization. Comparing only the candidate is insufficient because continuity is a relationship between two releases.

### Keep secrets external and make their absence an explicit blocker

The Team ID may be supplied as non-secret release configuration, while the certificate/private key and notarization credentials remain in the operator keychain or CI secret store. Missing credentials block formal artifacts but do not block implementation of the verifier and documentation.

### Retain one manual Accessibility upgrade check

Static identity checks are necessary but cannot prove the current macOS TCC behavior end to end. Final approval therefore records a real previous-version-to-candidate Sparkle update with pre-authorized Accessibility and post-update `AXIsProcessTrusted()`/Automatic Paste evidence.

## Risks / Trade-offs

- [The first Developer ID build has a different identity from all historical ad-hoc builds] → Communicate one final reauthorization; measure continuity beginning with the first Developer ID baseline.
- [Certificate rotation can alter requirements] → Compare designated requirements and Team ID for every release; perform a real upgrade smoke after rotation.
- [Developer credentials are unavailable on the current machine] → Complete tooling and planning now, but keep packaging and final validation blocked in the pending-decisions list.
- [A static requirement comparison may miss platform behavior] → Preserve the manual update scenario as a final gate.

## Migration Plan

1. Add and test the cross-version identity verifier.
2. Configure the stable Team ID and install the Developer ID Application identity outside source control.
3. Produce a hardened, signed, notarized V1.0.4 candidate using the formal-update path.
4. Inform existing users that migration from ad-hoc V1.0.3 may require one final Accessibility authorization.
5. Establish V1.0.4 as the first stable-identity baseline; require every later release to compare against it.
6. Roll back publication rather than shipping an ad-hoc replacement if any identity or update smoke gate fails.
