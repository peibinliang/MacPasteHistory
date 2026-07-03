#!/usr/bin/env bash
set -euo pipefail

zip_path=""
checksum_path=""
keep_extracted=0

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-qa-package.sh [options] <package.zip>

Verify a MacPasteHistory Release QA package before manual testing.

Options:
  --checksum FILE  Use an explicit SHA-256 checksum file.
  --keep           Keep the extracted app and print its path.
  -h, --help       Show this help.
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

executable_architectures() {
    local executable_path="$1"
    if command -v lipo >/dev/null 2>&1; then
        lipo -info "$executable_path" 2>/dev/null | sed 's/^.*are: //; s/^.*architecture: //' | xargs
    else
        printf "unknown"
    fi
}

cleanup() {
    if [[ "$keep_extracted" -eq 0 && -n "${extract_dir:-}" && -d "$extract_dir" ]]; then
        rm -rf "$extract_dir"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --checksum)
            if [[ $# -lt 2 ]]; then
                echo "--checksum requires a file path" >&2
                exit 2
            fi
            checksum_path="$2"
            shift
            ;;
        --keep)
            keep_extracted=1
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
            if [[ -n "$zip_path" ]]; then
                echo "Only one package zip may be provided" >&2
                exit 2
            fi
            zip_path="$1"
            ;;
    esac
    shift
done

if [[ -z "$zip_path" ]]; then
    usage >&2
    exit 2
fi

require_command codesign
require_command ditto
require_command find
require_command mktemp
require_command rm
require_command shasum

if [[ ! -f "$zip_path" ]]; then
    echo "Package zip not found: $zip_path" >&2
    exit 1
fi

if [[ -z "$checksum_path" ]]; then
    checksum_path="$zip_path.sha256"
fi

echo "Verifying QA package: $zip_path"

if [[ -f "$checksum_path" ]]; then
    checksum_dir="$(cd "$(dirname "$checksum_path")" && pwd)"
    checksum_file="$(basename "$checksum_path")"
    echo "Checking SHA-256: $checksum_path"
    (
        cd "$checksum_dir"
        shasum -a 256 -c "$checksum_file"
    )
else
    echo "Checksum file not found: $checksum_path" >&2
    exit 1
fi

extract_dir="$(mktemp -d "${TMPDIR:-/tmp}/macpastehistory-qa-verify.XXXXXX")"
trap cleanup EXIT

ditto -x -k "$zip_path" "$extract_dir"
app_path="$(find "$extract_dir" -type d -name "*.app" -print -quit)"

if [[ -z "$app_path" || ! -d "$app_path" ]]; then
    echo "No .app bundle found in package" >&2
    exit 1
fi

info_plist="$app_path/Contents/Info.plist"
executable_path="$app_path/Contents/MacOS/MacPasteHistory"

if [[ ! -f "$info_plist" ]]; then
    echo "Info.plist missing from app bundle" >&2
    exit 1
fi
if [[ ! -x "$executable_path" ]]; then
    echo "App executable missing or not executable: $executable_path" >&2
    exit 1
fi

version="$(plist_value "$info_plist" CFBundleShortVersionString)"
build_number="$(plist_value "$info_plist" CFBundleVersion)"
bundle_id="$(plist_value "$info_plist" CFBundleIdentifier)"
architectures="$(executable_architectures "$executable_path")"
codesign_output="$(codesign -dvv "$app_path" 2>&1 || true)"
signature="$(printf "%s\n" "$codesign_output" | awk -F= '/^Signature=/ {print $2; exit}')"
team_identifier="$(printf "%s\n" "$codesign_output" | awk -F= '/^TeamIdentifier=/ {print $2; exit}')"
entitlements_output="$(codesign -d --entitlements :- "$app_path" 2>/dev/null || true)"

if [[ -z "$signature" ]]; then
    signature="unknown"
fi
if [[ -z "$team_identifier" ]]; then
    team_identifier="not set"
fi

if ! printf "%s\n" "$entitlements_output" | grep -q "com.apple.security.app-sandbox"; then
    echo "App Sandbox entitlement is missing" >&2
    exit 1
fi

codesign --verify --deep --strict "$app_path"

echo
echo "# Release QA Package Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| App path | \`$app_path\` |"
echo "| Bundle identifier | \`$bundle_id\` |"
echo "| Version / build | \`$version ($build_number)\` |"
echo "| Architectures | \`$architectures\` |"
echo "| Signature | \`$signature\` |"
echo "| Team identifier | \`$team_identifier\` |"
echo "| App Sandbox entitlement | \`present\` |"

if [[ "$keep_extracted" -eq 1 ]]; then
    echo
    echo "Extracted app kept at: $app_path"
fi
