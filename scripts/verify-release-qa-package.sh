#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
zip_path=""
checksum_path=""
keep_extracted=0
formal_update=0
checksum_explicit=0

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-qa-package.sh [options] <package.zip>

Verify a MacPasteHistory Release QA package before manual testing.

Options:
  --checksum FILE  Use an explicit SHA-256 checksum file.
  --keep           Keep the extracted app and print its path.
  --formal-update  Require the exact V1.0.1 archive name, Developer ID
                   signature, notarization, bundle identity, and Sparkle XPCs.
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
            checksum_explicit=1
            shift
            ;;
        --keep)
            keep_extracted=1
            ;;
        --formal-update)
            formal_update=1
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
if [[ "$formal_update" -eq 1 ]]; then
    require_command grep
    require_command spctl
fi

if [[ ! -f "$zip_path" ]]; then
    echo "Package zip not found: $zip_path" >&2
    exit 1
fi

if [[ "$formal_update" -eq 1 && "$(basename "$zip_path")" != "粘易-1.0.1-2.zip" ]]; then
    echo "Formal update archive must be named 粘易-1.0.1-2.zip" >&2
    exit 1
fi
if [[ "$formal_update" -eq 1 && "$checksum_explicit" -eq 1 ]]; then
    echo "Formal update verification requires the adjacent <archive>.sha256 file" >&2
    exit 2
fi

if [[ -z "$checksum_path" ]]; then
    checksum_path="$zip_path.sha256"
fi

echo "Verifying QA package: $zip_path"

if [[ -f "$checksum_path" ]]; then
    checksum_dir="$(cd "$(dirname "$checksum_path")" && pwd)"
    checksum_file="$(basename "$checksum_path")"
    if [[ "$formal_update" -eq 1 ]]; then
        checksum_line_count="$(awk 'NF {count += 1} END {print count + 0}' "$checksum_path")"
        checksum_archive_name="$(awk 'NF {$1=""; sub(/^[ *]+/, ""); print; exit}' "$checksum_path")"
        if [[ "$checksum_line_count" != "1" \
            || "$checksum_archive_name" != "$(basename "$zip_path")" ]]; then
            echo "Formal update checksum must contain exactly the adjacent archive filename" >&2
            exit 1
        fi
    fi
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
if [[ "$formal_update" -eq 1 ]]; then
    app_path="$extract_dir/粘易.app"
else
    app_path="$(find "$extract_dir" -type d -name "*.app" -print -quit)"
fi

if [[ -z "$app_path" || ! -d "$app_path" ]]; then
    echo "No .app bundle found in package" >&2
    exit 1
fi

info_plist="$app_path/Contents/Info.plist"
executable_path="$app_path/Contents/MacOS/粘易"

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
codesign_output="$(codesign -dvvv "$app_path" 2>&1 || true)"
signature="$(printf "%s\n" "$codesign_output" | awk -F= '/^Signature=/ {print $2; exit}')"
team_identifier="$(printf "%s\n" "$codesign_output" | awk -F= '/^TeamIdentifier=/ {print $2; exit}')"
authority="$(printf "%s\n" "$codesign_output" | awk -F= '/^Authority=/ {print $2; exit}')"
entitlements_output="$(codesign -d --entitlements :- "$app_path" 2>/dev/null || true)"

if [[ -z "$signature" ]]; then
    signature="unknown"
fi
if [[ -z "$team_identifier" ]]; then
    team_identifier="not set"
fi
if [[ -z "$authority" ]]; then
    authority="not available"
fi

notarization="not checked"
if [[ "$formal_update" -eq 1 ]]; then
    if [[ "$version" != "1.0.1" || "$build_number" != "2" ]]; then
        echo "Formal update app must report version 1.0.1 (2)" >&2
        exit 1
    fi
    if [[ "$bundle_id" != "com.peibin.MacPasteHistory" ]]; then
        echo "Formal update app has an unexpected bundle identifier" >&2
        exit 1
    fi
    if [[ "$signature" == "adhoc" || "$authority" != "Developer ID Application:"* \
        || "$team_identifier" == "not set" ]]; then
        echo "Developer ID Application signature is required; ad-hoc and other identities are refused" >&2
        exit 1
    fi

    set +e
    spctl_output="$(spctl --assess --type execute --verbose=4 "$app_path" 2>&1)"
    spctl_status=$?
    set -e
    if [[ "$spctl_status" -ne 0 ]] \
        || ! printf '%s\n' "$spctl_output" | grep -Fq 'source=Notarized Developer ID'; then
        echo "Formal update app is not accepted as a notarized Developer ID application by spctl" >&2
        exit 1
    fi
    notarization="accepted (Notarized Developer ID)"
    "$REPO_ROOT/scripts/verify-sparkle-release-bundle.sh" "$app_path" >/dev/null
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
echo "| Authority | \`$authority\` |"
echo "| Team identifier | \`$team_identifier\` |"
echo "| App Sandbox entitlement | \`present\` |"
echo "| Notarization | \`$notarization\` |"
echo "| Formal update mode | \`$([[ "$formal_update" -eq 1 ]] && printf "yes" || printf "no")\` |"

if [[ "$keep_extracted" -eq 1 ]]; then
    echo
    echo "Extracted app kept at: $app_path"
fi
