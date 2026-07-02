#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
BUNDLE_ID="com.peibin.MacPasteHistory"
APP_PROCESS_NAME="MacPasteHistory"
DB_RELATIVE_PATH="Library/Application Support/MacPasteHistory/clipboard.db"
CONTAINER_DATA_DIR="$HOME/Library/Containers/$BUNDLE_ID/Data"
CONTAINER_PREFERENCES_DIR="$CONTAINER_DATA_DIR/Library/Preferences"
CONTAINER_PREFERENCES_DOMAIN="$CONTAINER_PREFERENCES_DIR/$BUNDLE_ID"

cleanup_defaults_saved=0
install_dir=""
test_app_support_dir=""

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

set_cleanup_default() {
    local key="$1"
    local value="$2"
    mkdir -p "$CONTAINER_PREFERENCES_DIR"
    defaults write "$BUNDLE_ID" "$key" -int "$value"
    defaults write "$CONTAINER_PREFERENCES_DOMAIN" "$key" -int "$value"
    defaults read "$BUNDLE_ID" "$key" >/dev/null
    defaults read "$CONTAINER_PREFERENCES_DOMAIN" "$key" >/dev/null
}

flush_defaults_cache() {
    killall cfprefsd >/dev/null 2>&1 || true
}

save_cleanup_defaults() {
    cleanup_defaults_saved=1
    original_max_text_set=0
    original_max_image_set=0
    original_max_image_size_set=0
    original_storage_cap_set=0

    if original_max_text="$(defaults read "$BUNDLE_ID" config.maxTextHistoryCount 2>/dev/null)"; then
        original_max_text_set=1
    fi
    if original_max_image="$(defaults read "$BUNDLE_ID" config.maxImageHistoryCount 2>/dev/null)"; then
        original_max_image_set=1
    fi
    if original_max_image_size="$(defaults read "$BUNDLE_ID" config.maxImageSizeInBytes 2>/dev/null)"; then
        original_max_image_size_set=1
    fi
    if original_storage_cap="$(defaults read "$BUNDLE_ID" config.totalStorageCapInBytes 2>/dev/null)"; then
        original_storage_cap_set=1
    fi
}

