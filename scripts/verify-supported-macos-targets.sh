#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_YML="$REPO_ROOT/project.yml"
INFO_PLIST="$REPO_ROOT/MacPasteHistory/Resources/Info.plist"
RELEASE_GUIDE="$REPO_ROOT/docs/release/RELEASE_PREP_GUIDE.md"
MANUAL_QA_RECORD="$REPO_ROOT/docs/release/manual-qa-record.md"
EXPECTED_MINIMUM_MACOS="14.0"

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

add_violation() {
    violations+=("$1")
}

read_plist_value() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

extract_project_deployment_target() {
    awk '
        /^[[:space:]]*deploymentTarget:/ { in_deployment = 1; next }
        in_deployment && /^[[:space:]]*macOS:/ {
            value = $2
            gsub(/"/, "", value)
            print value
            exit
        }
        in_deployment && /^[^[:space:]]/ { exit }
    ' "$PROJECT_YML"
}

require_command awk
require_command grep

violations=()

project_deployment_target="$(extract_project_deployment_target)"
build_setting_target="$(awk '/MACOSX_DEPLOYMENT_TARGET:/ {value = $2; gsub(/"/, "", value); print value; exit}' "$PROJECT_YML")"
plist_minimum_system="$(read_plist_value LSMinimumSystemVersion)"

if [[ "$project_deployment_target" != "$EXPECTED_MINIMUM_MACOS" ]]; then
    add_violation "project.yml deploymentTarget.macOS is '$project_deployment_target', expected '$EXPECTED_MINIMUM_MACOS'."
fi

if [[ "$build_setting_target" != "$EXPECTED_MINIMUM_MACOS" ]]; then
    add_violation "project.yml MACOSX_DEPLOYMENT_TARGET is '$build_setting_target', expected '$EXPECTED_MINIMUM_MACOS'."
fi

if [[ "$plist_minimum_system" != "$EXPECTED_MINIMUM_MACOS" ]]; then
    add_violation "Info.plist LSMinimumSystemVersion is '$plist_minimum_system', expected '$EXPECTED_MINIMUM_MACOS'."
fi

if ! grep -q "macOS 14.0+" "$RELEASE_GUIDE"; then
    add_violation "Release guide does not state the macOS 14.0+ support target."
fi

for required_row in "macOS 14.x" "macOS 15.x" "Current macOS"; do
    if ! grep -qE "^\\|[[:space:]]*$required_row[[:space:]]*\\|" "$MANUAL_QA_RECORD"; then
        add_violation "Manual QA record is missing the '$required_row' environment coverage row."
    fi
done

echo "# Supported macOS Target Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Expected minimum macOS | \`$EXPECTED_MINIMUM_MACOS\` |"
echo "| project.yml deploymentTarget.macOS | \`$project_deployment_target\` |"
echo "| project.yml MACOSX_DEPLOYMENT_TARGET | \`$build_setting_target\` |"
echo "| Info.plist LSMinimumSystemVersion | \`$plist_minimum_system\` |"
echo "| Release guide support target | \`$(grep -c "macOS 14.0+" "$RELEASE_GUIDE" | tr -d ' ')\` matches |"
echo "| Manual QA macOS coverage rows | \`3\` required |"
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
