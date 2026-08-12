#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/macpastehistory-update-identity-test.XXXXXX")"
EXPECTED_BUNDLE_ID="com.peibin.MacPasteHistory"
EXPECTED_TEAM_ID="ABCDE12345"
failures=0

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

make_app() {
    local path="$1"
    local bundle_id="$2"
    local team_id="$3"
    local signature="$4"
    local requirement="$5"
    local notarized="$6"

    mkdir -p "$path/Contents"
    plutil -create xml1 "$path/Contents/Info.plist"
    plutil -insert CFBundleIdentifier -string "$bundle_id" "$path/Contents/Info.plist"
    printf '%s\n' "$team_id" >"$path/.fixture-team-id"
    printf '%s\n' "$signature" >"$path/.fixture-signature"
    printf '%s\n' "$requirement" >"$path/.fixture-requirement"
    printf '%s\n' "$notarized" >"$path/.fixture-notarized"
}

expect_pass() {
    local name="$1"
    shift
    if ! output="$($@ 2>&1)"; then
        printf 'FAIL: %s\n%s\n' "$name" "$output" >&2
        failures=$((failures + 1))
    fi
}

expect_failure_containing() {
    local name="$1"
    local expected="$2"
    shift 2
    if output="$($@ 2>&1)"; then
        printf 'FAIL: %s unexpectedly passed\n' "$name" >&2
        failures=$((failures + 1))
    elif [[ "$output" != *"$expected"* ]]; then
        printf 'FAIL: %s did not contain %q\n%s\n' "$name" "$expected" "$output" >&2
        failures=$((failures + 1))
    fi
}

mkdir -p "$TEST_ROOT/bin"
cat >"$TEST_ROOT/bin/codesign" <<'FAKE_CODESIGN'
#!/usr/bin/env bash
set -euo pipefail
app="${@: -1}"
if [[ "$*" == *"-r-"* ]]; then
    printf '# designated => %s\n' "$(<"$app/.fixture-requirement")" >&2
    exit 0
fi
signature="$(<"$app/.fixture-signature")"
team_id="$(<"$app/.fixture-team-id")"
printf 'Signature=%s\n' "$signature" >&2
printf 'TeamIdentifier=%s\n' "$team_id" >&2
if [[ "$signature" == "Developer ID" ]]; then
    printf 'Authority=Developer ID Application: Fixture (%s)\n' "$team_id" >&2
    printf 'Runtime Version=14.0.0\n' >&2
fi
FAKE_CODESIGN
chmod +x "$TEST_ROOT/bin/codesign"

cat >"$TEST_ROOT/bin/spctl" <<'FAKE_SPCTL'
#!/usr/bin/env bash
set -euo pipefail
app="${@: -1}"
[[ "$(<"$app/.fixture-notarized")" == "yes" ]]
FAKE_SPCTL
chmod +x "$TEST_ROOT/bin/spctl"

stable_requirement='identifier "com.peibin.MacPasteHistory" and anchor apple generic and certificate leaf[subject.OU] = "ABCDE12345"'
previous_app="$TEST_ROOT/previous.app"
candidate_app="$TEST_ROOT/candidate.app"
make_app "$previous_app" "$EXPECTED_BUNDLE_ID" "$EXPECTED_TEAM_ID" "Developer ID" "$stable_requirement" yes
make_app "$candidate_app" "$EXPECTED_BUNDLE_ID" "$EXPECTED_TEAM_ID" "Developer ID" "$stable_requirement" yes

verifier=(
    env "PATH=$TEST_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    "$REPO_ROOT/scripts/verify-release-update-identity.sh"
    --previous-app "$previous_app"
    --candidate-app "$candidate_app"
    --expected-bundle-id "$EXPECTED_BUNDLE_ID"
    --expected-team-id "$EXPECTED_TEAM_ID"
)

expect_pass "compatible Developer ID releases" "${verifier[@]}"

make_app "$candidate_app" "$EXPECTED_BUNDLE_ID" "not set" adhoc 'cdhash H"1234567890"' yes
expect_failure_containing "ad-hoc candidate" "Developer ID" "${verifier[@]}"

make_app "$candidate_app" "$EXPECTED_BUNDLE_ID" "ZZZZZ99999" "Developer ID" "$stable_requirement" yes
expect_failure_containing "mismatched candidate Team ID" "Team ID" "${verifier[@]}"

make_app "$candidate_app" "$EXPECTED_BUNDLE_ID" "$EXPECTED_TEAM_ID" "Developer ID" 'cdhash H"1234567890"' yes
expect_failure_containing "CDHash-only candidate" "CDHash" "${verifier[@]}"

make_app "$candidate_app" "$EXPECTED_BUNDLE_ID" "$EXPECTED_TEAM_ID" "Developer ID" "$stable_requirement" no
expect_failure_containing "candidate without notarization" "notarized" "${verifier[@]}"

if [[ "$failures" -ne 0 ]]; then
    printf 'Failures: %s\n' "$failures" >&2
    exit 1
fi

printf 'Release update identity verifier tests: PASS\n'