restore_cleanup_defaults() {
    if [[ "$cleanup_defaults_saved" -ne 1 ]]; then
        return
    fi

    if [[ "${original_max_text_set:-0}" -eq 1 ]]; then
        defaults write "$BUNDLE_ID" config.maxTextHistoryCount -int "$original_max_text"
    else
        defaults delete "$BUNDLE_ID" config.maxTextHistoryCount >/dev/null 2>&1 || true
    fi
    defaults delete "$CONTAINER_PREFERENCES_DOMAIN" config.maxTextHistoryCount >/dev/null 2>&1 || true

    if [[ "${original_max_image_set:-0}" -eq 1 ]]; then
        defaults write "$BUNDLE_ID" config.maxImageHistoryCount -int "$original_max_image"
    else
        defaults delete "$BUNDLE_ID" config.maxImageHistoryCount >/dev/null 2>&1 || true
    fi
    defaults delete "$CONTAINER_PREFERENCES_DOMAIN" config.maxImageHistoryCount >/dev/null 2>&1 || true

    if [[ "${original_max_image_size_set:-0}" -eq 1 ]]; then
        defaults write "$BUNDLE_ID" config.maxImageSizeInBytes -int "$original_max_image_size"
    else
        defaults delete "$BUNDLE_ID" config.maxImageSizeInBytes >/dev/null 2>&1 || true
    fi
    defaults delete "$CONTAINER_PREFERENCES_DOMAIN" config.maxImageSizeInBytes >/dev/null 2>&1 || true

    if [[ "${original_storage_cap_set:-0}" -eq 1 ]]; then
        defaults write "$BUNDLE_ID" config.totalStorageCapInBytes -int "$original_storage_cap"
    else
        defaults delete "$BUNDLE_ID" config.totalStorageCapInBytes >/dev/null 2>&1 || true
    fi
    defaults delete "$CONTAINER_PREFERENCES_DOMAIN" config.totalStorageCapInBytes >/dev/null 2>&1 || true
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

launch_app() {
    launchctl setenv MACPASTEHISTORY_APP_SUPPORT_DIR "$test_app_support_dir"
    open -n "$app_path"
}

find_database() {
    local override_db="$test_app_support_dir/clipboard.db"
    local sandbox_db="$HOME/Library/Containers/$BUNDLE_ID/Data/$DB_RELATIVE_PATH"
    local unsandboxed_db="$HOME/$DB_RELATIVE_PATH"

    if [[ -n "${test_app_support_dir:-}" ]]; then
        if [[ -f "$override_db" ]]; then
            printf "%s\n" "$override_db"
            return 0
        fi
        return 1
    fi

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

verify_image_skip() {
    local db_path="$1"
    local image_path="$2"
    local image_before_id="$3"
    local expected_hash="$4"
    local app_support_dir="$5"
    local attempt
    local count

    for attempt in {1..8}; do
        osascript -e "set the clipboard to (read (POSIX file \"$image_path\") as «class PNGf»)" >/dev/null
        sleep 1
        count="$(
            sqlite3 "$db_path" \
                "SELECT COUNT(*) FROM clipboard_history WHERE content_type = 'image' AND id > $image_before_id;"
        )"
        if [[ "${count:-0}" -ne 0 ]]; then
            echo "Oversized image was unexpectedly saved." >&2
            return 1
        fi
    done

    if [[ -e "$app_support_dir/images/$expected_hash.png" || -e "$app_support_dir/thumbnails/$expected_hash.png" ]]; then
        echo "Oversized image left residual files." >&2
        return 1
    fi

    echo "Verified: oversized image is skipped without database records or files"
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

reset_controlled_history_state() {
    local db_path="$1"
    local app_support_dir
    app_support_dir="$(dirname "$db_path")"
    sqlite3 "$db_path" "DELETE FROM clipboard_history;"
    rm -rf "$app_support_dir/images" "$app_support_dir/thumbnails"
    mkdir -p "$app_support_dir/images" "$app_support_dir/thumbnails"
}

create_sized_file() {
    local path="$1"
    local size="$2"
    python3 - "$path" "$size" <<'PY'
import pathlib
import sys

path = pathlib.Path(sys.argv[1])
size = int(sys.argv[2])
path.write_bytes(b"x" * size)
PY
}

insert_text_cleanup_record() {
    local db_path="$1"
    local text="$2"
    local hash="$3"
    local days_ago="$4"
    local favorite="$5"
    sqlite3 "$db_path" \
        "INSERT INTO clipboard_history (content_type, text_content, content_hash, text_length, is_favorite, created_at, updated_at) VALUES ('text', '$(sql_escape "$text")', '$(sql_escape "$hash")', ${#text}, $favorite, datetime('now', '-$days_ago days'), datetime('now', '-$days_ago days'));"
}

insert_image_cleanup_record() {
    local db_path="$1"
    local file_path="$2"
    local thumbnail_path="$3"
    local hash="$4"
    local file_size="$5"
    local days_ago="$6"
    local favorite="$7"
    sqlite3 "$db_path" \
        "INSERT INTO clipboard_history (content_type, file_path, thumbnail_path, content_hash, file_size, image_width, image_height, image_format, is_favorite, created_at, updated_at) VALUES ('image', '$(sql_escape "$file_path")', '$(sql_escape "$thumbnail_path")', '$(sql_escape "$hash")', $file_size, 16, 16, 'png', $favorite, datetime('now', '-$days_ago days'), datetime('now', '-$days_ago days'));"
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
require_command ditto
require_command defaults
require_command killall
require_command launchctl

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

install_dir="$(mktemp -d /tmp/macpastehistory-release-install.XXXXXX)"
installed_app_path="$install_dir/$full_product_name"
ditto "$app_path" "$installed_app_path"
app_path="$installed_app_path"
mkdir -p "$CONTAINER_DATA_DIR"
test_app_support_dir="$(mktemp -d "$CONTAINER_DATA_DIR/release-smoke-data.XXXXXX")"
echo "Installed Release app copy: $app_path"
echo "Using isolated app data: $test_app_support_dir"

run_marker="MacPasteHistory release smoke $(date +%Y%m%d%H%M%S) $$"
text_marker="$run_marker text"
large_text_path="$(mktemp /tmp/macpastehistory-large-text.XXXXXX.txt)"
image_path="$(mktemp /tmp/macpastehistory-smoke.XXXXXX.png)"
large_image_path="$(mktemp /tmp/macpastehistory-large-image.XXXXXX.png)"
oversized_image_path="$(mktemp /tmp/macpastehistory-oversized-image.XXXXXX.png)"
image_id=""
large_image_id=""

trap 'quit_app; launchctl unsetenv MACPASTEHISTORY_APP_SUPPORT_DIR >/dev/null 2>&1 || true; restore_cleanup_defaults; rm -f "$large_text_path" "$image_path" "$large_image_path" "$oversized_image_path"; [[ -n "${install_dir:-}" ]] && rm -rf "$install_dir"; [[ -n "${test_app_support_dir:-}" ]] && rm -rf "$test_app_support_dir"' EXIT

printf "%s" "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l1sMngAAAABJRU5ErkJggg==" | base64 -D > "$image_path"
python3 - "$large_text_path" "$large_image_path" "$oversized_image_path" "$run_marker" <<'PY'
import binascii
import pathlib
import struct
import sys
import zlib

text_path = pathlib.Path(sys.argv[1])
large_image_path = pathlib.Path(sys.argv[2])
oversized_image_path = pathlib.Path(sys.argv[3])
run_marker = sys.argv[4]

lines = [f"{run_marker} large text line {index:04d} sample content for release QA." for index in range(900)]
text_path.write_text("\n".join(lines), encoding="utf-8")

seed = sum(run_marker.encode("utf-8")) % 256

def chunk(chunk_type: bytes, data: bytes) -> bytes:
    checksum = binascii.crc32(chunk_type + data) & 0xFFFFFFFF
    return struct.pack(">I", len(data)) + chunk_type + data + struct.pack(">I", checksum)

def write_png(path: pathlib.Path, width: int, height: int, color_seed: int) -> None:
    rows = []
    for y in range(height):
        row = bytearray()
        for x in range(width):
            row.extend(((x + color_seed) % 256, (y + color_seed) % 256, (x + y + color_seed) % 256))
        rows.append(b"\x00" + bytes(row))
    png = (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(b"".join(rows), 6))
        + chunk(b"IEND", b"")
    )
    path.write_bytes(png)

write_png(large_image_path, 1024, 768, seed)
write_png(oversized_image_path, 640, 480, (seed + 97) % 256)
PY

quit_app
wait_for_exit || true

echo "Launching Release app..."
launch_app
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

save_cleanup_defaults
set_cleanup_default config.maxImageSizeInBytes 1
flush_defaults_cache
oversized_before_id="$(sqlite3 "$db_path" "SELECT COALESCE(MAX(id), 0) FROM clipboard_history WHERE content_type = 'image';")"
oversized_hash="$(shasum -a 256 "$oversized_image_path" | awk '{print $1}')"
app_support_dir="$(dirname "$db_path")"
echo "Writing oversized PNG to clipboard..."
verify_image_skip "$db_path" "$oversized_image_path" "$oversized_before_id" "$oversized_hash" "$app_support_dir"
restore_cleanup_defaults
flush_defaults_cache

echo "Quitting Release app..."
quit_app
wait_for_exit

echo "Launching Release app for restart persistence verification..."
launch_app
wait_for_process
restart_text_count="$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_type = 'text' AND text_content = '$(sql_escape "$text_marker")';")"
restart_large_image_count="$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE id = $large_image_id;")"
if [[ "$restart_text_count" -lt 1 || "$restart_large_image_count" -lt 1 ]]; then
    echo "History records were not available after restart." >&2
    exit 1
