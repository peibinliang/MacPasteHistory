#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /private/tmp/macpastehistory-release-verifiers.XXXXXX)"

case "$TEST_ROOT" in
    /private/tmp/macpastehistory-release-verifiers.*) ;;
    *)
        echo "Unsafe temporary test directory: $TEST_ROOT"
        exit 1
        ;;
esac

trap 'rm -rf "$TEST_ROOT"' EXIT

failures=()
fixture_index=0
CURRENT_FIXTURE=""

add_failure() {
    failures+=("$1")
}

create_fixture() {
    fixture_index=$((fixture_index + 1))
    CURRENT_FIXTURE="$TEST_ROOT/fixture-$fixture_index"

    mkdir -p \
        "$CURRENT_FIXTURE/scripts" \
        "$CURRENT_FIXTURE/MacPasteHistory/Resources" \
        "$CURRENT_FIXTURE/docs/release"
    cp "$REPO_ROOT/project.yml" "$CURRENT_FIXTURE/project.yml"
    cp "$REPO_ROOT/MacPasteHistory/Resources/Info.plist" \
        "$CURRENT_FIXTURE/MacPasteHistory/Resources/Info.plist"
    cp "$REPO_ROOT/MacPasteHistory/MacPasteHistory.entitlements" \
        "$CURRENT_FIXTURE/MacPasteHistory/MacPasteHistory.entitlements"
    cp "$REPO_ROOT/docs/release/RELEASE_PREP_GUIDE.md" \
        "$CURRENT_FIXTURE/docs/release/RELEASE_PREP_GUIDE.md"
    cp "$REPO_ROOT/docs/release/manual-qa-record.md" \
        "$CURRENT_FIXTURE/docs/release/manual-qa-record.md"
    cp "$REPO_ROOT/scripts/verify-sparkle-configuration.sh" \
        "$CURRENT_FIXTURE/scripts/verify-sparkle-configuration.sh"
    cp "$REPO_ROOT/scripts/verify-release-entitlements.sh" \
        "$CURRENT_FIXTURE/scripts/verify-release-entitlements.sh"
    cp "$REPO_ROOT/scripts/verify-release-version-build.sh" \
        "$CURRENT_FIXTURE/scripts/verify-release-version-build.sh"
}

expect_failure() {
    local label="$1"
    shift

    if "$@" >/dev/null 2>&1; then
        add_failure "$label: verifier unexpectedly passed."
    fi
}

expect_success() {
    local label="$1"
    shift

    if ! "$@" >/dev/null 2>&1; then
        add_failure "$label: verifier unexpectedly failed."
    fi
}

write_xpc_info() {
    local xpc_path="$1"
    local bundle_id="$2"
    /usr/bin/plutil -create xml1 "$xpc_path/Contents/Info.plist"
    /usr/bin/plutil -insert CFBundleIdentifier -string "$bundle_id" \
        "$xpc_path/Contents/Info.plist"
}

create_fixture
/usr/bin/plutil -replace 'com\.apple\.security\.network\.server' -bool true \
    "$CURRENT_FIXTURE/MacPasteHistory/MacPasteHistory.entitlements"
expect_failure \
    "Sparkle verifier requires network.server=false" \
    "$CURRENT_FIXTURE/scripts/verify-sparkle-configuration.sh"

create_fixture
/usr/bin/plutil -insert \
    'com\.apple\.security\.temporary-exception\.mach-lookup\.global-name.3' \
    -string 'com.apple.coreaudio' \
    "$CURRENT_FIXTURE/MacPasteHistory/MacPasteHistory.entitlements"
expect_failure \
    "Sparkle verifier rejects duplicate Mach exceptions" \
    "$CURRENT_FIXTURE/scripts/verify-sparkle-configuration.sh"

create_fixture
public_key="$(
    /usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' \
        "$CURRENT_FIXTURE/MacPasteHistory/Resources/Info.plist"
)"
malformed_public_key="${public_key}!"
/usr/libexec/PlistBuddy -c "Set :SUPublicEDKey $malformed_public_key" \
    "$CURRENT_FIXTURE/MacPasteHistory/Resources/Info.plist"
