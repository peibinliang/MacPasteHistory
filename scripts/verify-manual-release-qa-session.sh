#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_SESSION_ROOT="$REPO_ROOT/build/manual-release-qa-session"
session_dir=""

usage() {
    cat <<'EOF'
Usage: scripts/verify-manual-release-qa-session.sh [options] [session-dir]

Verify that a generated manual Release QA session directory contains the
package, checksum, manifest, package verification, baseline, fixtures, manual
record copy, and README needed before manual testing starts.

Options:
  -h, --help  Show this help.
EOF
}

add_violation() {
    violations+=("$1")
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

newest_session_dir() {
    find "$DEFAULT_SESSION_ROOT" -mindepth 1 -maxdepth 1 -type d -print 2>/dev/null | sort | tail -n 1 || true
}

newest_matching_file() {
    local directory="$1"
    local pattern="$2"
    find "$directory" -maxdepth 1 -type f -name "$pattern" -print 2>/dev/null | sort | tail -n 1 || true
}

newest_matching_directory() {
    local directory="$1"
    local pattern="$2"
    find "$directory" -maxdepth 1 -type d -name "$pattern" -print 2>/dev/null | sort | tail -n 1 || true
}

require_nonempty_file() {
    local path="$1"
    local label="$2"
    if [[ ! -s "$path" ]]; then
        add_violation "$label is missing or empty: $path"
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
            if [[ -n "$session_dir" ]]; then
                echo "Only one session directory may be provided" >&2
                exit 2
            fi
            session_dir="$1"
            ;;
    esac
    shift
done

require_command find
require_command grep
require_command shasum

cd "$REPO_ROOT"

if [[ -z "$session_dir" ]]; then
    session_dir="$(newest_session_dir)"
fi

violations=()

if [[ -z "$session_dir" || ! -d "$session_dir" ]]; then
    echo "# Manual Release QA Session Verification"
    echo
    echo "Status: FAIL"
    echo
    echo "## Violations"
    echo
    echo "- Session directory not found. Run scripts/start-manual-release-qa-session.sh first or pass a session directory."
    exit 1
fi

package_dir="$session_dir/package"
fixture_dir="$session_dir/fixtures"
verification_path="$session_dir/package-verification.md"
baseline_path="$session_dir/release-qa-baseline.md"
fixture_log_path="$session_dir/fixture-generation.log"
manual_record_path="$session_dir/manual-qa-record.md"
readme_path="$session_dir/README.md"
session_verification_path="$session_dir/session-verification.md"

zip_path="$(newest_matching_file "$package_dir" "MacPasteHistory-*.zip")"
checksum_path="$zip_path.sha256"
manifest_path="$(newest_matching_file "$package_dir" "MacPasteHistory-*-manifest.md")"
package_app_path="$(newest_matching_directory "$package_dir" "MacPasteHistory-*.app")"

[[ -d "$package_dir" ]] || add_violation "Package directory is missing: $package_dir"
[[ -d "$fixture_dir" ]] || add_violation "Fixture directory is missing: $fixture_dir"
[[ -d "$package_app_path" ]] || add_violation "Packaged app is missing in $package_dir."

require_nonempty_file "$zip_path" "QA zip"
require_nonempty_file "$checksum_path" "SHA-256 checksum"
require_nonempty_file "$manifest_path" "Package manifest"
require_nonempty_file "$verification_path" "Package verification"
require_nonempty_file "$baseline_path" "Release QA baseline"
require_nonempty_file "$fixture_log_path" "Fixture generation log"
require_nonempty_file "$manual_record_path" "Manual QA record copy"
require_nonempty_file "$readme_path" "Session README"

checksum_status="not checked"
if [[ -s "$checksum_path" ]]; then
    checksum_dir="$(cd "$(dirname "$checksum_path")" && pwd)"
    checksum_file="$(basename "$checksum_path")"
    if (cd "$checksum_dir" && shasum -a 256 -c "$checksum_file" >/tmp/macpastehistory-session-checksum.log 2>&1); then
        checksum_status="passed"
    else
        checksum_status="failed"
        add_violation "QA zip SHA-256 verification failed."
    fi
fi

baseline_status="not checked"
if [[ -s "$baseline_path" ]]; then
    if scripts/verify-release-qa-baseline.sh "$baseline_path" >/tmp/macpastehistory-session-baseline.log 2>&1; then
        baseline_status="passed"
    else
        baseline_status="failed"
        add_violation "Release QA baseline verification failed."
    fi
fi

fixture_status="not checked"
if [[ -d "$fixture_dir" ]]; then
    if scripts/verify-manual-qa-fixtures.sh --fixture-dir "$fixture_dir" >/tmp/macpastehistory-session-fixtures.log 2>&1; then
        fixture_status="passed"
    else
        fixture_status="failed"
        add_violation "Manual QA fixture verification failed."
    fi
fi

if [[ -s "$verification_path" ]] && ! grep -q "# Release QA Package Verification" "$verification_path"; then
    add_violation "Package verification report does not look like scripts/verify-release-qa-package.sh output."
fi

if [[ -s "$baseline_path" ]] && ! grep -q "# Release QA Baseline" "$baseline_path"; then
    add_violation "Release QA baseline does not look like scripts/release-qa-baseline.sh output."
fi

if [[ -s "$manual_record_path" ]]; then
    if ! grep -q "Session prefilled" "$manual_record_path"; then
        add_violation "Manual QA record copy does not include the session prefill note."
    fi
    if ! grep -q "Not run" "$manual_record_path"; then
        add_violation "Manual QA record copy should keep manual scenarios as Not run before tester evidence is entered."
    fi
fi

if [[ -s "$readme_path" ]] && ! grep -q "Manual Release QA Session" "$readme_path"; then
    add_violation "Session README does not look like the generated guide."
fi

echo "# Manual Release QA Session Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Session directory | \`$session_dir\` |"
echo "| Packaged app | \`${package_app_path:-missing}\` |"
echo "| QA zip | \`${zip_path:-missing}\` |"
echo "| SHA-256 file | \`${checksum_path:-missing}\` |"
echo "| Package manifest | \`${manifest_path:-missing}\` |"
echo "| Package verification | \`$verification_path\` |"
echo "| Release baseline | \`$baseline_path\` |"
echo "| Release baseline verification | \`$baseline_status\` |"
echo "| Fixture directory | \`$fixture_dir\` |"
echo "| Fixture verification | \`$fixture_status\` |"
echo "| Checksum verification | \`$checksum_status\` |"
echo "| Manual QA record copy | \`$manual_record_path\` |"
echo "| Session README | \`$readme_path\` |"
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

if [[ -s /tmp/macpastehistory-session-checksum.log ]]; then
    echo
    echo "## Checksum Output"
    echo
    echo '```text'
    cat /tmp/macpastehistory-session-checksum.log
    echo '```'
fi

if [[ -s /tmp/macpastehistory-session-baseline.log ]]; then
    echo
    echo "## Baseline Output"
    echo
    echo '```text'
    cat /tmp/macpastehistory-session-baseline.log
    echo '```'
fi

if [[ -s /tmp/macpastehistory-session-fixtures.log ]]; then
    echo
    echo "## Fixture Output"
    echo
    echo '```text'
    cat /tmp/macpastehistory-session-fixtures.log
    echo '```'
fi

exit 1
