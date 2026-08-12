## 1. Identity Reproduction and Contract

- [x] 1.1 Compare historical V1.0.0 and V1.0.3 bundle identifiers, Team IDs, CDHashes, and designated requirements; record the ad-hoc identity root cause.
- [x] 1.2 Define stable public identity, first-migration, and real Accessibility upgrade acceptance scenarios.
- [x] 1.3 Record the missing Developer ID/notarization prerequisites in the pending-decisions list without storing credentials.

## 2. Cross-Version Release Gate

- [x] 2.1 Add a failing fixture-driven test for compatible and incompatible previous/candidate identities.
- [x] 2.2 Implement a verifier for bundle ID, Team ID, Developer ID authority, non-CDHash designated requirements, hardened runtime, and candidate notarization.
- [x] 2.3 Integrate the verifier into final release readiness while preserving explicit internal ad-hoc QA mode.
- [x] 2.4 Run the release tooling self-tests and strict OpenSpec validation.

## 3. Formal Distribution Setup

- [ ] 3.1 Obtain/install the stable Developer ID Application identity and record the expected Team ID in non-secret release configuration.
- [ ] 3.2 Configure external notarization credentials and produce a Developer ID signed, hardened, notarized V1.0.4 candidate.
- [ ] 3.3 Validate the DMG, Sparkle ZIP, embedded services, signature, Team ID, notarization, and appcast against the candidate.

## 4. Upgrade QA and Release Review

- [x] 4.1 Document that V1.0.3 ad-hoc users may need one final Accessibility authorization when moving to V1.0.4.
- [ ] 4.2 Install the previous stable-identity baseline, grant Accessibility, update through Sparkle, and record that trust and Automatic Paste survive the update.
- [ ] 4.3 Run full unit/build/release QA and obtain an independent code and release review.
- [ ] 4.4 Merge `release/v1.0.4` to `main` only after all formal identity and upgrade gates pass.
