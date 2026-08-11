#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_INFO_PLIST="$REPO_ROOT/MacPasteHistory/Resources/Info.plist"
EXPECTED_ARCHIVE_NAME="MacPasteHistory-1.0.2-3.zip"
EXPECTED_URL="https://github.com/peibinliang/MacPasteHistory/releases/download/V1.0.2/MacPasteHistory-1.0.2-3.zip"
EXPECTED_VERSION="1.0.2"
EXPECTED_BUILD="3"
EXPECTED_BUNDLE_ID="com.peibin.MacPasteHistory"
SPARKLE_NAMESPACE_URI="http://www.andymatuschak.org/xml-namespaces/sparkle"

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

Verify the V1.0.2 Sparkle appcast, adjacent archive checksum, embedded app
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

xml_count() {
    local xpath="$1"
    /usr/bin/xmllint --xpath "count($xpath)" "$appcast_path" 2>/dev/null || printf "0"
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

is_valid_signature_shape() {
    local signature="$1"
    local decoded_size reencoded_signature

    if ! printf '%s\n' "$signature" | grep -Eq '^[A-Za-z0-9+/]{86}==$'; then
        return 1
    fi
    if ! printf '%s' "$signature" | /usr/bin/base64 -D >/dev/null 2>&1; then
        return 1
    fi
    decoded_size="$(
        printf '%s' "$signature" \
            | /usr/bin/base64 -D 2>/dev/null \
            | /usr/bin/wc -c \
            | /usr/bin/tr -d '[:space:]'
    )"
    [[ "$decoded_size" == "64" ]] || return 1

    reencoded_signature="$(
        printf '%s' "$signature" \
            | /usr/bin/base64 -D 2>/dev/null \
            | /usr/bin/base64 \
            | /usr/bin/tr -d '\r\n'
    )"
    [[ "$reencoded_signature" == "$signature" ]]
}

validate_archive_entries() {
    local result validation_status

    set +e
    result="$(/usr/bin/python3 - "$archive_path" <<'PY'
import re
import stat
import sys
import zipfile

archive_path = sys.argv[1]
expected_root = "粘易.app"
try:
    with zipfile.ZipFile(archive_path) as archive:
        entries = archive.infolist()
except (OSError, zipfile.BadZipFile):
    print("invalid-zip")
    raise SystemExit(1)

if not entries:
    print("empty-zip")
    raise SystemExit(1)

for entry in entries:
    name = entry.filename.replace("\\", "/")
    parts = name.split("/")
    if (
        not name
        or "\x00" in name
        or name.startswith("/")
        or re.match(r"^[A-Za-z]:/", name)
        or any(part == ".." for part in parts)
    ):
        print("unsafe-entry")
        raise SystemExit(2)

    trimmed_name = name.rstrip("/")
    mode = entry.external_attr >> 16
    if trimmed_name == expected_root and stat.S_ISLNK(mode):
        print("top-level-symlink")
        raise SystemExit(3)

print("ok")
PY
    )"
    validation_status=$?
    set -e

    case "$result:$validation_status" in
        ok:0) return 0 ;;
        top-level-symlink:3) fail "top-level application path must not be a symbolic link" ;;
        unsafe-entry:2) fail "archive contains an unsafe archive entry path" ;;
        *) fail "archive is empty, invalid, or unreadable" ;;
    esac
}

validate_extracted_tree() {
    local application_path="$extract_dir/粘易.app"
    local result validation_status

    set +e
    result="$(/usr/bin/python3 - "$extract_dir" "$application_path" <<'PY'
import os
import sys

root, app = sys.argv[1:]
root_real = os.path.realpath(root)
unexpected_top_level = [name for name in os.listdir(root) if name not in {"粘易.app", "__MACOSX"}]
if unexpected_top_level:
    print("unexpected-root")
    raise SystemExit(6)
if os.path.islink(app):
    print("top-level-symlink")
    raise SystemExit(2)
if not os.path.isdir(app):
    print("missing-app")
    raise SystemExit(3)

app_real = os.path.realpath(app)
app_absolute = os.path.abspath(app)
try:
    if os.path.commonpath([root_real, app_real]) != root_real:
        print("app-escape")
        raise SystemExit(4)
except ValueError:
    print("app-escape")
    raise SystemExit(4)

for directory, subdirectories, filenames in os.walk(root, followlinks=False):
    for name in subdirectories + filenames:
        path = os.path.join(directory, name)
        if not os.path.islink(path):
            continue
        resolved = os.path.realpath(path)
        path_absolute = os.path.abspath(path)
        try:
            link_is_in_app = os.path.commonpath([app_absolute, path_absolute]) == app_absolute
            required_root = app_real if link_is_in_app else root_real
            stays_inside = os.path.commonpath([required_root, resolved]) == required_root
        except ValueError:
            stays_inside = False
        if not stays_inside or not os.path.exists(path):
            print("symlink-escape")
            raise SystemExit(5)

print("ok")
PY
    )"
    validation_status=$?
    set -e

    case "$result:$validation_status" in
        ok:0) return 0 ;;
        top-level-symlink:2) fail "top-level application path must not be a symbolic link" ;;
        symlink-escape:5) fail "application bundle symlink escapes application bundle or is broken" ;;
        app-escape:4) fail "canonical application path escapes extraction root" ;;
        unexpected-root:6) fail "archive contains entries outside 粘易.app" ;;
        *) fail "archive does not contain a safe physical 粘易.app bundle" ;;
    esac
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
require_command grep
require_command mktemp
require_command python3
require_command shasum
require_command stat
require_command xmllint

