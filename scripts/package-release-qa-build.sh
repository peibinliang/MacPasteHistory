#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
OUTPUT_DIR="$REPO_ROOT/build/release-qa"

should_build=1

usage() {
    cat <<'EOF'
Usage: scripts/package-release-qa-build.sh [options]

Build and package a Release app zip for manual QA on other Macs.

Options:
  --no-build       Reuse the existing Release build.
  --output-dir DIR Write the app copy, zip, checksum, and manifest to DIR.
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

release_app_path() {
    local build_settings built_products_dir full_product_name
    build_settings="$(
        xcodebuild \
            -project MacPasteHistory.xcodeproj \
            -scheme "$SCHEME" \
            -configuration Release \
            -destination 'generic/platform=macOS' \
            -showBuildSettings
    )"
    built_products_dir="$(printf "%s\n" "$build_settings" | awk -F ' = ' '/^[[:space:]]*BUILT_PRODUCTS_DIR = / {print $2; exit}')"
    full_product_name="$(printf "%s\n" "$build_settings" | awk -F ' = ' '/^[[:space:]]*FULL_PRODUCT_NAME = / {print $2; exit}')"
    printf "%s/%s" "$built_products_dir" "$full_product_name"
}

executable_architectures() {
    local executable_path="$1"
    if command -v lipo >/dev/null 2>&1; then
        lipo -info "$executable_path" 2>/dev/null | sed 's/^.*are: //; s/^.*architecture: //' | xargs
    else
        printf "unknown"
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --no-build)
            should_build=0
            ;;
        --output-dir)
            if [[ $# -lt 2 ]]; then
                echo "--output-dir requires a directory path" >&2
                exit 2
            fi
            OUTPUT_DIR="$2"
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

require_command awk
require_command codesign
require_command date
require_command ditto
require_command git
require_command mkdir
require_command rm
require_command shasum
require_command xcodebuild
require_command xcodegen

cd "$REPO_ROOT"

if [[ "$should_build" -eq 1 ]]; then
    echo "Validating Xcode file references..."
    scripts/validate-xcode-file-references.sh

    echo "Building generic Release app..."
    xcodebuild \
        -project MacPasteHistory.xcodeproj \
        -scheme "$SCHEME" \
        -configuration Release \
        -destination 'generic/platform=macOS' \
        build >/tmp/macpastehistory-release-qa-package-build.log
fi

app_path="$(release_app_path)"
if [[ ! -d "$app_path" ]]; then
    echo "Release app not found at $app_path" >&2
    echo "Run without --no-build to generate it." >&2
    exit 1
fi

info_plist="$app_path/Contents/Info.plist"
version="$(plist_value "$info_plist" CFBundleShortVersionString)"
build_number="$(plist_value "$info_plist" CFBundleVersion)"
git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf "unknown")"
timestamp="$(date '+%Y%m%d-%H%M%S')"
package_stem="MacPasteHistory-${version}-${build_number}-${git_commit}-${timestamp}"
package_app_name="$package_stem.app"
package_app_path="$OUTPUT_DIR/$package_app_name"
zip_name="$package_stem.zip"
zip_path="$OUTPUT_DIR/$zip_name"
checksum_path="$zip_path.sha256"
manifest_path="$OUTPUT_DIR/$package_stem-manifest.md"
executable_path="$app_path/Contents/MacOS/MacPasteHistory"
architectures="$(executable_architectures "$executable_path")"
codesign_summary="$(codesign -dvv "$app_path" 2>&1 || true)"
signature="$(printf "%s\n" "$codesign_summary" | awk -F= '/^Signature=/ {print $2; exit}')"
team_identifier="$(printf "%s\n" "$codesign_summary" | awk -F= '/^TeamIdentifier=/ {print $2; exit}')"

if [[ -z "$signature" ]]; then
    signature="unknown"
fi
if [[ -z "$team_identifier" ]]; then
    team_identifier="not set"
fi

mkdir -p "$OUTPUT_DIR"
rm -rf "$package_app_path" "$zip_path" "$checksum_path" "$manifest_path"

echo "Copying app to QA package directory..."
ditto "$app_path" "$package_app_path"

echo "Creating zip..."
(
    cd "$OUTPUT_DIR"
    ditto -c -k --keepParent "$package_app_name" "$zip_name"
)

(
    cd "$OUTPUT_DIR"
    shasum -a 256 "$zip_name" >"$(basename "$checksum_path")"
)

{
    echo "# Release QA Package"
    echo
    echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"
    echo
    echo "| Field | Value |"
    echo "|---|---|"
    echo "| Git commit | \`$git_commit\` |"
    echo "| Version / build | \`$version ($build_number)\` |"
    echo "| Source app | \`$app_path\` |"
    echo "| Packaged app | \`$package_app_path\` |"
    echo "| Zip | \`$zip_path\` |"
    echo "| SHA-256 file | \`$checksum_path\` |"
    echo "| Architectures | \`$architectures\` |"
    echo "| Signature | \`$signature\` |"
    echo "| Team identifier | \`$team_identifier\` |"
    echo
    echo "## Baseline"
    echo
    scripts/release-qa-baseline.sh --app "$package_app_path"
} >"$manifest_path"

echo "QA package created:"
echo "  App:      $package_app_path"
echo "  Zip:      $zip_path"
echo "  SHA-256:  $checksum_path"
echo "  Manifest: $manifest_path"
