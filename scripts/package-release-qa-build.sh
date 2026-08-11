#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
OUTPUT_DIR="$REPO_ROOT/build/release-qa"

should_build=1
formal_update=0
explicit_app_path=""
release_notes_path=""
output_dir_explicit=0
formal_stage_dir=""

usage() {
    cat <<'EOF'
Usage: scripts/package-release-qa-build.sh [options]

Build and package a Release app zip for manual QA on other Macs.

Options:
  --no-build          Reuse the existing Release build.
  --output-dir DIR    Write package artifacts to DIR.
  --formal-update     Package a Developer ID signed and notarized Sparkle update.
  --app PATH          Explicit .app input for --formal-update; no discovery occurs.
  --release-notes FILE
                      Explicit non-empty Markdown release notes for formal mode.
  -h, --help          Show this help.
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

cleanup_formal_stage() {
    if [[ -z "$formal_stage_dir" || ! -d "$formal_stage_dir" ]]; then
        return
    fi
    case "$(basename "$formal_stage_dir")" in
        .formal-update-stage.*) rm -rf "$formal_stage_dir" ;;
        *) echo "Refusing to remove unexpected formal staging directory" >&2 ;;
    esac
}

canonical_path() {
    /usr/bin/python3 - "$1" <<'PY'
import os
import sys

print(os.path.realpath(sys.argv[1]))
PY
}