fi
echo "Verified: history remains available after Release app restart"
quit_app
wait_for_exit

cleanup_test_records "$db_path" "$text_marker" "$image_id"
cleanup_test_records "$db_path" "$large_text_marker" "$large_image_id"

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
launch_app
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

echo "Using isolated app data for controlled cleanup-limit verification..."
save_cleanup_defaults

reset_controlled_history_state "$db_path"
set_cleanup_default config.maxTextHistoryCount 2
set_cleanup_default config.maxImageHistoryCount 2
set_cleanup_default config.totalStorageCapInBytes 1000000
flush_defaults_cache
echo "Cleanup limits: text=$(defaults read "$CONTAINER_PREFERENCES_DOMAIN" config.maxTextHistoryCount), image=$(defaults read "$CONTAINER_PREFERENCES_DOMAIN" config.maxImageHistoryCount), storage=$(defaults read "$CONTAINER_PREFERENCES_DOMAIN" config.totalStorageCapInBytes)"

count_old_text="$run_marker cleanup old text"
count_favorite_text="$run_marker cleanup favorite text"
count_new_text="$run_marker cleanup new text"
insert_text_cleanup_record "$db_path" "$count_old_text" "count-old-text-${run_marker//[^A-Za-z0-9]/-}" 3 0
insert_text_cleanup_record "$db_path" "$count_favorite_text" "count-favorite-text-${run_marker//[^A-Za-z0-9]/-}" 2 1
insert_text_cleanup_record "$db_path" "$count_new_text" "count-new-text-${run_marker//[^A-Za-z0-9]/-}" 1 0

