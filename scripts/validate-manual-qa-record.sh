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

require_named_row() {
    local group_name="$1"
    local row_name="$2"
    local section_text
    section_text="$(
        awk -v section="$group_name" '
            $0 == "## " section { in_section = 1; next }
            in_section && /^## / { exit }
            in_section { print }
        ' "$record_path"
    )"
    if ! printf "%s\n" "$section_text" | grep -qE "^\\|[[:space:]]*$row_name[[:space:]]*\\|"; then
        add_blocker "Missing required $group_name row: $row_name"
    fi
}

require_build_field() {
    local field_name="$1"
    local section_text
    section_text="$(
        awk '
            $0 == "## Build Under Test" { in_section = 1; next }
            in_section && /^## / { exit }
            in_section { print }
        ' "$record_path"
    )"
    if ! printf "%s\n" "$section_text" | grep -qE "^\\|[[:space:]]*$field_name[[:space:]]*\\|"; then
        add_blocker "Missing required Build Under Test field: $field_name"
    fi
}

build_field_value() {
    local field_name="$1"
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
    ' "$record_path"
}

markdown_table_value() {
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

summary_field_value() {
    local summary="$1"
    local field_name="$2"
    printf "%s\n" "$summary" | sed -n "s/^.*$field_name=\([^;|]*\).*$/\1/p" | awk '
        {
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", $0)
            print
            exit
        }
    '
}

normalized_path() {
    local path_value="$1"
    local path_dir
    local path_base

    if [[ -d "$path_value" ]]; then
        (cd "$path_value" && pwd -P)
    else
        path_dir="$(dirname "$path_value")"
        path_base="$(basename "$path_value")"
        if [[ -d "$path_dir" ]]; then
            printf "%s/%s" "$(cd "$path_dir" && pwd -P)" "$path_base"
        else
            printf "%s" "$path_value"
        fi
    fi
}

resolve_record_path() {
    local raw_path="$1"
    local record_dir
    record_dir="$(cd "$(dirname "$record_path")" && pwd)"

    if [[ "$raw_path" = /* ]]; then
        printf "%s" "$raw_path"
    elif [[ -e "$REPO_ROOT/$raw_path" ]]; then
        printf "%s" "$REPO_ROOT/$raw_path"
    else
        printf "%s" "$record_dir/$raw_path"
    fi
}

resolve_manifest_path() {
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
manifest_status="not checked"
package_sha_status="not checked"
package_verification_status="not checked"
fixture_status="not checked"
app_path_status="not checked"
manifest_worktree_status="not checked"
git_commit_status="not checked"
rm -f /tmp/macpastehistory-manual-record-manifest.log
rm -f /tmp/macpastehistory-manual-record-fixtures.log
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

required_build_fields=(
    "Date"
    "Tester"
    "Git commit"
    "App path"
    "Version / build"
    "Signing identity"
    "Package SHA-256"
    "Package manifest"
    "Package verification"
    "Fixture directory"
    "Notes"
)

for section_name in "${required_sections[@]}"; do
    require_section "$section_name"
done

for field_name in "${required_build_fields[@]}"; do
    require_build_field "$field_name"
done

for scenario_name in "${required_workflow_rows[@]}"; do
    require_named_row "Release App Workflow" "$scenario_name"
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

manifest_value="$(build_field_value "Package manifest")"
if [[ -z "$manifest_value" || "$manifest_value" =~ ^(TBD|TODO|PLACEHOLDER|not[[:space:]]provided)$ ]]; then
    manifest_status="missing"
else
    manifest_path="$(resolve_record_path "$manifest_value")"
    if [[ ! -s "$manifest_path" ]]; then
        manifest_status="missing"
        add_blocker "Package manifest file is missing or empty: $manifest_value"
    elif scripts/verify-release-qa-manifest.sh "$manifest_path" >/tmp/macpastehistory-manual-record-manifest.log 2>&1; then
        manifest_status="passed"
    else
        manifest_status="failed"
        add_blocker "Package manifest verification failed: $manifest_value"
    fi
fi

if [[ "$manifest_status" == "passed" ]]; then
    manifest_worktree_value="$(markdown_table_value "$manifest_path" "Git worktree")"
    if [[ "$manifest_worktree_value" == "Clean" ]]; then
        manifest_worktree_status="passed"
    else
        manifest_worktree_status="dirty"
        add_blocker "Package manifest baseline was generated from a dirty git worktree."
    fi
fi

if [[ "$manifest_status" == "passed" ]]; then
    record_git_commit="$(build_field_value "Git commit")"
    manifest_git_commit="$(markdown_table_value "$manifest_path" "Git commit")"
    if [[ -z "$record_git_commit" || "$record_git_commit" =~ ^(TBD|TODO|PLACEHOLDER|not[[:space:]]provided)$ ]]; then
        git_commit_status="missing"
        add_blocker "Git commit is missing from the record."
    elif [[ -z "$manifest_git_commit" || "$manifest_git_commit" =~ ^(TBD|TODO|PLACEHOLDER|not[[:space:]]provided)$ ]]; then
        git_commit_status="missing manifest"
        add_blocker "Package manifest does not list a Git commit."
    elif [[ "$record_git_commit" != "$manifest_git_commit" ]]; then
        git_commit_status="mismatch"
        add_blocker "Git commit does not match the package manifest."
    else
        git_commit_status="passed"
    fi
fi

if [[ "$manifest_status" == "passed" ]]; then
    app_path_value="$(build_field_value "App path")"
    packaged_app_value="$(markdown_table_value "$manifest_path" "Packaged app")"
    if [[ -z "$app_path_value" || "$app_path_value" =~ ^(TBD|TODO|PLACEHOLDER|not[[:space:]]provided)$ ]]; then
        app_path_status="missing"
        add_blocker "App path is missing from the record."
    else
        app_path="$(resolve_record_path "$app_path_value")"
        packaged_app_path="$(resolve_manifest_path "$packaged_app_value" "$(cd "$(dirname "$manifest_path")" && pwd)")"
        if [[ ! -d "$app_path" ]]; then
            app_path_status="missing"
            add_blocker "App path does not exist or is not a directory: $app_path_value"
        elif [[ "$app_path" != *.app ]]; then
            app_path_status="invalid"
            add_blocker "App path does not point to a .app bundle: $app_path_value"
        elif [[ "$(normalized_path "$app_path")" != "$(normalized_path "$packaged_app_path")" ]]; then
            app_path_status="mismatch"
            add_blocker "App path does not match the Packaged app in the manifest."
        else
            app_path_status="passed"
        fi
    fi
fi

if [[ "$manifest_status" == "passed" ]]; then
    package_sha_value="$(build_field_value "Package SHA-256" | tr '[:upper:]' '[:lower:]')"
    checksum_value="$(markdown_table_value "$manifest_path" "SHA-256 file")"
    if [[ -z "$checksum_value" || "$checksum_value" =~ ^(TBD|TODO|PLACEHOLDER|not[[:space:]]provided)$ ]]; then
        package_sha_status="missing checksum"
        add_blocker "Package manifest does not list a SHA-256 file."
    else
        checksum_path="$(resolve_manifest_path "$checksum_value" "$(cd "$(dirname "$manifest_path")" && pwd)")"
        if [[ ! -s "$checksum_path" ]]; then
            package_sha_status="missing checksum"
            add_blocker "Package SHA-256 checksum file is missing or empty: $checksum_value"
        else
            expected_package_sha="$(awk 'NF {print tolower($1); exit}' "$checksum_path")"
            if [[ -z "$package_sha_value" || -z "$expected_package_sha" ]]; then
                package_sha_status="missing"
                add_blocker "Package SHA-256 value is missing from the record or checksum file."
            elif [[ "$package_sha_value" == "$expected_package_sha" ]]; then
                package_sha_status="passed"
            else
                package_sha_status="mismatch"
                add_blocker "Package SHA-256 does not match the manifest checksum file."
            fi
        fi
    fi
fi

if [[ "$manifest_status" == "passed" ]]; then
    package_verification_value="$(build_field_value "Package verification")"
    expected_signature="$(markdown_table_value "$manifest_path" "Signature")"
    expected_team="$(markdown_table_value "$manifest_path" "Team identifier")"
    verification_signature="$(summary_field_value "$package_verification_value" "Signature")"
    verification_team="$(summary_field_value "$package_verification_value" "Team")"
    verification_sandbox="$(summary_field_value "$package_verification_value" "Sandbox")"

    if [[ -z "$package_verification_value" || "$package_verification_value" =~ ^(TBD|TODO|PLACEHOLDER|not[[:space:]]provided)$ ]]; then
        package_verification_status="missing"
        add_blocker "Package verification summary is missing from the record."
    elif ! printf "%s\n" "$package_verification_value" | grep -q ": OK"; then
        package_verification_status="failed"
        add_blocker "Package verification summary does not include a successful checksum result."
    elif [[ -z "$verification_signature" || "$verification_signature" != "$expected_signature" ]]; then
        package_verification_status="mismatch"
        add_blocker "Package verification signature does not match the manifest."
    elif [[ -z "$verification_team" || "$verification_team" != "$expected_team" ]]; then
        package_verification_status="mismatch"
        add_blocker "Package verification Team value does not match the manifest."
    elif [[ "$verification_sandbox" != "present" ]]; then
        package_verification_status="mismatch"
        add_blocker "Package verification Sandbox value is not present."
    else
        package_verification_status="passed"
    fi
fi

fixture_value="$(build_field_value "Fixture directory")"
if [[ -z "$fixture_value" || "$fixture_value" =~ ^(TBD|TODO|PLACEHOLDER|not[[:space:]]provided)$ ]]; then
    fixture_status="missing"
    add_blocker "Fixture directory is missing from the record."
else
    fixture_path="$(resolve_record_path "$fixture_value")"
    if [[ ! -d "$fixture_path" ]]; then
        fixture_status="missing"
        add_blocker "Fixture directory does not exist: $fixture_value"
    elif scripts/verify-manual-qa-fixtures.sh --fixture-dir "$fixture_path" >/tmp/macpastehistory-manual-record-fixtures.log 2>&1; then
        fixture_status="passed"
    else
        fixture_status="failed"
        add_blocker "Fixture directory verification failed: $fixture_value"
    fi
fi

echo "# Manual QA Record Validation"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Record | \`$record_path\` |"
echo "| Required sections | \`${#required_sections[@]}\` |"
echo "| Required build fields | \`${#required_build_fields[@]}\` |"
echo "| Required workflow rows | \`${#required_workflow_rows[@]}\` |"
echo "| Required environment rows | \`${#required_environment_rows[@]}\` |"
echo "| Required common app rows | \`${#required_common_app_rows[@]}\` |"
echo "| Required privacy rows | \`${#required_privacy_rows[@]}\` |"
echo "| TBD / Not run lines | \`$(printf "%s\n" "$placeholder_lines" | sed '/^$/d' | wc -l | tr -d ' ')\` |"
echo "| Package manifest verification | \`$manifest_status\` |"
echo "| Package manifest worktree | \`$manifest_worktree_status\` |"
echo "| Git commit match | \`$git_commit_status\` |"
echo "| App path verification | \`$app_path_status\` |"
echo "| Package SHA-256 match | \`$package_sha_status\` |"
echo "| Package verification summary | \`$package_verification_status\` |"
echo "| Fixture directory verification | \`$fixture_status\` |"
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

if [[ -s /tmp/macpastehistory-manual-record-manifest.log ]]; then
    echo
    echo "## Package Manifest Output"
    echo
    echo '```text'
    cat /tmp/macpastehistory-manual-record-manifest.log
    echo '```'
fi

if [[ -s /tmp/macpastehistory-manual-record-fixtures.log ]]; then
    echo
    echo "## Fixture Verification Output"
    echo
    echo '```text'
    cat /tmp/macpastehistory-manual-record-fixtures.log
    echo '```'
fi

exit 1
