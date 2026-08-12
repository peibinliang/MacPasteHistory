#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
BUNDLE_ID="com.peibin.MacPasteHistory"
CONTAINER_DATA_DIR="$HOME/Library/Containers/$BUNDLE_ID/Data"

should_build=1
should_open=1
use_isolated_data=0
seed_preview_data=0
open_history=0

usage() {
    cat <<'EOF'
Usage: scripts/preview-release-app.sh [options]

Build and preview the current Release app.

Options:
  --build-only     Build Release and print the app path without opening it.
  --no-build       Reuse the existing Release build.
  --isolated-data  Launch with a temporary isolated App Support directory.
  --seed-preview-data
                  Seed isolated preview data before launching. Implies --isolated-data.
  --open-history  Open the history window on launch. Implies --isolated-data.
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
        --seed-preview-data)
            use_isolated_data=1
            seed_preview_data=1
            ;;
        --open-history)
            use_isolated_data=1
            open_history=1
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
    preview_session_name="$(basename "$preview_data_dir")"
    preview_defaults_suite="com.peibin.MacPasteHistory.qa.$preview_session_name"
    echo "Using isolated preview data: $preview_data_dir"
    echo "Using isolated preview preferences: $preview_defaults_suite"
    if [[ "$seed_preview_data" -eq 1 ]]; then
        echo "Seeding synthetic preview history..."
        scripts/seed-preview-data.sh "$preview_data_dir"
    fi
    open_args=(
        -n
        --env "MACPASTEHISTORY_APP_SUPPORT_DIR=$preview_data_dir"
        --env "MACPASTEHISTORY_USER_DEFAULTS_SUITE=$preview_defaults_suite"
    )
    if [[ "$open_history" -eq 1 ]]; then
        open_args+=(--env "MACPASTEHISTORY_OPEN_HISTORY_ON_LAUNCH=1")
    fi
    open "${open_args[@]}" "$app_path"
else
    open "$app_path"
fi

echo "Preview launched."
