#!/usr/bin/env bash
set -euo pipefail

violations=()

add_violation() {
    violations+=("$1")
}

command_status() {
    local status="$1"
    if [[ "$status" -eq 0 ]]; then
        printf "passed"
    else
        printf "failed"
    fi
}

developer_dir="$(xcode-select -p 2>/dev/null || true)"
if [[ -z "$developer_dir" ]]; then
    add_violation "xcode-select has no active developer directory."
elif [[ ! -d "$developer_dir" ]]; then
    add_violation "Selected developer directory does not exist: $developer_dir"
fi

xcode_version="$(xcodebuild -version 2>/dev/null | tr '\n' ' ' | sed 's/[[:space:]]*$//' || true)"
if [[ -z "$xcode_version" ]]; then
    add_violation "xcodebuild -version did not return an Xcode version."
fi

first_launch_log="$(mktemp "${TMPDIR:-/tmp}/macpastehistory-xcode-first-launch.XXXXXX")"
license_log="$(mktemp "${TMPDIR:-/tmp}/macpastehistory-xcode-license.XXXXXX")"

set +e
xcodebuild -checkFirstLaunchStatus >"$first_launch_log" 2>&1
first_launch_exit=$?
xcodebuild -license status >"$license_log" 2>&1
license_exit=$?
set -e

first_launch_status="$(command_status "$first_launch_exit")"
license_status="$(command_status "$license_exit")"
first_launch_output="$(cat "$first_launch_log" 2>/dev/null || true)"
license_output="$(cat "$license_log" 2>/dev/null || true)"
rm -f "$first_launch_log" "$license_log"

if [[ "$first_launch_exit" -ne 0 ]]; then
    add_violation "Xcode first-launch authorization is not complete."
fi

if [[ "$license_exit" -ne 0 ]]; then
    add_violation "Xcode license is not accepted."
fi

echo "# Xcode Authorization Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Developer directory | \`${developer_dir:-not selected}\` |"
echo "| Xcode version | \`${xcode_version:-unknown}\` |"
echo "| First launch status | \`$first_launch_status\` |"
echo "| License status | \`$license_status\` |"
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

if [[ -n "$first_launch_output" || -n "$license_output" ]]; then
    echo
    echo "## Command Output"
    echo
    if [[ -n "$first_launch_output" ]]; then
        echo "### xcodebuild -checkFirstLaunchStatus"
        echo
        echo '```text'
        printf "%s\n" "$first_launch_output"
        echo '```'
    fi
    if [[ -n "$license_output" ]]; then
        echo
        echo "### xcodebuild -license status"
        echo
        echo '```text'
        printf "%s\n" "$license_output"
        echo '```'
    fi
fi

exit 1
