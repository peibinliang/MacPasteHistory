#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
EXPECTED_BUNDLE_ID="com.peibin.MacPasteHistory"

allow_adhoc=0
should_build=0
app_path=""

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-app-signature.sh [options]

Verify the built Release .app code signature, Team ID, bundle identifier, and
App Sandbox entitlement.

Options:
  --app PATH      Verify a specific .app bundle.
  --build        Build the Release app before verification.
  --allow-adhoc  Treat ad-hoc/no-Team signatures as WARN for internal QA only.
  -h, --help     Show this help.
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
    local plist_path="$1"
    local key="$2"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || printf "unknown"
}

release_app_path() {
    local build_settings built_products_dir full_product_name
    build_settings="$(
        xcodebuild \
            -project MacPasteHistory.xcodeproj \
            -scheme "$SCHEME" \
            -configuration Release \
            -destination 'platform=macOS,arch=arm64' \
            -showBuildSettings
    )"
    built_products_dir="$(printf "%s\n" "$build_settings" | awk -F ' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / {print $2; exit}')"
    full_product_name="$(printf "%s\n" "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / {print $2; exit}')"
    printf "%s/%s" "$built_products_dir" "$full_product_name"
}

add_violation() {
    violations+=("$1")
}

add_warning() {
    warnings+=("$1")
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            if [[ $# -lt 2 ]]; then
                echo "--app requires a path" >&2
                exit 2
            fi
            app_path="$2"
            shift
            ;;
        --build)
            should_build=1
            ;;
        --allow-adhoc)
            allow_adhoc=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

require_command awk
require_command codesign
require_command plutil
require_command xcodebuild

cd "$REPO_ROOT"

if [[ "$should_build" -eq 1 ]]; then
    scripts/preview-release-app.sh --build-only >/tmp/macpastehistory-release-app-signature-build.log
fi

if [[ -z "$app_path" ]]; then
    app_path="$(release_app_path)"
fi

violations=()
warnings=()

if [[ ! -d "$app_path" ]]; then
    add_violation "Release app not found at $app_path. Run with --build or build Release first."
fi

info_plist="$app_path/Contents/Info.plist"
if [[ ! -f "$info_plist" ]]; then
    add_violation "Info.plist missing from app bundle."
fi

bundle_id="unknown"
version="unknown"
build_number="unknown"
if [[ -f "$info_plist" ]]; then
    bundle_id="$(plist_value "$info_plist" CFBundleIdentifier)"
    version="$(plist_value "$info_plist" CFBundleShortVersionString)"
    build_number="$(plist_value "$info_plist" CFBundleVersion)"
fi

codesign_output=""
codesign_verify_output=""
codesign_verify_status=1
entitlements_output=""
signature="unknown"
team_identifier="unknown"
authority="not available"
sandbox_status="missing"

if [[ -d "$app_path" ]]; then
    codesign_output="$(codesign -dvv "$app_path" 2>&1 || true)"
    signature="$(printf "%s\n" "$codesign_output" | awk -F= '/^Signature=/ {print $2; exit}')"
    team_identifier="$(printf "%s\n" "$codesign_output" | awk -F= '/^TeamIdentifier=/ {print $2; exit}')"
    authority="$(printf "%s\n" "$codesign_output" | awk -F= '/^Authority=/ {print $2; exit}')"
    entitlements_output="$(codesign -d --entitlements :- "$app_path" 2>/dev/null || true)"

    set +e
    codesign_verify_output="$(codesign --verify --deep --strict "$app_path" 2>&1)"
    codesign_verify_status=$?
    set -e

    if [[ "$codesign_verify_status" -ne 0 ]]; then
        add_violation "codesign --verify --deep --strict failed."
    fi

    if printf "%s\n" "$entitlements_output" | plutil -p - 2>/dev/null | grep -q '"com.apple.security.app-sandbox" => true'; then
        sandbox_status="present"
    else
        add_violation "App Sandbox entitlement is missing or false."
    fi
fi

if [[ -z "$signature" ]]; then
    signature="unknown"
fi
if [[ -z "$team_identifier" ]]; then
    team_identifier="unknown"
fi
if [[ -z "$authority" ]]; then
    authority="not available"
fi

if [[ "$bundle_id" != "$EXPECTED_BUNDLE_ID" ]]; then
    add_violation "Bundle identifier is '$bundle_id', expected '$EXPECTED_BUNDLE_ID'."
fi

if [[ "$signature" == "adhoc" || "$team_identifier" == "not set" || "$team_identifier" == "unknown" ]]; then
    if [[ "$allow_adhoc" -eq 1 ]]; then
        add_warning "Release app is ad-hoc signed or has no TeamIdentifier; this is acceptable only for local/internal QA."
    else
        add_violation "Release app is not signed with a distribution-capable Team ID."
    fi
fi

echo "# Release App Signature Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| App path | \`$app_path\` |"
echo "| Bundle identifier | \`$bundle_id\` |"
echo "| Version / build | \`$version ($build_number)\` |"
echo "| Signature | \`$signature\` |"
echo "| Team identifier | \`$team_identifier\` |"
echo "| Authority | \`$authority\` |"
echo "| App Sandbox entitlement | \`$sandbox_status\` |"
echo "| Ad-hoc allowed | \`$([[ "$allow_adhoc" -eq 1 ]] && printf "yes" || printf "no")\` |"
echo "| Violations | \`${#violations[@]}\` |"
echo "| Warnings | \`${#warnings[@]}\` |"
echo

if [[ "${#violations[@]}" -eq 0 && "${#warnings[@]}" -eq 0 ]]; then
    echo "Status: PASS"
    exit 0
fi

if [[ "${#violations[@]}" -eq 0 ]]; then
    echo "Status: WARN"
else
    echo "Status: FAIL"
fi

if [[ "${#violations[@]}" -gt 0 ]]; then
    echo
    echo "## Violations"
    echo
    for violation in "${violations[@]}"; do
        echo "- $violation"
    done
fi

if [[ "${#warnings[@]}" -gt 0 ]]; then
    echo
    echo "## Warnings"
    echo
    for warning in "${warnings[@]}"; do
        echo "- $warning"
    done
fi

if [[ "$codesign_verify_status" -ne 0 && -n "$codesign_verify_output" ]]; then
    echo
    echo "## codesign Verification Output"
    echo
    echo '```text'
    printf "%s\n" "$codesign_verify_output"
    echo '```'
fi

if [[ "${#violations[@]}" -gt 0 ]]; then
    exit 1
fi

exit 0
