#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$REPO_ROOT/MacPasteHistory/Resources/Info.plist"
ENTITLEMENTS_PLIST="$REPO_ROOT/MacPasteHistory/MacPasteHistory.entitlements"
PROJECT_YML="$REPO_ROOT/project.yml"

EXPECTED_VERSION="1.0.2"
EXPECTED_BUILD="4"
EXPECTED_FEED_URL="https://peibinliang.github.io/MacPasteHistory/appcast.xml"
EXPECTED_SPARKLE_VERSION="2.9.2"

add_violation() {
    violations+=("$1")
}

plist_value() {
    local plist="$1"
    local key="$2"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist" 2>/dev/null || true
}

plist_type() {
    local plist="$1"
    local key="$2"
    local escaped_key="${key//./\\.}"
    /usr/bin/plutil -type "$escaped_key" "$plist" 2>/dev/null || true
}

require_plist_value() {
    local plist="$1"
    local key="$2"
    local expected="$3"
    local value
    value="$(plist_value "$plist" "$key")"

    if [[ "$value" != "$expected" ]]; then
        add_violation "$key is not configured with the required value."
    fi
}

require_plist_boolean() {
    local plist="$1"
    local key="$2"
    local expected="$3"
    local type
    local value
    type="$(plist_type "$plist" "$key")"
    value="$(plist_value "$plist" "$key")"

    if [[ "$type" != "bool" || "$value" != "$expected" ]]; then
        add_violation "$key must be the Boolean value $expected."
    fi
}

mach_lookup_count() {
    local expected="$1"
    /usr/libexec/PlistBuddy \
        -c "Print :com.apple.security.temporary-exception.mach-lookup.global-name" \
        "$ENTITLEMENTS_PLIST" 2>/dev/null \
        | awk '{$1=$1; print}' \
        | grep -Fxc "$expected" || true
}

require_single_mach_lookup() {
    local expected="$1"
    local count="$2"

    if [[ "$count" -ne 1 ]]; then
        add_violation "Mach lookup exception '$expected' appears $count times, expected exactly once."
    fi
}

is_valid_public_key() {
    local public_key="$1"
    local normalized_key
    local decoded_size

    normalized_key="$(printf '%s' "$public_key" | tr '[:upper:]' '[:lower:]')"
    case "$normalized_key" in
        ""|sample|example|placeholder|changeme|replace-me|replace_me|your-public-key|your_public_key|*private*|*begin\ *key*)
            return 1
            ;;
    esac

    if ! printf '%s' "$public_key" | /usr/bin/base64 -D >/dev/null 2>&1; then
        return 1
    fi

    decoded_size="$(printf '%s' "$public_key" | /usr/bin/base64 -D 2>/dev/null | wc -c | tr -d '[:space:]')"
    [[ "$decoded_size" == "32" ]]
}

sparkle_exact_version() {
    awk '
        /^  Sparkle:$/ { in_sparkle = 1; next }
        in_sparkle && /^[^ ]/ { exit }
        in_sparkle && $1 == "exactVersion:" { print $2; exit }
    ' "$PROJECT_YML"
}

violations=()

require_plist_value "$INFO_PLIST" "CFBundleShortVersionString" "$EXPECTED_VERSION"
require_plist_value "$INFO_PLIST" "CFBundleVersion" "$EXPECTED_BUILD"
require_plist_value "$INFO_PLIST" "SUFeedURL" "$EXPECTED_FEED_URL"
require_plist_boolean "$INFO_PLIST" "SUEnableAutomaticChecks" "true"
require_plist_boolean "$INFO_PLIST" "SUEnableInstallerLauncherService" "true"
require_plist_boolean "$INFO_PLIST" "SUEnableDownloaderService" "true"
require_plist_boolean "$ENTITLEMENTS_PLIST" "com.apple.security.network.client" "true"
require_plist_boolean "$ENTITLEMENTS_PLIST" "com.apple.security.network.server" "false"

public_key="$(plist_value "$INFO_PLIST" "SUPublicEDKey")"
public_key_status="configured"
if ! is_valid_public_key "$public_key"; then
    public_key_status="missing or invalid"
    add_violation "SUPublicEDKey must contain a non-sample EdDSA public key."
fi

coreaudio_count="$(mach_lookup_count "com.apple.coreaudio")"
installer_count="$(mach_lookup_count '$(PRODUCT_BUNDLE_IDENTIFIER)-spks')"
downloader_count="$(mach_lookup_count '$(PRODUCT_BUNDLE_IDENTIFIER)-spki')"

require_single_mach_lookup "com.apple.coreaudio" "$coreaudio_count"
require_single_mach_lookup '$(PRODUCT_BUNDLE_IDENTIFIER)-spks' "$installer_count"
require_single_mach_lookup '$(PRODUCT_BUNDLE_IDENTIFIER)-spki' "$downloader_count"

configured_sparkle_version="$(sparkle_exact_version)"
if [[ "$configured_sparkle_version" != "$EXPECTED_SPARKLE_VERSION" ]]; then
    add_violation "project.yml does not pin Sparkle to exactVersion $EXPECTED_SPARKLE_VERSION."
fi

echo "# Sparkle Configuration Verification"
echo
echo "| Field | Status |"
echo "|---|---|"
echo "| V1.0.2 version and build | \`$(plist_value "$INFO_PLIST" "CFBundleShortVersionString") ($(plist_value "$INFO_PLIST" "CFBundleVersion"))\` |"
echo "| Fixed HTTPS feed | \`$([[ "$(plist_value "$INFO_PLIST" "SUFeedURL")" == "$EXPECTED_FEED_URL" ]] && echo configured || echo missing-or-invalid)\` |"
echo "| Automatic checks | \`$(plist_value "$INFO_PLIST" "SUEnableAutomaticChecks") ($(plist_type "$INFO_PLIST" "SUEnableAutomaticChecks"))\` |"
echo "| Installer Launcher service | \`$(plist_value "$INFO_PLIST" "SUEnableInstallerLauncherService") ($(plist_type "$INFO_PLIST" "SUEnableInstallerLauncherService"))\` |"
echo "| Downloader service | \`$(plist_value "$INFO_PLIST" "SUEnableDownloaderService") ($(plist_type "$INFO_PLIST" "SUEnableDownloaderService"))\` |"
echo "| EdDSA public key | \`$public_key_status\` |"
echo "| Main-app network client | \`$(plist_value "$ENTITLEMENTS_PLIST" "com.apple.security.network.client") ($(plist_type "$ENTITLEMENTS_PLIST" "com.apple.security.network.client"))\` |"
echo "| Main-app network server | \`$(plist_value "$ENTITLEMENTS_PLIST" "com.apple.security.network.server") ($(plist_type "$ENTITLEMENTS_PLIST" "com.apple.security.network.server"))\` |"
echo "| Required Mach exceptions | \`$coreaudio_count / $installer_count / $downloader_count\` |"
echo "| Sparkle exact version | \`$configured_sparkle_version\` |"
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