[[ -f "$appcast_path" ]] || fail "appcast file is missing"
[[ -f "$archive_path" ]] || fail "archive file is missing"
[[ -f "$archive_path.sha256" ]] || fail "adjacent SHA-256 file is missing"
[[ -f "$SOURCE_INFO_PLIST" ]] || fail "source Info.plist is missing"
[[ "$(basename "$archive_path")" == "$EXPECTED_ARCHIVE_NAME" ]] \
    || fail "archive filename does not match the V1.0.2 release name"

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
short_version_xpath="$item_xpath/*[local-name()=\"shortVersionString\" and namespace-uri()=\"$SPARKLE_NAMESPACE_URI\"]"
build_version_xpath="$item_xpath/*[local-name()=\"version\" and namespace-uri()=\"$SPARKLE_NAMESPACE_URI\"]"
enclosure_xpath="$item_xpath/*[local-name()=\"enclosure\" and namespace-uri()=\"\"]"
signature_xpath="$enclosure_xpath/@*[local-name()=\"edSignature\" and namespace-uri()=\"$SPARKLE_NAMESPACE_URI\"]"
any_signature_xpath="$enclosure_xpath/@*[local-name()=\"edSignature\"]"

if [[ "$(xml_count "$short_version_xpath")" != "1" \
    || "$(xml_count "$build_version_xpath")" != "1" ]]; then
    fail "latest item must use the Sparkle namespace URI for version metadata"
fi
if [[ "$(xml_count "$any_signature_xpath")" == "0" ]]; then
    fail "missing sparkle:edSignature"
fi
if [[ "$(xml_count "$signature_xpath")" != "1" ]]; then
    fail "latest item must use the Sparkle namespace URI for sparkle:edSignature"
fi

short_version="$(xml_value "$short_version_xpath")"
build_version="$(xml_value "$build_version_xpath")"
enclosure_url="$(xml_value "$enclosure_xpath/@url")"
enclosure_length="$(xml_value "$enclosure_xpath/@length")"
enclosure_signature="$(xml_value "$signature_xpath")"

[[ "$short_version" == "$EXPECTED_VERSION" ]] || fail "latest item short version is not 1.0.2"
[[ "$build_version" == "$EXPECTED_BUILD" ]] || fail "latest item build version is not 3"
[[ "$enclosure_url" == "$EXPECTED_URL" ]] || fail "enclosure URL does not match the fixed GitHub Release URL"

archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
[[ "$enclosure_length" == "$archive_length" ]] || fail "enclosure length does not match archive byte size"
if ! is_valid_signature_shape "$enclosure_signature"; then
    fail "sparkle:edSignature must be strict Base64 for a 64-byte Ed25519 signature"
fi

checksum_line_count="$(awk 'NF {count += 1} END {print count + 0}' "$archive_path.sha256")"
[[ "$checksum_line_count" == "1" ]] || fail "adjacent SHA-256 file must contain exactly one checksum"
expected_checksum="$(awk 'NF {print $1; exit}' "$archive_path.sha256")"
actual_checksum="$(/usr/bin/shasum -a 256 "$archive_path" | awk '{print $1}')"
[[ "$expected_checksum" =~ ^[[:xdigit:]]{64}$ ]] || fail "adjacent SHA-256 is malformed"
expected_checksum_lower="$(printf '%s' "$expected_checksum" | /usr/bin/tr '[:upper:]' '[:lower:]')"
actual_checksum_lower="$(printf '%s' "$actual_checksum" | /usr/bin/tr '[:upper:]' '[:lower:]')"
[[ "$expected_checksum_lower" == "$actual_checksum_lower" ]] \
    || fail "archive SHA-256 does not match adjacent checksum file"

validate_archive_entries

extract_dir="$(mktemp -d /private/tmp/macpastehistory-appcast-verify.XXXXXX)"
case "$extract_dir" in
    /private/tmp/macpastehistory-appcast-verify.*) ;;
    *) fail "unsafe temporary extraction directory" ;;
esac
trap cleanup EXIT

if ! /usr/bin/ditto -x -k "$archive_path" "$extract_dir" >/dev/null 2>&1; then
    fail "archive could not be extracted"
fi
validate_extracted_tree
archive_info_plist="$extract_dir/粘易.app/Contents/Info.plist"
[[ -f "$archive_info_plist" ]] || fail "archive does not contain 粘易.app/Contents/Info.plist"

archive_version="$(plist_value "$archive_info_plist" CFBundleShortVersionString)"
archive_build="$(plist_value "$archive_info_plist" CFBundleVersion)"
archive_bundle_id="$(plist_value "$archive_info_plist" CFBundleIdentifier)"
archive_public_key="$(plist_value "$archive_info_plist" SUPublicEDKey)"
[[ "$archive_version" == "$EXPECTED_VERSION" ]] || fail "archive short version is not 1.0.2"
[[ "$archive_build" == "$EXPECTED_BUILD" ]] || fail "archive build version is not 3"
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
echo "| EdDSA signature field | \`strict 64-byte Base64 shape verified\` |"
echo "| Cryptographic authenticity | \`deferred to Sparkle generate_appcast and client verification\` |"
echo "| Public key | \`matches source Info.plist\` |"
echo
echo "Status: PASS"
