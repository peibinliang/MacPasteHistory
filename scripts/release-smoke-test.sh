#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
BUNDLE_ID="com.peibin.MacPasteHistory"
APP_PROCESS_NAME="MacPasteHistory"
DB_RELATIVE_PATH="Library/Application Support/MacPasteHistory/clipboard.db"

cd "$REPO_ROOT"

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

sql_escape() {
    printf "%s" "$1" | sed "s/'/''/g"
}

quit_app() {
    osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true
}

wait_for_process() {
    local attempt
    for attempt in {1..30}; do
        if pgrep -x "$APP_PROCESS_NAME" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo "App process did not start within timeout." >&2
    return 1
}

wait_for_exit() {
    local attempt
    for attempt in {1..15}; do
        if ! pgrep -x "$APP_PROCESS_NAME" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo "App process did not exit within timeout." >&2
    return 1
}

find_database() {
    local sandbox_db="$HOME/Library/Containers/$BUNDLE_ID/Data/$DB_RELATIVE_PATH"
    local unsandboxed_db="$HOME/$DB_RELATIVE_PATH"

    if [[ -f "$sandbox_db" ]]; then
        printf "%s\n" "$sandbox_db"
        return 0
    fi

    if [[ -f "$unsandboxed_db" ]]; then
        printf "%s\n" "$unsandboxed_db"
        return 0
    fi

    return 1
}

wait_for_database() {
    local attempt
    for attempt in {1..30}; do
        if find_database; then
            return 0
        fi
        sleep 1
    done
    echo "Database was not created within timeout." >&2
    return 1
}

wait_for_text_capture() {
    local db_path="$1"
    local text_marker="$2"
    local escaped_text
    local attempt
    local count
    escaped_text="$(sql_escape "$text_marker")"

    for attempt in {1..30}; do
        printf "%s" "$text_marker" | pbcopy
        sleep 1
        count="$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_type = 'text' AND text_content = '$escaped_text';")"
        if [[ "${count:-0}" -gt 0 ]]; then
            echo "Verified: text clipboard capture"
            return 0
        fi
    done

    echo "Timed out waiting for: text clipboard capture" >&2
    return 1
}

wait_for_image_capture() {
    local db_path="$1"
    local image_path="$2"
    local image_before_id="$3"
    local attempt
    local count

    for attempt in {1..30}; do
        osascript -e "set the clipboard to (read (POSIX file \"$image_path\") as «class PNGf»)" >/dev/null
        sleep 1
        count="$(
            sqlite3 "$db_path" \
                "SELECT COUNT(*) FROM clipboard_history WHERE content_type = 'image' AND id > $image_before_id AND file_path IS NOT NULL AND thumbnail_path IS NOT NULL;"
        )"
        if [[ "${count:-0}" -gt 0 ]]; then
            echo "Verified: image clipboard capture with files"
            return 0
        fi
    done

    echo "Timed out waiting for: image clipboard capture with files" >&2
    return 1
}

cleanup_test_records() {
    local db_path="$1"
    local text_marker="$2"
    local image_id="$3"
    local escaped_text
    escaped_text="$(sql_escape "$text_marker")"

    sqlite3 "$db_path" "DELETE FROM clipboard_history WHERE text_content = '$escaped_text';" || true

    if [[ -n "$image_id" ]]; then
        while IFS='|' read -r file_path thumbnail_path; do
            [[ -n "${file_path:-}" ]] && rm -f "$file_path"
            [[ -n "${thumbnail_path:-}" ]] && rm -f "$thumbnail_path"
        done < <(sqlite3 "$db_path" "SELECT COALESCE(file_path, ''), COALESCE(thumbnail_path, '') FROM clipboard_history WHERE id = $image_id;")
        sqlite3 "$db_path" "DELETE FROM clipboard_history WHERE id = $image_id;" || true
    fi
}

require_command xcodegen
require_command xcodebuild
require_command sqlite3
require_command osascript
require_command pbcopy
require_command codesign
require_command plutil
require_command base64
require_command python3

echo "Generating Xcode project..."
xcodegen generate >/dev/null

echo "Building Release app..."
xcodebuild \
    -project MacPasteHistory.xcodeproj \
    -scheme "$SCHEME" \
    -configuration Release \
    -destination 'platform=macOS,arch=arm64' \
    build >/tmp/macpastehistory-release-smoke-build.log

build_settings="$(xcodebuild -project MacPasteHistory.xcodeproj -scheme "$SCHEME" -configuration Release -showBuildSettings)"
built_products_dir="$(printf "%s\n" "$build_settings" | awk -F ' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / {print $2; exit}')"
full_product_name="$(printf "%s\n" "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / {print $2; exit}')"
app_path="$built_products_dir/$full_product_name"

if [[ ! -d "$app_path" ]]; then
    echo "Release app not found at $app_path" >&2
    exit 1
fi

echo "Release app: $app_path"
codesign -d --entitlements :- "$app_path" 2>/dev/null | plutil -p - | grep -q '"com.apple.security.app-sandbox" => true'
echo "Verified: Release app has App Sandbox entitlement"

signature_summary="$(codesign -dvv "$app_path" 2>&1 | awk -F= '/^(Signature|TeamIdentifier)=/ {print $0}')"
echo "$signature_summary"

run_marker="MacPasteHistory release smoke $(date +%Y%m%d%H%M%S) $$"
text_marker="$run_marker text"
large_text_path="$(mktemp /tmp/macpastehistory-large-text.XXXXXX.txt)"
image_path="$(mktemp /tmp/macpastehistory-smoke.XXXXXX.png)"
large_image_path="$(mktemp /tmp/macpastehistory-large-image.XXXXXX.png)"
image_id=""
large_image_id=""

