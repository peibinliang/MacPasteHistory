#!/usr/bin/env bash
set -euo pipefail

previous_app=""
candidate_app=""
expected_bundle_id=""
expected_team_id=""

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-update-identity.sh [options]

Verify that consecutive public macOS releases have a stable code identity.

Options:
  --previous-app PATH        Previously published Developer ID signed app.
  --candidate-app PATH       Candidate Developer ID signed and notarized app.
  --expected-bundle-id ID    Production bundle identifier.
  --expected-team-id ID      Apple Developer Team identifier.
  -h, --help                 Show this help.
EOF
}

fail() {
    printf 'Release update identity verification failed: %s\n' "$1" >&2
    exit 1
}

require_value() {
    local option="$1"
    local value="${2:-}"
    [[ -n "$value" ]] || fail "$option requires a value"
}

plist_value() {
    local plist_path="$1"
    local key="$2"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

signature_details() {
    local app_path="$1"
    codesign -dv --verbose=4 "$app_path" 2>&1
}

team_identifier() {
    signature_details "$1" | awk -F= '/^TeamIdentifier=/ {print $2; exit}'
}

designated_requirement() {
    local app_path="$1"
    codesign -d -r- "$app_path" 2>&1 | sed -n 's/^# designated => //p' | head -n 1
}

verify_app_identity() {
    local label="$1"
    local app_path="$2"
    local info_plist="$app_path/Contents/Info.plist"
    local bundle_id details team_id requirement

    [[ -d "$app_path" && ! -L "$app_path" ]] || fail "$label app must be a physical .app bundle: $app_path"
    [[ -f "$info_plist" ]] || fail "$label app is missing Contents/Info.plist"

    bundle_id="$(plist_value "$info_plist" CFBundleIdentifier)"
    [[ "$bundle_id" == "$expected_bundle_id" ]] \
        || fail "$label bundle ID is '$bundle_id', expected '$expected_bundle_id'"

    codesign --verify --deep --strict "$app_path" >/dev/null 2>&1 \
        || fail "$label app does not have a valid code signature"

    details="$(signature_details "$app_path")"
    [[ "$details" == *"Authority=Developer ID Application:"* ]] \
        || fail "$label app must use a Developer ID Application signature"
    [[ "$details" != *"Signature=adhoc"* ]] \
        || fail "$label app must not use an ad-hoc signature; Developer ID is required"
    if [[ "$details" != *"flags="*"runtime"* && "$details" != *"Runtime Version="* ]]; then
        fail "$label app must enable the hardened runtime"
    fi

    team_id="$(team_identifier "$app_path")"
    [[ "$team_id" == "$expected_team_id" ]] \
        || fail "$label Team ID is '$team_id', expected '$expected_team_id'"

    requirement="$(designated_requirement "$app_path")"
    [[ -n "$requirement" ]] || fail "$label designated requirement is missing"
    if [[ "$requirement" == cdhash\ * || "$requirement" != *"identifier"* ]]; then
        fail "$label designated requirement is CDHash-only and changes between builds"
    fi
    [[ "$requirement" == *"$expected_team_id"* ]] \
        || fail "$label designated requirement does not bind the expected Team ID"

    printf '%s' "$requirement"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --previous-app)
            require_value "$1" "${2:-}"
            previous_app="$2"
            shift 2
            ;;
        --candidate-app)
            require_value "$1" "${2:-}"
            candidate_app="$2"
            shift 2
            ;;
        --expected-bundle-id)
            require_value "$1" "${2:-}"
            expected_bundle_id="$2"
            shift 2
            ;;
        --expected-team-id)
            require_value "$1" "${2:-}"
            expected_team_id="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown option: $1"
            ;;
    esac
done

[[ -n "$previous_app" ]] || fail "--previous-app is required"
[[ -n "$candidate_app" ]] || fail "--candidate-app is required"
[[ -n "$expected_bundle_id" ]] || fail "--expected-bundle-id is required"
[[ -n "$expected_team_id" ]] || fail "--expected-team-id is required"
command -v codesign >/dev/null 2>&1 || fail "codesign is required"
command -v spctl >/dev/null 2>&1 || fail "spctl is required"

previous_requirement="$(verify_app_identity "Previous" "$previous_app")"
candidate_requirement="$(verify_app_identity "Candidate" "$candidate_app")"

[[ "$candidate_requirement" == "$previous_requirement" ]] \
    || fail "candidate designated requirement is incompatible with the previous release"

spctl --assess --type execute --verbose=2 "$candidate_app" >/dev/null 2>&1 \
    || fail "candidate app is not accepted as a notarized Developer ID application"

cat <<EOF
# Release Update Identity Verification

| Field | Value |
|---|---|
| Bundle identifier | \`$expected_bundle_id\` |
| Team identifier | \`$expected_team_id\` |
| Previous signature | \`Developer ID Application\` |
| Candidate signature | \`Developer ID Application\` |
| Designated requirement | \`stable across releases\` |
| Candidate notarization | \`accepted\` |

Status: PASS
EOF
