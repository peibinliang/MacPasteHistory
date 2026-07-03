#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$REPO_ROOT/MacPasteHistory/Resources/Info.plist"

usage() {
    cat <<'EOF'
Usage: scripts/verify-privacy-usage-descriptions.sh

Verify that Info.plist includes non-placeholder privacy usage descriptions
required by clipboard and accessibility-related release workflows.
EOF
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

plist_value() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

add_violation() {
    violations+=("$1")
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

require_command grep
require_command sed

if [[ ! -f "$INFO_PLIST" ]]; then
    echo "Info.plist not found: $INFO_PLIST" >&2
    exit 1
fi

violations=()
required_keys=(
    "NSPasteboardAccessUsageDescription"
    "NSAccessibilityUsageDescription"
)

for key in "${required_keys[@]}"; do
    value="$(plist_value "$key")"
    trimmed="$(printf "%s" "$value" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
    if [[ -z "$trimmed" ]]; then
        add_violation "Missing or empty $key."
        continue
    fi
    if printf "%s" "$trimmed" | grep -qiE '^(todo|tbd|placeholder|fixme)$|TODO|TBD|PLACEHOLDER|FIXME'; then
        add_violation "$key contains placeholder text."
    fi
done

pasteboard_description="$(plist_value NSPasteboardAccessUsageDescription)"
accessibility_description="$(plist_value NSAccessibilityUsageDescription)"

if ! printf "%s" "$pasteboard_description" | grep -qiE 'pasteboard|clipboard|copy|paste'; then
    add_violation "NSPasteboardAccessUsageDescription should explain clipboard or pasteboard access."
fi

if ! printf "%s" "$accessibility_description" | grep -qiE 'accessibility|foreground|frontmost|paste'; then
    add_violation "NSAccessibilityUsageDescription should explain accessibility access."
fi

echo "# Privacy Usage Description Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Info.plist | \`$INFO_PLIST\` |"
echo "| Required descriptions | \`${#required_keys[@]}\` |"
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
