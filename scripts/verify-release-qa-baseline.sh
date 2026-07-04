#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
baseline_path="$REPO_ROOT/build/manual-release-qa-session/latest/release-qa-baseline.md"

required_sections=(
    "## Build Under Test"
    "## Machine And Toolchain"
    "## Signing And Sandbox"
    "## Common App Availability"
    "## Manual Evidence Still Required"
)
required_fields=(
    "Git commit"
    "Git worktree"
    "App path"
    "Version / build"
    "Bundle identifier"
    "Architecture"
    "CPU"
    "macOS"
    "Xcode developer directory"
    "Xcode version"
    "Xcode first launch"
    "Xcode license"
    "Available local code signing identities"
    "App signature"
    "Authority"
    "Team identifier"
    "App Sandbox entitlement"
    "Distribution signing status"
)
required_apps=(
    "Google Chrome"
    "Safari"
    "VS Code"
    "WeChat"
    "DingTalk"
)

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-qa-baseline.sh [baseline.md]

Verify that a Release QA baseline contains the objective build, machine,
toolchain, signing, Sandbox, common-app, and remaining-manual-evidence fields
needed before manual QA starts.

Options:
  -h, --help  Show this help.
EOF
}

add_violation() {
    violations+=("$1")
}

table_value() {
    local file_path="$1"
    local field_name="$2"
    awk -F'|' -v field="$field_name" '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            gsub(/^`|`$/, "", value)
            return value
        }
        $2 {
            key = trim($2)
            if (key == field) {
                print trim($3)
                exit
            }
        }
    ' "$file_path"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            baseline_path="$1"
            ;;
    esac
    shift
done

violations=()

if [[ ! -s "$baseline_path" ]]; then
    echo "# Release QA Baseline Verification"
    echo
    echo "Status: FAIL"
    echo
    echo "## Violations"
    echo
    echo "- Baseline file is missing or empty: $baseline_path"
    exit 1
fi

for section in "${required_sections[@]}"; do
    if ! grep -qxF "$section" "$baseline_path"; then
        add_violation "Missing required section: $section"
    fi
done

for field in "${required_fields[@]}"; do
    value="$(table_value "$baseline_path" "$field")"
    if [[ -z "$value" ]]; then
        add_violation "Missing required field: $field"
    elif [[ "$value" =~ ^(unknown|TBD|TODO|PLACEHOLDER)$ ]]; then
        add_violation "Field contains placeholder value: $field=$value"
    fi
done

for app_name in "${required_apps[@]}"; do
    if ! awk -F'|' -v app="$app_name" '
        function trim(value) {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
            return value
        }
        $2 && trim($2) == app { found=1 }
        END { exit found ? 0 : 1 }
    ' "$baseline_path"; then
        add_violation "Missing common-app availability row: $app_name"
    fi
done

sandbox_status="$(table_value "$baseline_path" "App Sandbox entitlement")"
if [[ "$sandbox_status" != "present" ]]; then
    add_violation "App Sandbox entitlement must be present in the baseline."
fi

bundle_identifier="$(table_value "$baseline_path" "Bundle identifier")"
if [[ "$bundle_identifier" != "com.peibin.MacPasteHistory" ]]; then
    add_violation "Bundle identifier is not com.peibin.MacPasteHistory."
fi

version_build="$(table_value "$baseline_path" "Version / build")"
if [[ ! "$version_build" =~ ^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]\([0-9]+\)$ ]]; then
    add_violation "Version / build does not look like 'x.y.z (n)': $version_build"
fi

echo "# Release QA Baseline Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Baseline | \`$baseline_path\` |"
echo "| Required sections | \`${#required_sections[@]}\` |"
echo "| Required fields | \`${#required_fields[@]}\` |"
echo "| Required common apps | \`${#required_apps[@]}\` |"
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
