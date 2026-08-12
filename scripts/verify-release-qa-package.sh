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
  --formal-update  Require an archive name matching its app version/build,
                   Developer ID signature, notarization, bundle identity,
                   and Sparkle XPCs.
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

validate_archive_entries() {
    local archive_path="$1"
    local expected_root="$2"
    local result validation_status

    set +e
    result="$(/usr/bin/python3 - "$archive_path" "$expected_root" <<'PY'
import re
import stat
import sys
import zipfile

archive_path, expected_root = sys.argv[1:]
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
    if expected_root and trimmed_name == expected_root and stat.S_ISLNK(mode):
        print("top-level-symlink")
        raise SystemExit(3)

print("ok")
PY
    )"
    validation_status=$?
    set -e

    case "$result:$validation_status" in
        ok:0) return 0 ;;
        top-level-symlink:3)
            echo "Formal archive top-level application path must not be a symbolic link" >&2
            return 1
            ;;
        unsafe-entry:2)
            echo "Formal archive contains an unsafe archive entry path" >&2
            return 1
            ;;
        *)
            echo "Package zip is empty, invalid, or unreadable" >&2
            return 1
            ;;
    esac
}

validate_extracted_tree() {
    local extraction_root="$1"
    local application_path="$2"
    local result validation_status

    set +e
    result="$(/usr/bin/python3 - "$extraction_root" "$application_path" "$formal_update" <<'PY'
import os
import sys

root, app, strict_root = sys.argv[1:]
root_real = os.path.realpath(root)

if strict_root == "1":
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
        top-level-symlink:2)
            echo "Extracted top-level application path must not be a symbolic link" >&2
            ;;
        symlink-escape:5)
            echo "Extracted application bundle symlink escapes application bundle or is broken" >&2
            ;;
        app-escape:4)
            echo "Canonical application path escapes extraction root" >&2
            ;;
        unexpected-root:6)
            echo "Formal archive contains entries outside the expected application root" >&2
            ;;
        *)
            echo "No safe .app bundle found in package" >&2
            ;;
    esac
    return 1
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
require_command python3
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

if [[ "$formal_update" -eq 1 && "$checksum_explicit" -eq 1 ]]; then
    echo "Formal update verification requires the adjacent <archive>.sha256 file" >&2
    exit 2
fi

if [[ -z "$checksum_path" ]]; then
    checksum_path="$zip_path.sha256"
fi

if [[ "$formal_update" -eq 1 ]]; then
    validate_archive_entries "$zip_path" "粘易.app"
else
    validate_archive_entries "$zip_path" ""
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
    if find "$extract_dir" -mindepth 1 -maxdepth 1 -type l -name "*.app" -print -quit | grep -q .; then
        echo "Extracted top-level application path must not be a symbolic link" >&2
        exit 1
    fi
    app_paths=()
    while IFS= read -r -d '' candidate; do
        app_paths+=("$candidate")
    done < <(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d -name "*.app" -print0)
    if [[ "${#app_paths[@]}" -ne 1 ]]; then
        echo "Package must contain exactly one physical .app bundle" >&2
        exit 1
    fi
    app_path="${app_paths[0]}"
fi

validate_extracted_tree "$extract_dir" "$app_path"

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
    expected_archive_name="MacPasteHistory-$version-$build_number.zip"
    if [[ "$(basename "$zip_path")" != "$expected_archive_name" ]]; then
        echo "Formal update archive must be named $expected_archive_name to match the app version/build" >&2
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
