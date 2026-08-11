#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_INFO_PLIST="$REPO_ROOT/MacPasteHistory/Resources/Info.plist"
EXPECTED_ARCHIVE_NAME="粘易-1.0.1-2.zip"
DOWNLOAD_URL_PREFIX="https://github.com/peibinliang/MacPasteHistory/releases/download/v1.0.1/"

release_directory=""
sparkle_bin_directory=""

usage() {
    cat <<'EOF'
Usage: scripts/generate-sparkle-appcast.sh \
  --release-directory DIR \
  --sparkle-bin-directory DIR

Generate a V1.0.1 appcast from an explicit formal-release directory, verify it,
then copy the verified XML to docs/appcast.xml. This command accepts no key
arguments; Sparkle accesses its signing key through its protected environment.
EOF
}

fail() {
    echo "Sparkle appcast generation failed: $1" >&2
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --release-directory)
            [[ $# -ge 2 ]] || { echo "--release-directory requires a path" >&2; exit 2; }
            release_directory="$2"
            shift
            ;;
        --sparkle-bin-directory)
            [[ $# -ge 2 ]] || { echo "--sparkle-bin-directory requires a path" >&2; exit 2; }
            sparkle_bin_directory="$2"
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

[[ -n "$release_directory" ]] || { usage >&2; exit 2; }
[[ -n "$sparkle_bin_directory" ]] || { usage >&2; exit 2; }
[[ -d "$release_directory" ]] || fail "release directory does not exist"
[[ -d "$sparkle_bin_directory" ]] || fail "Sparkle bin directory does not exist"

generate_appcast="$sparkle_bin_directory/generate_appcast"
archive_path="$release_directory/$EXPECTED_ARCHIVE_NAME"
generated_appcast="$release_directory/appcast.xml"
destination_appcast="$REPO_ROOT/docs/appcast.xml"

[[ -x "$generate_appcast" ]] || fail "generate_appcast is missing or not executable"
[[ -f "$archive_path" ]] || fail "formal update archive is missing from the release directory"
[[ -f "$archive_path.sha256" ]] || fail "adjacent SHA-256 file is missing"
[[ -f "$SOURCE_INFO_PLIST" ]] || fail "source Info.plist is missing"

"$REPO_ROOT/scripts/verify-release-qa-package.sh" \
    --formal-update \
    "$archive_path" >/dev/null

"$generate_appcast" \
    --download-url-prefix "$DOWNLOAD_URL_PREFIX" \
    --maximum-versions 10 \
    "$release_directory"

[[ -f "$generated_appcast" ]] || fail "generate_appcast did not produce appcast.xml"
expected_public_key="$(
    /usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' "$SOURCE_INFO_PLIST" 2>/dev/null || true
)"
[[ -n "$expected_public_key" ]] || fail "SUPublicEDKey is missing from source Info.plist"

"$REPO_ROOT/scripts/verify-sparkle-appcast.sh" \
    --appcast "$generated_appcast" \
    --archive "$archive_path" \
    --expected-public-key "$expected_public_key"

mkdir -p "$(dirname "$destination_appcast")"
temporary_destination="$destination_appcast.tmp.$$"
cp "$generated_appcast" "$temporary_destination"
mv "$temporary_destination" "$destination_appcast"

echo "Verified appcast copied to: $destination_appcast"