count_old_image="$app_support_dir/images/${run_marker// /_}_count_old.png"
count_old_thumb="$app_support_dir/thumbnails/${run_marker// /_}_count_old.png"
count_favorite_image="$app_support_dir/images/${run_marker// /_}_count_favorite.png"
count_favorite_thumb="$app_support_dir/thumbnails/${run_marker// /_}_count_favorite.png"
count_new_image="$app_support_dir/images/${run_marker// /_}_count_new.png"
count_new_thumb="$app_support_dir/thumbnails/${run_marker// /_}_count_new.png"
create_sized_file "$count_old_image" 100
create_sized_file "$count_old_thumb" 8
create_sized_file "$count_favorite_image" 100
create_sized_file "$count_favorite_thumb" 8
create_sized_file "$count_new_image" 100
create_sized_file "$count_new_thumb" 8
insert_image_cleanup_record "$db_path" "$count_old_image" "$count_old_thumb" "count-old-image-${run_marker//[^A-Za-z0-9]/-}" 100 3 0
insert_image_cleanup_record "$db_path" "$count_favorite_image" "$count_favorite_thumb" "count-favorite-image-${run_marker//[^A-Za-z0-9]/-}" 100 2 1
insert_image_cleanup_record "$db_path" "$count_new_image" "$count_new_thumb" "count-new-image-${run_marker//[^A-Za-z0-9]/-}" 100 1 0

echo "Launching Release app for count-limit cleanup verification..."
launch_app
wait_for_process
for attempt in {1..30}; do
    old_text_count="$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE text_content = '$(sql_escape "$count_old_text")';")"
    old_image_count="$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_hash = 'count-old-image-${run_marker//[^A-Za-z0-9]/-}';")"
    if [[ "$old_text_count" -eq 0 && "$old_image_count" -eq 0 && ! -e "$count_old_image" && ! -e "$count_old_thumb" ]]; then
        break
    fi
    sleep 1
done
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE text_content = '$(sql_escape "$count_old_text")';")" -ne 0 ]]; then
    echo "Old text record was not trimmed by count-limit cleanup." >&2
    exit 1
