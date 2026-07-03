#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
BUNDLE_ID="com.peibin.MacPasteHistory"
CONTAINER_DATA_DIR="$HOME/Library/Containers/$BUNDLE_ID/Data"

should_build=1
should_open=1
use_isolated_data=0

usage() {
    cat <<'EOF'
Usage: scripts/preview-release-app.sh [options]

Build and preview the current Release app.

Options:
  --build-only     Build Release and print the app path without opening it.
  --no-build       Reuse the existing Release build.
  --isolated-data  Launch with a temporary isolated App Support directory.
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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build-only)
            should_open=0
            ;;
        --no-build)
            should_build=0
            ;;
        --isolated-data)
            use_isolated_data=1
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

require_command xcodegen
require_command xcodebuild
require_command open
require_command awk

cd "$REPO_ROOT"

if [[ "$should_build" -eq 1 ]]; then
    echo "Validating Xcode file references..."
    scripts/validate-xcode-file-references.sh

    echo "Building Release app..."
    xcodebuild \
        -project MacPasteHistory.xcodeproj \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination 'platform=macOS,arch=arm64' \
        build >/tmp/macpastehistory-preview-release-build.log
fi

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
app_path="$built_products_dir/$full_product_name"

if [[ ! -d "$app_path" ]]; then
    echo "Release app not found at $app_path" >&2
    echo "Run without --no-build to generate it." >&2
    exit 1
fi

echo "Release app: $app_path"

if [[ "$should_open" -eq 0 ]]; then
    exit 0
fi

if [[ "$use_isolated_data" -eq 1 ]]; then
    mkdir -p "$CONTAINER_DATA_DIR"
    preview_data_dir="$(mktemp -d "$CONTAINER_DATA_DIR/manual-preview-data.XXXXXX")"
    echo "Using isolated preview data: $preview_data_dir"
    open -n --env "MACPASTEHISTORY_APP_SUPPORT_DIR=$preview_data_dir" "$app_path"
else
    open "$app_path"
fi

echo "Preview launched."
