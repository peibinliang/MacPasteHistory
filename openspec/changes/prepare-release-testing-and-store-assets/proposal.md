## Why

Before distribution, the app needs sandboxing, signing, release builds, compatibility testing, common-copy scenario testing, documentation, privacy policy, and store assets. This phase turns the implemented app into a release-ready package.

## What Changes

- Configure App Sandbox.
- Configure signing certificates and Release build settings.
- Test Intel Mac and Apple Silicon Mac compatibility.
- Test supported macOS versions.
- Test copy behavior in common apps such as Chrome, Safari, VS Code, WeChat, and DingTalk.
- Test large text and large image scenarios.
- Write user help documentation.
- Write privacy policy.
- Prepare App Store screenshots.

## Capabilities

### New Capabilities
- `prepare-release-testing-and-store-assets`: Release configuration, compatibility testing, copy-scenario QA, large-content testing, user documentation, privacy policy, and App Store assets.

### Modified Capabilities

## Impact

- Affects Xcode project configuration, entitlements, signing, Release builds, QA plans, documentation files, privacy policy, screenshots, and distribution readiness.