malformed_output=""
if malformed_output="$("$CURRENT_FIXTURE/scripts/verify-sparkle-configuration.sh" 2>&1)"; then
    add_failure "Sparkle verifier accepts malformed trailing Base64 input."
fi
if printf '%s' "$malformed_output" | grep -Fq "$malformed_public_key"; then
    add_failure "Sparkle verifier exposes malformed public-key input."
fi

create_fixture
/usr/bin/plutil -replace SUEnableAutomaticChecks -string true \
    "$CURRENT_FIXTURE/MacPasteHistory/Resources/Info.plist"
expect_failure \
    "Sparkle verifier rejects Info.plist string true" \
    "$CURRENT_FIXTURE/scripts/verify-sparkle-configuration.sh"

create_fixture
/usr/bin/plutil -replace 'com\.apple\.security\.network\.client' -string false \
    "$CURRENT_FIXTURE/MacPasteHistory/MacPasteHistory.entitlements"
expect_failure \
    "Sparkle verifier rejects entitlements string false" \
    "$CURRENT_FIXTURE/scripts/verify-sparkle-configuration.sh"

create_fixture
/usr/bin/plutil -replace 'com\.apple\.security\.app-sandbox' -string true \
    "$CURRENT_FIXTURE/MacPasteHistory/MacPasteHistory.entitlements"
expect_failure \
    "Entitlements verifier rejects string true" \
    "$CURRENT_FIXTURE/scripts/verify-release-entitlements.sh"

create_fixture
/usr/bin/plutil -replace 'com\.apple\.security\.network\.client' -string false \
    "$CURRENT_FIXTURE/MacPasteHistory/MacPasteHistory.entitlements"
expect_failure \
    "Entitlements verifier rejects string false" \
    "$CURRENT_FIXTURE/scripts/verify-release-entitlements.sh"

create_fixture
perl -pi -e 's/1\.0\.1/1x0x1/g' \
    "$CURRENT_FIXTURE/docs/release/RELEASE_PREP_GUIDE.md" \
    "$CURRENT_FIXTURE/docs/release/manual-qa-record.md"
expect_failure \
    "Version verifier treats dots literally" \
    "$CURRENT_FIXTURE/scripts/verify-release-version-build.sh"

release_app="$TEST_ROOT/release/粘易.app"
mkdir -p \
    "$release_app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc/Contents" \
    "$release_app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc/Contents"
cp "$REPO_ROOT/MacPasteHistory/Resources/Info.plist" "$release_app/Contents/Info.plist"
write_xpc_info \
    "$release_app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Installer.xpc" \
    "org.sparkle-project.InstallerLauncher"
write_xpc_info \
    "$release_app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" \
    "org.sparkle-project.DownloaderService"
expect_success \
    "Release bundle verifier accepts Sparkle 2.9.2 service paths" \
    "$REPO_ROOT/scripts/verify-sparkle-release-bundle.sh" "$release_app"

old_name_app="$TEST_ROOT/old-name/粘易.app"
mkdir -p \
    "$old_name_app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/InstallerLauncher.xpc/Contents" \
    "$old_name_app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc/Contents"
write_xpc_info \
    "$old_name_app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/InstallerLauncher.xpc" \
    "org.sparkle-project.InstallerLauncher"
write_xpc_info \
    "$old_name_app/Contents/Frameworks/Sparkle.framework/Versions/B/XPCServices/Downloader.xpc" \
    "org.sparkle-project.DownloaderService"
expect_failure \
    "Release bundle verifier rejects assumed InstallerLauncher.xpc path" \
    "$REPO_ROOT/scripts/verify-sparkle-release-bundle.sh" "$old_name_app"

echo "# Release Configuration Verifier Self-Test"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Negative cases | \`9\` |"
echo "| Positive bundle cases | \`1\` |"
echo "| Failures | \`${#failures[@]}\` |"
echo

if [[ "${#failures[@]}" -eq 0 ]]; then
    echo "Status: PASS"
    exit 0
fi

echo "Status: FAIL"
echo
echo "## Failures"
echo
for failure in "${failures[@]}"; do
    echo "- $failure"
done

exit 1