trap 'quit_app; rm -f "$large_text_path" "$image_path" "$large_image_path"' EXIT

printf "%s" "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l1sMngAAAABJRU5ErkJggg==" | base64 -D > "$image_path"
python3 - "$large_text_path" "$large_image_path" "$run_marker" <<'PY'
import binascii
import pathlib
import struct
import sys
import zlib

text_path = pathlib.Path(sys.argv[1])
image_path = pathlib.Path(sys.argv[2])
run_marker = sys.argv[3]

lines = [f"{run_marker} large text line {index:04d} sample content for release QA." for index in range(900)]
text_path.write_text("\n".join(lines), encoding="utf-8")

width = 1024
height = 768
seed = sum(run_marker.encode("utf-8")) % 256
rows = []
for y in range(height):
    row = bytearray()
    for x in range(width):
        row.extend(((x + seed) % 256, (y + seed) % 256, (x + y + seed) % 256))
    rows.append(b"\x00" + bytes(row))

def chunk(chunk_type: bytes, data: bytes) -> bytes:
    checksum = binascii.crc32(chunk_type + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", checksum)

png = (
    b"\x89PNG\r\n\x1a\n"
    + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
    + chunk(b"IDAT", zlib.compress(b"".join(rows), 6))
    + chunk(b"IEND", b"")
)
image_path.write_bytes(png)
PY

quit_app
wait_for_exit || true

echo "Launching Release app..."
open -n "$app_path"
wait_for_process
db_path="$(wait_for_database)"
echo "Database: $db_path"

echo "Writing test text to clipboard..."
wait_for_text_capture "$db_path" "$text_marker"

large_text_marker="$(cat "$large_text_path")"
echo "Writing large test text to clipboard..."
wait_for_text_capture "$db_path" "$large_text_marker"
large_text_length="$(sqlite3 "$db_path" "SELECT text_length FROM clipboard_history WHERE text_content = '$(sql_escape "$large_text_marker")' LIMIT 1;")"
if [[ "${large_text_length:-0}" -lt 50000 ]]; then
    echo "Large text record was shorter than expected: ${large_text_length:-0}" >&2
    exit 1
fi
echo "Verified: large text clipboard capture (${large_text_length} characters)"

image_before_id="$(sqlite3 "$db_path" "SELECT COALESCE(MAX(id), 0) FROM clipboard_history WHERE content_type = 'image';")"
echo "Writing test PNG to clipboard..."
wait_for_image_capture "$db_path" "$image_path" "$image_before_id"
image_id="$(sqlite3 "$db_path" "SELECT id FROM clipboard_history WHERE content_type = 'image' AND id > $image_before_id ORDER BY id DESC LIMIT 1;")"

large_image_before_id="$(sqlite3 "$db_path" "SELECT COALESCE(MAX(id), 0) FROM clipboard_history WHERE content_type = 'image';")"
echo "Writing large test PNG to clipboard..."
wait_for_image_capture "$db_path" "$large_image_path" "$large_image_before_id"
large_image_id="$(sqlite3 "$db_path" "SELECT id FROM clipboard_history WHERE content_type = 'image' AND id > $large_image_before_id ORDER BY id DESC LIMIT 1;")"
large_image_dimensions="$(
    sqlite3 "$db_path" \
        "SELECT COALESCE(image_width, 0) || 'x' || COALESCE(image_height, 0) FROM clipboard_history WHERE id = $large_image_id;"
)"
if [[ "$large_image_dimensions" != "1024x768" ]]; then
    echo "Large image dimensions were not persisted as expected: $large_image_dimensions" >&2
    exit 1
fi
echo "Verified: large image clipboard capture ($large_image_dimensions)"

echo "Quitting Release app..."
quit_app
wait_for_exit

cleanup_test_records "$db_path" "$text_marker" "$image_id"
cleanup_test_records "$db_path" "$large_text_marker" "$large_image_id"

app_support_dir="$(dirname "$db_path")"
expired_original="$app_support_dir/images/${run_marker// /_}_expired.png"
expired_thumbnail="$app_support_dir/thumbnails/${run_marker// /_}_expired.png"
mkdir -p "$(dirname "$expired_original")" "$(dirname "$expired_thumbnail")"
printf "expired original" > "$expired_original"
printf "expired thumbnail" > "$expired_thumbnail"
expired_hash="expired-${run_marker//[^A-Za-z0-9]/-}"
sqlite3 "$db_path" \
    "INSERT INTO clipboard_history (content_type, file_path, thumbnail_path, content_hash, file_size, image_width, image_height, image_format, created_at, updated_at) VALUES ('image', '$(sql_escape "$expired_original")', '$(sql_escape "$expired_thumbnail")', '$(sql_escape "$expired_hash")', 16, 16, 16, 'png', datetime('now', '-31 days'), datetime('now', '-31 days'));"
expired_id="$(sqlite3 "$db_path" "SELECT id FROM clipboard_history WHERE content_hash = '$(sql_escape "$expired_hash")' LIMIT 1;")"

echo "Launching Release app for cleanup verification..."
open -n "$app_path"
wait_for_process
for attempt in {1..30}; do
    expired_count="$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE id = $expired_id;")"
    if [[ "$expired_count" -eq 0 && ! -e "$expired_original" && ! -e "$expired_thumbnail" ]]; then
        echo "Verified: expired image database record and files are cleaned on startup"
        break
    fi
    sleep 1
done
if [[ -e "$expired_original" || -e "$expired_thumbnail" ]]; then
    echo "Expired image files were not cleaned." >&2
    exit 1
fi
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE id = $expired_id;")" -ne 0 ]]; then
    echo "Expired image database record was not cleaned." >&2
    exit 1
fi
quit_app
wait_for_exit

echo "Release smoke test passed."
