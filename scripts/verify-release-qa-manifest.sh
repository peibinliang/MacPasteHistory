#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest_path=""

required_fields=(
    "Git commit"
    "Version / build"
    "Source app"
    "Packaged app"
    "Zip"
    "SHA-256 file"
    "Architectures"
    "Signature"
    "Team identifier"
)

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-qa-manifest.sh <manifest.md>

Verify that a Release QA package manifest contains package metadata, points to
existing package artifacts, has a valid SHA-256 file, and embeds a valid Release
QA baseline.

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

resolve_path() {
    local raw_path="$1"
    local manifest_dir="$2"

    if [[ "$raw_path" = /* ]]; then
        printf "%s" "$raw_path"
    elif [[ -e "$REPO_ROOT/$raw_path" ]]; then
        printf "%s" "$REPO_ROOT/$raw_path"
    else
        printf "%s" "$manifest_dir/$raw_path"
    fi
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
            if [[ -n "$manifest_path" ]]; then
                echo "Only one manifest may be provided" >&2
                exit 2
            fi
            manifest_path="$1"
            ;;
    esac
    shift
done

if [[ -z "$manifest_path" ]]; then
    usage >&2
    exit 2
fi

violations=()
rm -f /tmp/macpastehistory-manifest-checksum.log /tmp/macpastehistory-manifest-baseline.log

if [[ ! -s "$manifest_path" ]]; then
    echo "# Release QA Manifest Verification"
    echo
    echo "Status: FAIL"
    echo
    echo "## Violations"
    echo
    echo "- Manifest file is missing or empty: $manifest_path"
    exit 1
fi

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

require_command awk
require_command grep
require_command mktemp
require_command shasum

manifest_dir="$(cd "$(dirname "$manifest_path")" && pwd)"

if ! grep -qxF "# Release QA Package" "$manifest_path"; then
    add_violation "Manifest header is missing: # Release QA Package"
fi
if ! grep -qxF "## Baseline" "$manifest_path"; then
    add_violation "Manifest is missing embedded baseline section."
fi

for field in "${required_fields[@]}"; do
    value="$(table_value "$manifest_path" "$field")"
    if [[ -z "$value" ]]; then
        add_violation "Missing required field: $field"
    elif [[ "$value" =~ ^(unknown|TBD|TODO|PLACEHOLDER)$ ]]; then
        add_violation "Field contains placeholder value: $field=$value"
    fi
done

packaged_app="$(table_value "$manifest_path" "Packaged app")"
zip_path="$(table_value "$manifest_path" "Zip")"
checksum_path="$(table_value "$manifest_path" "SHA-256 file")"
architectures="$(table_value "$manifest_path" "Architectures")"
version_build="$(table_value "$manifest_path" "Version / build")"

packaged_app_resolved=""
zip_resolved=""
checksum_resolved=""
if [[ -n "$packaged_app" ]]; then
    packaged_app_resolved="$(resolve_path "$packaged_app" "$manifest_dir")"
fi
if [[ -n "$zip_path" ]]; then
    zip_resolved="$(resolve_path "$zip_path" "$manifest_dir")"
fi
if [[ -n "$checksum_path" ]]; then
    checksum_resolved="$(resolve_path "$checksum_path" "$manifest_dir")"
fi

[[ -n "$packaged_app_resolved" && -d "$packaged_app_resolved" ]] || add_violation "Packaged app does not exist: $packaged_app"
[[ -n "$zip_resolved" && -s "$zip_resolved" ]] || add_violation "Zip does not exist or is empty: $zip_path"
[[ -n "$checksum_resolved" && -s "$checksum_resolved" ]] || add_violation "SHA-256 file does not exist or is empty: $checksum_path"

if [[ -n "$checksum_resolved" && -s "$checksum_resolved" ]]; then
    checksum_dir="$(cd "$(dirname "$checksum_resolved")" && pwd)"
    checksum_file="$(basename "$checksum_resolved")"
    if ! (cd "$checksum_dir" && shasum -a 256 -c "$checksum_file" >/tmp/macpastehistory-manifest-checksum.log 2>&1); then
        add_violation "Manifest SHA-256 verification failed."
    fi
fi

if [[ ! "$architectures" =~ arm64 ]]; then
    add_violation "Architectures should include arm64."
fi
if [[ ! "$version_build" =~ ^[0-9]+\.[0-9]+\.[0-9]+[[:space:]]\([0-9]+\)$ ]]; then
    add_violation "Version / build does not look like 'x.y.z (n)': $version_build"
fi

baseline_tmp="$(mktemp "${TMPDIR:-/tmp}/macpastehistory-manifest-baseline.XXXXXX")"
awk 'found { print } /^# Release QA Baseline$/ { found=1; print }' "$manifest_path" >"$baseline_tmp"

baseline_status="not checked"
if [[ -s "$baseline_tmp" ]]; then
    if scripts/verify-release-qa-baseline.sh "$baseline_tmp" >/tmp/macpastehistory-manifest-baseline.log 2>&1; then
        baseline_status="passed"
    else
        baseline_status="failed"
        add_violation "Embedded Release QA baseline verification failed."
    fi
else
    add_violation "Embedded Release QA baseline content is missing."
fi

rm -f "$baseline_tmp"

echo "# Release QA Manifest Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Manifest | \`$manifest_path\` |"
echo "| Packaged app | \`$packaged_app\` |"
echo "| Zip | \`$zip_path\` |"
echo "| SHA-256 file | \`$checksum_path\` |"
echo "| Embedded baseline verification | \`$baseline_status\` |"
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

if [[ -s /tmp/macpastehistory-manifest-checksum.log ]]; then
    echo
    echo "## Checksum Output"
    echo
    echo '```text'
    cat /tmp/macpastehistory-manifest-checksum.log
    echo '```'
fi

if [[ -s /tmp/macpastehistory-manifest-baseline.log ]]; then
    echo
    echo "## Baseline Output"
    echo
    echo '```text'
    cat /tmp/macpastehistory-manifest-baseline.log
    echo '```'
fi

exit 1
