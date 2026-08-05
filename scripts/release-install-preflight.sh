#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
BUNDLE_ID="com.peibin.MacPasteHistory"
APP_PROCESS_NAME="粘易"
CONTAINER_DATA_DIR="$HOME/Library/Containers/$BUNDLE_ID/Data"

should_build=1
keep_artifacts=0
app_path=""
install_root=""
installed_app_path=""
preview_data_dir=""

usage() {
    cat <<'EOF'
Usage: scripts/release-install-preflight.sh [options]

Copy the Release app to a temporary install directory, launch it with isolated
App Support data, verify local storage initialization, then quit it.

Options:
  --app PATH    Use a specific .app bundle instead of the current Release build.
  --no-build    Reuse the existing Release build.
  --keep        Keep the temporary install and data directories.
  -h, --help    Show this help.
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
    for attempt in {1..20}; do
        if ! pgrep -x "$APP_PROCESS_NAME" >/dev/null 2>&1; then
            return 0
        fi
        sleep 1
    done
    echo "App process did not exit within timeout." >&2
    return 1
}

wait_for_database() {
    local db_path="$1"
    local attempt
    for attempt in {1..30}; do
        if [[ -f "$db_path" ]]; then
            return 0
        fi
        sleep 1
    done
    echo "Database was not created within timeout: $db_path" >&2
    return 1
}

cleanup() {
    quit_app
    wait_for_exit >/dev/null 2>&1 || true
    launchctl unsetenv MACPASTEHISTORY_APP_SUPPORT_DIR >/dev/null 2>&1 || true
    if [[ "$keep_artifacts" -eq 0 ]]; then
        if [[ -n "${install_root:-}" && -d "$install_root" ]]; then
            rm -rf "$install_root"
        fi
        if [[ -n "${preview_data_dir:-}" && -d "$preview_data_dir" ]]; then
            rm -rf "$preview_data_dir"
        fi
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --app)
            if [[ $# -lt 2 ]]; then
                echo "--app requires a path" >&2
                exit 2
            fi
            app_path="$2"
            should_build=0
            shift
            ;;
        --no-build)
            should_build=0
            ;;
        --keep)
            keep_artifacts=1
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
require_command ditto
require_command mkdir
require_command open
require_command osascript
require_command pgrep
require_command rm
require_command sqlite3
require_command launchctl
require_command xcodebuild

cd "$REPO_ROOT"

if [[ "$should_build" -eq 1 ]]; then
    scripts/preview-release-app.sh --build-only >/tmp/macpastehistory-install-preflight-build.log
fi

if [[ -z "$app_path" ]]; then
    app_path="$(release_app_path)"
fi

if [[ ! -d "$app_path" ]]; then
    echo "Release app not found at $app_path" >&2
    echo "Run without --no-build to generate it, or pass --app <path>." >&2
    exit 1
fi

trap cleanup EXIT

install_root="$(mktemp -d /tmp/macpastehistory-release-install-preflight.XXXXXX)"
installed_app_path="$install_root/粘易.app"
mkdir -p "$CONTAINER_DATA_DIR"
preview_data_dir="$(mktemp -d "$CONTAINER_DATA_DIR/install-preflight-data.XXXXXX")"
db_path="$preview_data_dir/clipboard.db"

mkdir -p "$preview_data_dir"

quit_app
wait_for_exit >/dev/null 2>&1 || true

ditto "$app_path" "$installed_app_path"

info_plist="$installed_app_path/Contents/Info.plist"
version="$(plist_value "$info_plist" CFBundleShortVersionString)"
build_number="$(plist_value "$info_plist" CFBundleVersion)"
bundle_id="$(plist_value "$info_plist" CFBundleIdentifier)"
lsui_element="$(plist_value "$info_plist" LSUIElement)"

launchctl setenv MACPASTEHISTORY_APP_SUPPORT_DIR "$preview_data_dir"
open -n "$installed_app_path"
wait_for_process
wait_for_database "$db_path"

schema_count="$(sqlite3 "$db_path" "SELECT COUNT(*) FROM sqlite_master WHERE type = 'table' AND name IN ('clipboard_history', 'schema_migrations');")"
if [[ "$schema_count" -ne 2 ]]; then
    echo "Expected clipboard_history and schema_migrations tables, found $schema_count" >&2
    exit 1
fi

quit_app
wait_for_exit

echo "# Release Install Preflight"
echo
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Source app | \`$app_path\` |"
echo "| Installed app copy | \`$installed_app_path\` |"
echo "| Isolated App Support | \`$preview_data_dir\` |"
echo "| Database | \`$db_path\` |"
echo "| Bundle identifier | \`$bundle_id\` |"
echo "| Version / build | \`$version ($build_number)\` |"
echo "| LSUIElement | \`$lsui_element\` |"
echo "| SQLite schema tables | \`$schema_count\` |"
echo "| Process exit after quit | \`confirmed\` |"
echo
echo "Status: PASS"

if [[ "$keep_artifacts" -eq 1 ]]; then
    echo
    echo "Kept artifacts for inspection:"
    echo "- $install_root"
fi