package_formal_update() {
    local info_plist version build_number bundle_id
    local codesign_summary signature authority team_identifier
    local spctl_output spctl_status archive_name archive_path checksum_path release_notes_name
    local release_notes_output canonical_app canonical_output staged_archive staged_checksum staged_notes

    [[ -n "$explicit_app_path" ]] || {
        echo "--formal-update requires --app with an explicit application path" >&2
        exit 2
    }
    [[ "$output_dir_explicit" -eq 1 && -n "$OUTPUT_DIR" ]] || {
        echo "--formal-update requires --output-dir" >&2
        exit 2
    }
    while [[ "$explicit_app_path" != "/" && "$explicit_app_path" == */ ]]; do
        explicit_app_path="${explicit_app_path%/}"
    done
    [[ -d "$explicit_app_path" ]] || {
        echo "Formal update app not found: $explicit_app_path" >&2
        exit 1
    }
    [[ ! -L "$explicit_app_path" ]] || {
        echo "formal update app path must not be a symbolic link" >&2
        exit 1
    }

    canonical_app="$(canonical_path "$explicit_app_path")"
    canonical_output="$(canonical_path "$OUTPUT_DIR")"
    [[ -d "$canonical_app" && "$(basename "$canonical_app")" == "粘易.app" ]] || {
        echo "Formal update app must be a physical bundle named 粘易.app" >&2
        exit 1
    }
    if [[ "$canonical_output" == "$canonical_app" || "$canonical_output" == "$canonical_app/"* ]]; then
        echo "formal output directory must not be the app bundle or inside it" >&2
        exit 1
    fi
    explicit_app_path="$canonical_app"
    OUTPUT_DIR="$canonical_output"

    info_plist="$explicit_app_path/Contents/Info.plist"
    [[ -f "$info_plist" ]] || {
        echo "Info.plist missing from formal update app" >&2
        exit 1
    }

    version="$(plist_value "$info_plist" CFBundleShortVersionString)"
    build_number="$(plist_value "$info_plist" CFBundleVersion)"
    bundle_id="$(plist_value "$info_plist" CFBundleIdentifier)"
    [[ "$version" == "1.0.2" && "$build_number" == "3" ]] || {
        echo "Formal update app must report version 1.0.2 (3)" >&2
        exit 1
    }
    [[ "$bundle_id" == "com.peibin.MacPasteHistory" ]] || {
        echo "Formal update app has an unexpected bundle identifier" >&2
        exit 1
    }

    codesign_summary="$(codesign -dvvv "$explicit_app_path" 2>&1 || true)"
    signature="$(printf "%s\n" "$codesign_summary" | awk -F= '/^Signature=/ {print $2; exit}')"
    authority="$(printf "%s\n" "$codesign_summary" | awk -F= '/^Authority=/ {print $2; exit}')"
    team_identifier="$(printf "%s\n" "$codesign_summary" | awk -F= '/^TeamIdentifier=/ {print $2; exit}')"
    if [[ "$signature" == "adhoc" || "$authority" != "Developer ID Application:"* \
        || -z "$team_identifier" || "$team_identifier" == "not set" ]]; then
        echo "Developer ID Application signature is required; ad-hoc and other identities are refused" >&2
        exit 1
    fi
    if ! codesign --verify --deep --strict "$explicit_app_path" >/dev/null 2>&1; then
        echo "Formal update app failed strict code-signature verification" >&2
        exit 1
    fi

    set +e
    spctl_output="$(spctl --assess --type execute --verbose=4 "$explicit_app_path" 2>&1)"
    spctl_status=$?
    set -e
    if [[ "$spctl_status" -ne 0 ]] \
        || ! printf '%s\n' "$spctl_output" | grep -Fq 'source=Notarized Developer ID'; then
        echo "Formal update app is not accepted as a notarized Developer ID application by spctl" >&2
        exit 1
    fi

    "$REPO_ROOT/scripts/verify-sparkle-release-bundle.sh" "$explicit_app_path" >/dev/null

    [[ -n "$release_notes_path" ]] || {
        echo "--formal-update requires --release-notes with an explicit Markdown file" >&2
        exit 2
    }
    [[ -s "$release_notes_path" ]] || {
        echo "Formal update release notes are missing or empty" >&2
        exit 1
    }

    archive_name="粘易-1.0.2-3.zip"
    archive_path="$OUTPUT_DIR/$archive_name"
    checksum_path="$archive_path.sha256"
    release_notes_name="粘易-1.0.2-3-release-notes.md"
    release_notes_output="$OUTPUT_DIR/$release_notes_name"
    mkdir -p "$OUTPUT_DIR"
    canonical_output="$(canonical_path "$OUTPUT_DIR")"
    if [[ "$canonical_output" == "$canonical_app" || "$canonical_output" == "$canonical_app/"* ]]; then
        echo "formal output directory must not be the app bundle or inside it" >&2
        exit 1
    fi
    OUTPUT_DIR="$canonical_output"
    archive_path="$OUTPUT_DIR/$archive_name"
    checksum_path="$archive_path.sha256"
    release_notes_output="$OUTPUT_DIR/$release_notes_name"

    for output_file in "$archive_path" "$checksum_path" "$release_notes_output"; do
        if [[ -e "$output_file" ]]; then
            echo "Refusing to overwrite existing formal release artifact: $output_file" >&2
            exit 1
        fi
    done

    formal_stage_dir="$(mktemp -d "$OUTPUT_DIR/.formal-update-stage.XXXXXX")"
    case "$formal_stage_dir" in
        "$OUTPUT_DIR"/.formal-update-stage.*) ;;
        *)
            echo "Unexpected formal staging directory" >&2
            exit 1
            ;;
    esac
    staged_archive="$formal_stage_dir/$archive_name"
    staged_checksum="$staged_archive.sha256"
    staged_notes="$formal_stage_dir/$release_notes_name"

    /usr/bin/ditto -c -k --sequesterRsrc --keepParent "$explicit_app_path" "$staged_archive"
    (
        cd "$formal_stage_dir"
        /usr/bin/shasum -a 256 "$archive_name" >"$archive_name.sha256"
    )
    cp "$release_notes_path" "$staged_notes"

    "$REPO_ROOT/scripts/verify-release-qa-package.sh" \
        --formal-update \
        "$staged_archive" >/dev/null

    mv "$staged_archive" "$archive_path"
    mv "$staged_checksum" "$checksum_path"
    mv "$staged_notes" "$release_notes_output"
    rmdir "$formal_stage_dir"
    formal_stage_dir=""

    echo "Formal Sparkle update artifacts created:"
    echo "  Archive:       $archive_path"
    echo "  SHA-256:       $checksum_path"
    echo "  Release notes: $release_notes_output"
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
            output_dir_explicit=1
            shift
            ;;
        --formal-update)
            formal_update=1
            should_build=0
            ;;
        --app)
            if [[ $# -lt 2 ]]; then
                echo "--app requires an application path" >&2
                exit 2
            fi
            explicit_app_path="$2"
            shift
            ;;
        --release-notes)
            if [[ $# -lt 2 ]]; then
                echo "--release-notes requires a file path" >&2
                exit 2
            fi
            release_notes_path="$2"
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
require_command mkdir
require_command shasum

cd "$REPO_ROOT"

if [[ "$formal_update" -eq 1 ]]; then
    require_command cp
    require_command grep
    require_command mktemp
    require_command mv
    require_command python3
    require_command rm
    require_command rmdir
    require_command spctl
    trap cleanup_formal_stage EXIT
    package_formal_update
    exit 0
fi

if [[ -n "$explicit_app_path" || -n "$release_notes_path" ]]; then
    echo "--app and --release-notes are only valid with --formal-update" >&2
    exit 2
fi

require_command git
require_command rm
require_command xcodebuild
require_command xcodegen

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
package_stem="粘易-${version}-${build_number}-${git_commit}-${timestamp}"
package_app_name="$package_stem.app"
package_app_path="$OUTPUT_DIR/$package_app_name"
zip_name="$package_stem.zip"
zip_path="$OUTPUT_DIR/$zip_name"
checksum_path="$zip_path.sha256"
manifest_path="$OUTPUT_DIR/$package_stem-manifest.md"
executable_path="$app_path/Contents/MacOS/粘易"
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
