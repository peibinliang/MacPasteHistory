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

text_marker="MacPasteHistory release smoke $(date +%Y%m%d%H%M%S) $$"
image_path="$(mktemp /tmp/macpastehistory-smoke.XXXXXX.png)"
image_id=""

trap 'quit_app; rm -f "$image_path"' EXIT

printf "%s" "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAFgwJ/l1sMngAAAABJRU5ErkJggg==" | base64 -D > "$image_path"

quit_app
wait_for_exit || true

echo "Launching Release app..."
open -n "$app_path"
wait_for_process
db_path="$(wait_for_database)"
echo "Database: $db_path"

echo "Writing test text to clipboard..."
wait_for_text_capture "$db_path" "$text_marker"

image_before_id="$(sqlite3 "$db_path" "SELECT COALESCE(MAX(id), 0) FROM clipboard_history WHERE content_type = 'image';")"
echo "Writing test PNG to clipboard..."
wait_for_image_capture "$db_path" "$image_path" "$image_before_id"
image_id="$(sqlite3 "$db_path" "SELECT id FROM clipboard_history WHERE content_type = 'image' AND id > $image_before_id ORDER BY id DESC LIMIT 1;")"

echo "Quitting Release app..."
quit_app
wait_for_exit

cleanup_test_records "$db_path" "$text_marker" "$image_id"

echo "Release smoke test passed."
