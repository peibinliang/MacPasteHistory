#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
record_path="$REPO_ROOT/docs/release/manual-qa-record.md"
allow_adhoc=0

usage() {
    cat <<'EOF'
Usage: scripts/validate-manual-qa-record.sh [options] [record.md]

Validate that a manual Release QA record is filled before final approval.

Options:
  --allow-adhoc   Allow ad-hoc or missing Team ID values for internal QA.
  -h, --help      Show this help.
EOF
}

add_blocker() {
    blockers+=("$1")
}

require_section() {
    local section_name="$1"
    if ! grep -q "^## $section_name$" "$record_path"; then
        add_blocker "Missing required section: $section_name"
    fi
}

require_workflow_row() {
    local scenario_name="$1"
    if ! grep -qE "^\\|[[:space:]]*$scenario_name[[:space:]]*\\|" "$record_path"; then
        add_blocker "Missing required Release App Workflow row: $scenario_name"
    fi
}

require_named_row() {
    local group_name="$1"
    local row_name="$2"
    if ! grep -qE "^\\|[[:space:]]*$row_name[[:space:]]*\\|" "$record_path"; then
        add_blocker "Missing required $group_name row: $row_name"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --allow-adhoc)
            allow_adhoc=1
            ;;
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
            record_path="$1"
            ;;
    esac
    shift
done

if [[ ! -f "$record_path" ]]; then
    echo "Manual QA record not found: $record_path" >&2
    exit 1
fi

blockers=()
required_sections=(
    "Build Under Test"
    "Environment Coverage"
    "Release App Workflow"
    "Common App Copy Matrix"
    "Privacy And Safety Checks"
    "Decision"
)

required_workflow_rows=(
    "First launch"
    "Open history"
    "Quit and relaunch"
    "Restart persistence"
    "Restore text"
    "Double-click paste"
    "Restore image"
    "Clear all data"
    "Launch at login"
)

required_environment_rows=(
    "Apple Silicon"
    "Intel Mac"
    "macOS 14.x"
    "macOS 15.x"
    "Current macOS"
)

required_common_app_rows=(
    "Google Chrome"
    "Safari"
    "VS Code"
    "WeChat"
    "DingTalk"
)

required_privacy_rows=(
    "Pause recording"
    "Sensitive text"
    "Blocked app"
    "Logs"
    "Local storage"
)

for section_name in "${required_sections[@]}"; do
    require_section "$section_name"
done

for scenario_name in "${required_workflow_rows[@]}"; do
    require_workflow_row "$scenario_name"
done

for row_name in "${required_environment_rows[@]}"; do
    require_named_row "Environment Coverage" "$row_name"
done

for row_name in "${required_common_app_rows[@]}"; do
    require_named_row "Common App Copy Matrix" "$row_name"
done

for row_name in "${required_privacy_rows[@]}"; do
    require_named_row "Privacy And Safety Checks" "$row_name"
done

placeholder_lines="$(grep -nE '^\|.*TBD|^\|.*Not run' "$record_path" || true)"
if [[ -n "$placeholder_lines" ]]; then
    add_blocker "Record still contains TBD or Not run placeholders."
fi

if grep -qE 'Ready for distribution\?[[:space:]]*\|[[:space:]]*.*No' "$record_path"; then
    add_blocker "Decision still says the release is not ready for distribution."
fi

if [[ "$allow_adhoc" -eq 0 ]]; then
    unsigned_lines="$(grep -nEi 'Signing identity[[:space:]]*\|[[:space:]]*(adhoc|not set|none)|Signature[[:space:]]*[=:][[:space:]]*adhoc|Team identifier[[:space:]]*[=:|][[:space:]]*not set' "$record_path" || true)"
    if [[ -n "$unsigned_lines" ]]; then
        add_blocker "Record contains ad-hoc signing or missing Team ID values. Use --allow-adhoc only for internal QA."
    fi
else
    unsigned_lines=""
fi

echo "# Manual QA Record Validation"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Record | \`$record_path\` |"
echo "| Required sections | \`${#required_sections[@]}\` |"
echo "| Required workflow rows | \`${#required_workflow_rows[@]}\` |"
echo "| Required environment rows | \`${#required_environment_rows[@]}\` |"
echo "| Required common app rows | \`${#required_common_app_rows[@]}\` |"
echo "| Required privacy rows | \`${#required_privacy_rows[@]}\` |"
echo "| TBD / Not run lines | \`$(printf "%s\n" "$placeholder_lines" | sed '/^$/d' | wc -l | tr -d ' ')\` |"
echo "| Ad-hoc allowed | \`$([[ "$allow_adhoc" -eq 1 ]] && printf "yes" || printf "no")\` |"
echo

if [[ "${#blockers[@]}" -eq 0 ]]; then
    echo "Status: PASS"
    echo
    echo "The manual QA record has no obvious placeholders or final-approval blockers."
    exit 0
fi

echo "Status: FAIL"
echo
echo "## Blockers"
echo
for blocker in "${blockers[@]}"; do
    echo "- $blocker"
done

if [[ -n "$placeholder_lines" ]]; then
    echo
    echo "## Placeholder Lines"
    echo
    printf "%s\n" "$placeholder_lines" | sed 's/^/- /'
fi

if [[ -n "${unsigned_lines:-}" ]]; then
    echo
    echo "## Signing Lines"
    echo
    printf "%s\n" "$unsigned_lines" | sed 's/^/- /'
fi

exit 1