fi
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE text_content = '$(sql_escape "$count_favorite_text")';")" -ne 1 ]]; then
    echo "Favorite text record was not preserved by count-limit cleanup." >&2
    exit 1
fi
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE text_content = '$(sql_escape "$count_new_text")';")" -ne 1 ]]; then
    echo "Newest text record was not preserved by count-limit cleanup." >&2
    exit 1
fi
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_hash = 'count-old-image-${run_marker//[^A-Za-z0-9]/-}';")" -ne 0 || -e "$count_old_image" || -e "$count_old_thumb" ]]; then
    echo "Old image record or files were not trimmed by count-limit cleanup." >&2
    exit 1
fi
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_hash = 'count-favorite-image-${run_marker//[^A-Za-z0-9]/-}';")" -ne 1 || ! -e "$count_favorite_image" ]]; then
    echo "Favorite image record was not preserved by count-limit cleanup." >&2
    exit 1
fi
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_hash = 'count-new-image-${run_marker//[^A-Za-z0-9]/-}';")" -ne 1 || ! -e "$count_new_image" ]]; then
    echo "Newest image record was not preserved by count-limit cleanup." >&2
    exit 1
fi
echo "Verified: Release startup trims text/image count limits while preserving favorites"
quit_app
wait_for_exit

reset_controlled_history_state "$db_path"
set_cleanup_default config.maxTextHistoryCount 500
set_cleanup_default config.maxImageHistoryCount 200
set_cleanup_default config.totalStorageCapInBytes 250
flush_defaults_cache
echo "Cleanup limits: text=$(defaults read "$CONTAINER_PREFERENCES_DOMAIN" config.maxTextHistoryCount), image=$(defaults read "$CONTAINER_PREFERENCES_DOMAIN" config.maxImageHistoryCount), storage=$(defaults read "$CONTAINER_PREFERENCES_DOMAIN" config.totalStorageCapInBytes)"
storage_old_image="$app_support_dir/images/${run_marker// /_}_storage_old.png"
storage_old_thumb="$app_support_dir/thumbnails/${run_marker// /_}_storage_old.png"
storage_new_image="$app_support_dir/images/${run_marker// /_}_storage_new.png"
storage_new_thumb="$app_support_dir/thumbnails/${run_marker// /_}_storage_new.png"
create_sized_file "$storage_old_image" 200
create_sized_file "$storage_old_thumb" 8
create_sized_file "$storage_new_image" 200
create_sized_file "$storage_new_thumb" 8
insert_image_cleanup_record "$db_path" "$storage_old_image" "$storage_old_thumb" "storage-old-image-${run_marker//[^A-Za-z0-9]/-}" 200 2 0
insert_image_cleanup_record "$db_path" "$storage_new_image" "$storage_new_thumb" "storage-new-image-${run_marker//[^A-Za-z0-9]/-}" 200 1 0

echo "Launching Release app for storage-limit cleanup verification..."
launch_app
wait_for_process
for attempt in {1..30}; do
    storage_old_count="$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_hash = 'storage-old-image-${run_marker//[^A-Za-z0-9]/-}';")"
    if [[ "$storage_old_count" -eq 0 && ! -e "$storage_old_image" && ! -e "$storage_old_thumb" ]]; then
        break
    fi
    sleep 1
done
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_hash = 'storage-old-image-${run_marker//[^A-Za-z0-9]/-}';")" -ne 0 || -e "$storage_old_image" || -e "$storage_old_thumb" ]]; then
    echo "Old image record or files were not evicted by storage-limit cleanup." >&2
    exit 1
fi
if [[ "$(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_hash = 'storage-new-image-${run_marker//[^A-Za-z0-9]/-}';")" -ne 1 || ! -e "$storage_new_image" || ! -e "$storage_new_thumb" ]]; then
    echo "Newest image record was not preserved by storage-limit cleanup." >&2
    exit 1
fi
echo "Verified: Release startup evicts images beyond storage limit and removes files"
quit_app
wait_for_exit

restore_cleanup_defaults

echo "Release smoke test passed."
