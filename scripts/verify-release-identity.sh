#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_YML="$REPO_ROOT/project.yml"
INFO_PLIST="$REPO_ROOT/MacPasteHistory/Resources/Info.plist"

EXPECTED_BUNDLE_ID="com.peibin.MacPasteHistory"
EXPECTED_PRODUCT_NAME="MacPasteHistory"
EXPECTED_INFOPLIST="MacPasteHistory/Resources/Info.plist"

add_violation() {
    violations+=("$1")
}

project_value() {
    local key="$1"
    awk -F ': ' -v key="$key" '$1 ~ key {print $2; exit}' "$PROJECT_YML" | tr -d '"'
}

plist_value() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

violations=()

project_bundle_id="$(project_value "PRODUCT_BUNDLE_IDENTIFIER")"
project_product_name="$(project_value "PRODUCT_NAME")"
project_infoplist="$(project_value "INFOPLIST_FILE")"
generate_infoplist="$(project_value "GENERATE_INFOPLIST_FILE")"

plist_bundle_id="$(plist_value CFBundleIdentifier)"
plist_name="$(plist_value CFBundleName)"
plist_display_name="$(plist_value CFBundleDisplayName)"
plist_package_type="$(plist_value CFBundlePackageType)"
lsui_element="$(plist_value LSUIElement)"

if [[ "$project_bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
    add_violation "project.yml PRODUCT_BUNDLE_IDENTIFIER is '$project_bundle_id', expected '$EXPECTED_BUNDLE_ID'."
fi

if [[ "$project_product_name" != "$EXPECTED_PRODUCT_NAME" ]]; then
    add_violation "project.yml PRODUCT_NAME is '$project_product_name', expected '$EXPECTED_PRODUCT_NAME'."
fi

if [[ "$project_infoplist" != "$EXPECTED_INFOPLIST" ]]; then
    add_violation "project.yml INFOPLIST_FILE is '$project_infoplist', expected '$EXPECTED_INFOPLIST'."
fi

if [[ "$generate_infoplist" != "NO" ]]; then
    add_violation "project.yml GENERATE_INFOPLIST_FILE is '$generate_infoplist', expected 'NO'."
fi

if [[ "$plist_bundle_id" != '$(PRODUCT_BUNDLE_IDENTIFIER)' ]]; then
    add_violation "Info.plist CFBundleIdentifier is '$plist_bundle_id', expected '\$(PRODUCT_BUNDLE_IDENTIFIER)'."
fi

if [[ "$plist_name" != '$(PRODUCT_NAME)' ]]; then
    add_violation "Info.plist CFBundleName is '$plist_name', expected '\$(PRODUCT_NAME)'."
fi

if [[ "$plist_display_name" != "$EXPECTED_PRODUCT_NAME" ]]; then
    add_violation "Info.plist CFBundleDisplayName is '$plist_display_name', expected '$EXPECTED_PRODUCT_NAME'."
fi

if [[ "$plist_package_type" != "APPL" ]]; then
    add_violation "Info.plist CFBundlePackageType is '$plist_package_type', expected 'APPL'."
fi

if [[ "$lsui_element" != "true" ]]; then
    add_violation "Info.plist LSUIElement is '$lsui_element', expected 'true' for a menu bar app."
fi

echo "# Release Identity Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Expected bundle identifier | \`$EXPECTED_BUNDLE_ID\` |"
echo "| project.yml PRODUCT_BUNDLE_IDENTIFIER | \`$project_bundle_id\` |"
echo "| project.yml PRODUCT_NAME | \`$project_product_name\` |"
echo "| project.yml INFOPLIST_FILE | \`$project_infoplist\` |"
echo "| project.yml GENERATE_INFOPLIST_FILE | \`$generate_infoplist\` |"
echo "| Info.plist CFBundleIdentifier | \`$plist_bundle_id\` |"
echo "| Info.plist CFBundleName | \`$plist_name\` |"
echo "| Info.plist CFBundleDisplayName | \`$plist_display_name\` |"
echo "| Info.plist CFBundlePackageType | \`$plist_package_type\` |"
echo "| Info.plist LSUIElement | \`$lsui_element\` |"
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
