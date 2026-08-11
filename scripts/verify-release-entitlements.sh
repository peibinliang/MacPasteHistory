#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_YML="$REPO_ROOT/project.yml"
ENTITLEMENTS_PLIST="$REPO_ROOT/MacPasteHistory/MacPasteHistory.entitlements"
EXPECTED_ENTITLEMENTS="MacPasteHistory/MacPasteHistory.entitlements"

add_violation() {
    violations+=("$1")
}

plist_value() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :$key" "$ENTITLEMENTS_PLIST" 2>/dev/null || true
}

plist_type() {
    local key="$1"
    local escaped_key="${key//./\\.}"
    /usr/bin/plutil -type "$escaped_key" "$ENTITLEMENTS_PLIST" 2>/dev/null || true
}

require_boolean() {
    local key="$1"
    local expected="$2"
    local type
    local value
    type="$(plist_type "$key")"
    value="$(plist_value "$key")"
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

require_true() {
    local key="$1"
    local value
    value="$(plist_value "$key")"
    if [[ "$value" != "true" ]]; then
        add_violation "$key is '$value', expected 'true'."
    fi
}

violations=()

if [[ ! -f "$ENTITLEMENTS_PLIST" ]]; then
    add_violation "Entitlements file is missing: $ENTITLEMENTS_PLIST"
fi

configured_entitlements="$(awk -F ': ' '/CODE_SIGN_ENTITLEMENTS:/ {print $2; exit}' "$PROJECT_YML" | tr -d '"')"
if [[ "$configured_entitlements" != "$EXPECTED_ENTITLEMENTS" ]]; then
    add_violation "project.yml CODE_SIGN_ENTITLEMENTS is '$configured_entitlements', expected '$EXPECTED_ENTITLEMENTS'."
fi

app_sandbox="$(plist_value "com.apple.security.app-sandbox")"
require_boolean "com.apple.security.app-sandbox" "true"
require_boolean "com.apple.security.network.client" "true"
require_boolean "com.apple.security.network.server" "false"
require_boolean "com.apple.security.files.user-selected.read-write" "false"
require_boolean "com.apple.security.device.usb" "false"

coreaudio_mach_count="$(mach_lookup_count "com.apple.coreaudio")"
installer_mach_count="$(mach_lookup_count '$(PRODUCT_BUNDLE_IDENTIFIER)-spks')"
downloader_mach_count="$(mach_lookup_count '$(PRODUCT_BUNDLE_IDENTIFIER)-spki')"

require_single_mach_lookup "com.apple.coreaudio" "$coreaudio_mach_count"
require_single_mach_lookup '$(PRODUCT_BUNDLE_IDENTIFIER)-spks' "$installer_mach_count"
require_single_mach_lookup '$(PRODUCT_BUNDLE_IDENTIFIER)-spki' "$downloader_mach_count"

echo "# Release Entitlements Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Expected entitlements path | \`$EXPECTED_ENTITLEMENTS\` |"
echo "| project.yml CODE_SIGN_ENTITLEMENTS | \`$configured_entitlements\` |"
echo "| Entitlements file | \`$ENTITLEMENTS_PLIST\` |"
echo "| App Sandbox | \`$app_sandbox ($(plist_type "com.apple.security.app-sandbox"))\` |"
echo "| Network client | \`$(plist_value "com.apple.security.network.client") ($(plist_type "com.apple.security.network.client"))\` |"
echo "| Network server | \`$(plist_value "com.apple.security.network.server") ($(plist_type "com.apple.security.network.server"))\` |"
echo "| User-selected read/write files | \`$(plist_value "com.apple.security.files.user-selected.read-write") ($(plist_type "com.apple.security.files.user-selected.read-write"))\` |"
echo "| USB entitlement | \`$(plist_value "com.apple.security.device.usb") ($(plist_type "com.apple.security.device.usb"))\` |"
echo "| CoreAudio mach exception entries | \`$coreaudio_mach_count\` |"
echo "| Sparkle Installer Launcher mach exception entries | \`$installer_mach_count\` |"
echo "| Sparkle Downloader mach exception entries | \`$downloader_mach_count\` |"
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
