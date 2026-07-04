#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEFAULT_OUTPUT_ROOT="$REPO_ROOT/build/manual-release-qa-session"
OUTPUT_DIR=""
should_build=1

usage() {
    cat <<'EOF'
Usage: scripts/start-manual-release-qa-session.sh [options]

Prepare a timestamped manual Release QA session workspace.

Options:
  --no-build       Reuse the existing Release build when packaging.
  --output-dir DIR Write the session files to DIR instead of build/manual-release-qa-session/<timestamp>.
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

newest_matching_file() {
    local directory="$1"
    local pattern="$2"
    find "$directory" -maxdepth 1 -type f -name "$pattern" -print | sort | tail -n 1
}

newest_matching_directory() {
    local directory="$1"
    local pattern="$2"
    find "$directory" -maxdepth 1 -type d -name "$pattern" -print | sort | tail -n 1
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

require_command cp
require_command date
require_command find
require_command git
require_command mkdir
require_command tail

cd "$REPO_ROOT"

git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf "unknown")"
timestamp="$(date '+%Y%m%d-%H%M%S')"

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$DEFAULT_OUTPUT_ROOT/$timestamp-$git_commit"
fi

package_dir="$OUTPUT_DIR/package"
fixture_dir="$OUTPUT_DIR/fixtures"
verification_path="$OUTPUT_DIR/package-verification.md"
baseline_path="$OUTPUT_DIR/release-qa-baseline.md"
fixture_log_path="$OUTPUT_DIR/fixture-generation.log"
manual_record_path="$OUTPUT_DIR/manual-qa-record.md"
readme_path="$OUTPUT_DIR/README.md"
session_verification_path="$OUTPUT_DIR/session-verification.md"

mkdir -p "$package_dir" "$fixture_dir"

package_args=(--output-dir "$package_dir")
if [[ "$should_build" -eq 0 ]]; then
    package_args=(--no-build "${package_args[@]}")
fi

echo "Creating Release QA package..."
scripts/package-release-qa-build.sh "${package_args[@]}"

zip_path="$(newest_matching_file "$package_dir" "MacPasteHistory-*.zip")"
package_app_path="$(newest_matching_directory "$package_dir" "MacPasteHistory-*.app")"
manifest_path="$(newest_matching_file "$package_dir" "MacPasteHistory-*-manifest.md")"
checksum_path="$zip_path.sha256"

if [[ -z "$zip_path" || ! -f "$zip_path" ]]; then
    echo "Could not find generated QA zip in $package_dir" >&2
    exit 1
fi
if [[ -z "$package_app_path" || ! -d "$package_app_path" ]]; then
    echo "Could not find generated QA app in $package_dir" >&2
    exit 1
fi
if [[ -z "$manifest_path" || ! -f "$manifest_path" ]]; then
    echo "Could not find generated QA manifest in $package_dir" >&2
    exit 1
fi

echo "Verifying Release QA package..."
scripts/verify-release-qa-package.sh "$zip_path" >"$verification_path"

echo "Generating manual QA fixtures..."
scripts/generate-manual-qa-fixtures.swift "$fixture_dir" >"$fixture_log_path"

echo "Generating Release QA baseline..."
scripts/release-qa-baseline.sh --app "$package_app_path" >"$baseline_path"

cp docs/release/manual-qa-record.md "$manual_record_path"
scripts/prefill-manual-qa-record.sh \
    --record "$manual_record_path" \
    --baseline "$baseline_path" \
    --verification "$verification_path" \
    --checksum "$checksum_path" \
    --fixture-dir "$fixture_dir" \
    --notes "Session prefilled from generated package, baseline, verification, and fixtures; manual results still required." \
    >/tmp/macpastehistory-prefill-manual-qa-record.log

cat >"$readme_path" <<EOF
# Manual Release QA Session

Generated: $(date '+%Y-%m-%d %H:%M:%S %z')

| Field | Value |
|---|---|
| Git commit | \`$git_commit\` |
| Session directory | \`$OUTPUT_DIR\` |
| Packaged app | \`$package_app_path\` |
| QA zip | \`$zip_path\` |
| SHA-256 file | \`$checksum_path\` |
| Package manifest | \`$manifest_path\` |
| Package verification | \`$verification_path\` |
| Release baseline | \`$baseline_path\` |
| Fixture directory | \`$fixture_dir\` |
| Manual QA record copy | \`$manual_record_path\` |
| Session verification | \`$session_verification_path\` |

## Recommended Order

1. Review the prefilled build, signing, Sandbox, Xcode, macOS, package, and fixture values in \`$manual_record_path\`.
2. Cross-check \`$baseline_path\` and \`$verification_path\` if any prefilled value needs review.
3. Run static release checks before manual testing:
   - \`scripts/scan-privacy-log-safety.sh\`
   - \`scripts/verify-privacy-usage-descriptions.sh\`
   - \`scripts/verify-app-icon-assets.sh\`
   - \`scripts/verify-release-screenshot-assets.sh\`
   - \`scripts/verify-manual-qa-fixtures.sh\`
   - \`scripts/verify-signing-identities.sh --allow-adhoc\` for internal QA, or without the flag for final distribution
   - \`scripts/verify-release-app-signature.sh --allow-adhoc\` for internal QA, or without the flag for final distribution
4. Run \`scripts/release-install-preflight.sh --no-build\` to verify a copied Release app can launch, initialize isolated local storage, and quit.
5. Launch the packaged app from Finder, or use \`scripts/preview-release-app.sh --seed-preview-data\` for a local isolated-data preview with synthetic history already loaded.
6. Use files in \`$fixture_dir\` for Chrome, Safari, VS Code, WeChat, DingTalk, large-text, and image-copy scenarios.
7. Fill every manual result in \`$manual_record_path\` with tester, date, environment, result, and screenshot or note references.
8. After filling the record, run \`scripts/validate-manual-qa-record.sh "$manual_record_path"\`. Use \`--allow-adhoc\` only for internal QA before distribution signing exists.
9. Run \`scripts/release-readiness-report.sh --manual-record "$manual_record_path" --qa-session "$OUTPUT_DIR" --output "$OUTPUT_DIR/release-readiness-report.md" --json-output "$OUTPUT_DIR/release-readiness-report.json" --strict-final\` as the final release gate; add \`--allow-adhoc\` only for internal QA before distribution signing exists.
10. Keep OpenSpec release tasks unchecked until the corresponding manual evidence is actually filled, validated, and reviewed.

## Important Boundaries

- This session only prepares evidence inputs; it does not prove menu bar, restore, Clear All Data, Launch at login, Intel Mac, or multi-macOS manual QA.
- Current ad-hoc signed packages are suitable for local/internal QA only. Formal distribution still needs a valid Apple signing identity.
EOF

echo "Verifying manual Release QA session directory..."
scripts/verify-manual-release-qa-session.sh "$OUTPUT_DIR" >"$session_verification_path"

echo
echo "Manual Release QA session prepared:"
echo "  Directory:    $OUTPUT_DIR"
echo "  README:       $readme_path"
echo "  Verification: $session_verification_path"
echo "  QA record:    $manual_record_path"
echo "  Package zip:  $zip_path"
