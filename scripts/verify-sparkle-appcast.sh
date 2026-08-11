#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_INFO_PLIST="$REPO_ROOT/MacPasteHistory/Resources/Info.plist"
EXPECTED_ARCHIVE_NAME="粘易-1.0.1-2.zip"
EXPECTED_URL="https://github.com/peibinliang/MacPasteHistory/releases/download/v1.0.1/%E7%B2%98%E6%98%93-1.0.1-2.zip"
EXPECTED_VERSION="1.0.1"
EXPECTED_BUILD="2"
EXPECTED_BUNDLE_ID="com.peibin.MacPasteHistory"

appcast_path=""
archive_path=""
expected_public_key=""
extract_dir=""

usage() {
    cat <<'EOF'
Usage: scripts/verify-sparkle-appcast.sh \
  --appcast PATH \
  --archive PATH \
  --expected-public-key PUBLIC_KEY

Verify the V1.0.1 Sparkle appcast, adjacent archive checksum, embedded app
identity, and committed EdDSA public key. The public key is never printed.
EOF
}

cleanup() {
    if [[ -n "$extract_dir" && -d "$extract_dir" ]]; then
        rm -rf "$extract_dir"
    fi
}

fail() {
    echo "Sparkle appcast verification failed: $1" >&2
    exit 1
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        fail "missing required command: $command_name"
    fi
}

plist_value() {
    local plist_path="$1"
    local key="$2"
    /usr/libexec/PlistBuddy -c "Print :$key" "$plist_path" 2>/dev/null || true
}

xml_value() {
    local xpath="$1"
    /usr/bin/xmllint --xpath "string($xpath)" "$appcast_path" 2>/dev/null || true
}

