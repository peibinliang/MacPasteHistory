#!/usr/bin/env bash
set -euo pipefail

if [[ "$#" -ne 1 ]]; then
    echo "Usage: $0 /path/to/Application.app" >&2
    exit 2
fi

APP_PATH="$1"
SPARKLE_FRAMEWORK_RELATIVE_PATH="Contents/Frameworks/Sparkle.framework"
INSTALLER_RELATIVE_PATH="$SPARKLE_FRAMEWORK_RELATIVE_PATH/Versions/B/XPCServices/Installer.xpc"
DOWNLOADER_RELATIVE_PATH="$SPARKLE_FRAMEWORK_RELATIVE_PATH/Versions/B/XPCServices/Downloader.xpc"
EXPECTED_INSTALLER_BUNDLE_ID="org.sparkle-project.InstallerLauncher"
EXPECTED_DOWNLOADER_BUNDLE_ID="org.sparkle-project.DownloaderService"

add_violation() {
    violations+=("$1")
}

require_directory() {
    local relative_path="$1"

    if [[ ! -d "$APP_PATH/$relative_path" ]]; then
        add_violation "Required embedded path is missing: $relative_path"
    fi
}

bundle_identifier() {
    local relative_path="$1"
    /usr/libexec/PlistBuddy \
        -c "Print :CFBundleIdentifier" \
        "$APP_PATH/$relative_path/Contents/Info.plist" 2>/dev/null || true
}

violations=()

if [[ ! -d "$APP_PATH" ]]; then
    add_violation "Release application bundle is missing: $APP_PATH"
fi

require_directory "$SPARKLE_FRAMEWORK_RELATIVE_PATH"
require_directory "$INSTALLER_RELATIVE_PATH"
require_directory "$DOWNLOADER_RELATIVE_PATH"

installer_bundle_id="$(bundle_identifier "$INSTALLER_RELATIVE_PATH")"
downloader_bundle_id="$(bundle_identifier "$DOWNLOADER_RELATIVE_PATH")"

if [[ "$installer_bundle_id" != "$EXPECTED_INSTALLER_BUNDLE_ID" ]]; then
    add_violation "Installer.xpc has bundle ID '$installer_bundle_id', expected '$EXPECTED_INSTALLER_BUNDLE_ID'."
fi

if [[ "$downloader_bundle_id" != "$EXPECTED_DOWNLOADER_BUNDLE_ID" ]]; then
    add_violation "Downloader.xpc has bundle ID '$downloader_bundle_id', expected '$EXPECTED_DOWNLOADER_BUNDLE_ID'."
fi

echo "# Sparkle Release Bundle Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Release app | \`$APP_PATH\` |"
echo "| Sparkle framework | \`$SPARKLE_FRAMEWORK_RELATIVE_PATH\` |"
echo "| Installer Launcher service | \`$INSTALLER_RELATIVE_PATH\` |"
echo "| Installer Launcher bundle ID | \`$installer_bundle_id\` |"
echo "| Downloader service | \`$DOWNLOADER_RELATIVE_PATH\` |"
echo "| Downloader bundle ID | \`$downloader_bundle_id\` |"
echo "| Violations | \`${#violations[@]}\` |"
echo

if [[ "${#violations[@]}" -eq 0 ]]; then
    echo "Status: PASS"
    exit 0
fi

echo "Status: FAIL"
echo
echo "## Violations"
echo
for violation in "${violations[@]}"; do
    echo "- $violation"
done

exit 1