is_valid_public_key() {
    local public_key="$1"
    local decoded_size

    if [[ -z "$public_key" ]]; then
        return 1
    fi
    if ! printf '%s' "$public_key" | /usr/bin/base64 -D >/dev/null 2>&1; then
        return 1
    fi
    decoded_size="$(
        printf '%s' "$public_key" \
            | /usr/bin/base64 -D 2>/dev/null \
            | /usr/bin/wc -c \
            | /usr/bin/tr -d '[:space:]'
    )"
    [[ "$decoded_size" == "32" ]]
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --appcast)
            [[ $# -ge 2 ]] || { echo "--appcast requires a path" >&2; exit 2; }
            appcast_path="$2"
            shift
            ;;
        --archive)
            [[ $# -ge 2 ]] || { echo "--archive requires a path" >&2; exit 2; }
            archive_path="$2"
            shift
            ;;
        --expected-public-key)
            [[ $# -ge 2 ]] || { echo "--expected-public-key requires a value" >&2; exit 2; }
            expected_public_key="$2"
            shift
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

[[ -n "$appcast_path" ]] || { usage >&2; exit 2; }
[[ -n "$archive_path" ]] || { usage >&2; exit 2; }
[[ -n "$expected_public_key" ]] || { usage >&2; exit 2; }

require_command ditto
require_command mktemp
require_command shasum
require_command stat
require_command xmllint

[[ -f "$appcast_path" ]] || fail "appcast file is missing"
[[ -f "$archive_path" ]] || fail "archive file is missing"
[[ -f "$archive_path.sha256" ]] || fail "adjacent SHA-256 file is missing"
[[ -f "$SOURCE_INFO_PLIST" ]] || fail "source Info.plist is missing"
[[ "$(basename "$archive_path")" == "$EXPECTED_ARCHIVE_NAME" ]] \
    || fail "archive filename does not match the V1.0.1 release name"

if ! is_valid_public_key "$expected_public_key"; then
    fail "expected public key is not a valid 32-byte EdDSA public key"
fi
source_public_key="$(plist_value "$SOURCE_INFO_PLIST" SUPublicEDKey)"
if [[ "$source_public_key" != "$expected_public_key" ]]; then
    fail "expected public key does not match source Info.plist"
fi

if ! /usr/bin/xmllint --noout "$appcast_path" >/dev/null 2>&1; then
    fail "appcast XML does not parse"
fi

item_xpath='(/*[local-name()="rss"]/*[local-name()="channel"]/*[local-name()="item"])[1]'
short_version="$(xml_value "$item_xpath/*[local-name()=\"shortVersionString\"]")"
build_version="$(xml_value "$item_xpath/*[local-name()=\"version\"]")"
enclosure_url="$(xml_value "$item_xpath/*[local-name()=\"enclosure\"]/@url")"
enclosure_length="$(xml_value "$item_xpath/*[local-name()=\"enclosure\"]/@length")"
enclosure_signature="$(xml_value "$item_xpath/*[local-name()=\"enclosure\"]/@*[local-name()=\"edSignature\"]")"

[[ "$short_version" == "$EXPECTED_VERSION" ]] || fail "latest item short version is not 1.0.1"
[[ "$build_version" == "$EXPECTED_BUILD" ]] || fail "latest item build version is not 2"
[[ "$enclosure_url" == "$EXPECTED_URL" ]] || fail "enclosure URL does not match the fixed GitHub Release URL"

archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
[[ "$enclosure_length" == "$archive_length" ]] || fail "enclosure length does not match archive byte size"
[[ -n "${enclosure_signature//[[:space:]]/}" ]] || fail "missing sparkle:edSignature"

checksum_line_count="$(awk 'NF {count += 1} END {print count + 0}' "$archive_path.sha256")"
[[ "$checksum_line_count" == "1" ]] || fail "adjacent SHA-256 file must contain exactly one checksum"
expected_checksum="$(awk 'NF {print $1; exit}' "$archive_path.sha256")"
actual_checksum="$(/usr/bin/shasum -a 256 "$archive_path" | awk '{print $1}')"
[[ "$expected_checksum" =~ ^[[:xdigit:]]{64}$ ]] || fail "adjacent SHA-256 is malformed"
expected_checksum_lower="$(printf '%s' "$expected_checksum" | /usr/bin/tr '[:upper:]' '[:lower:]')"
actual_checksum_lower="$(printf '%s' "$actual_checksum" | /usr/bin/tr '[:upper:]' '[:lower:]')"
[[ "$expected_checksum_lower" == "$actual_checksum_lower" ]] \
    || fail "archive SHA-256 does not match adjacent checksum file"

extract_dir="$(mktemp -d /private/tmp/macpastehistory-appcast-verify.XXXXXX)"
case "$extract_dir" in
    /private/tmp/macpastehistory-appcast-verify.*) ;;
    *) fail "unsafe temporary extraction directory" ;;
esac
trap cleanup EXIT

if ! /usr/bin/ditto -x -k "$archive_path" "$extract_dir" >/dev/null 2>&1; then
    fail "archive could not be extracted"
fi
archive_info_plist="$extract_dir/粘易.app/Contents/Info.plist"
[[ -f "$archive_info_plist" ]] || fail "archive does not contain 粘易.app/Contents/Info.plist"

archive_version="$(plist_value "$archive_info_plist" CFBundleShortVersionString)"
archive_build="$(plist_value "$archive_info_plist" CFBundleVersion)"
archive_bundle_id="$(plist_value "$archive_info_plist" CFBundleIdentifier)"
archive_public_key="$(plist_value "$archive_info_plist" SUPublicEDKey)"
[[ "$archive_version" == "$EXPECTED_VERSION" ]] || fail "archive short version is not 1.0.1"
[[ "$archive_build" == "$EXPECTED_BUILD" ]] || fail "archive build version is not 2"
[[ "$archive_bundle_id" == "$EXPECTED_BUNDLE_ID" ]] || fail "archive bundle identifier is not com.peibin.MacPasteHistory"
[[ "$archive_public_key" == "$expected_public_key" ]] \
    || fail "archive public key does not match source Info.plist"

echo "# Sparkle Appcast Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Version / build | \`$archive_version ($archive_build)\` |"
echo "| Bundle identifier | \`$archive_bundle_id\` |"
echo "| Archive | \`$archive_path\` |"
echo "| Archive bytes | \`$archive_length\` |"
echo "| SHA-256 | \`verified\` |"
echo "| EdDSA signature field | \`present\` |"
echo "| Public key | \`matches source Info.plist\` |"
echo
echo "Status: PASS"
