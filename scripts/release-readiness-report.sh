#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manual_record="$REPO_ROOT/docs/release/manual-qa-record.md"
output_path=""
allow_adhoc=0
skip_xcodegen=0
skip_install_preflight=0
skip_release_smoke=0

usage() {
    cat <<'EOF'
Usage: scripts/release-readiness-report.sh [options]

Generate a Markdown release-readiness report from automated checks and
manual QA evidence.

Options:
  --manual-record PATH  Manual QA record to validate.
  --output PATH         Write the report to PATH as well as stdout.
  --allow-adhoc         Allow ad-hoc or missing signing for internal QA only.
  --skip-xcodegen       Validate the existing Xcode project without regenerating it.
  --skip-install-preflight
                        Skip launching a copied Release app during readiness checks.
  --skip-release-smoke  Skip the synthetic Release smoke test during readiness checks.
  -h, --help            Show this help.
EOF
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

escape_table_cell() {
    printf "%s" "$1" | tr '\n' ' ' | sed 's/|/\\|/g'
}

add_blocker() {
    blockers+=("$1")
}

add_warning() {
    warnings+=("$1")
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --manual-record)
            if [[ $# -lt 2 ]]; then
                echo "--manual-record requires a path" >&2
                exit 2
            fi
            manual_record="$2"
            shift
            ;;
        --output)
            if [[ $# -lt 2 ]]; then
                echo "--output requires a path" >&2
                exit 2
            fi
            output_path="$2"
            shift
            ;;
        --allow-adhoc)
            allow_adhoc=1
            ;;
        --skip-xcodegen)
            skip_xcodegen=1
            ;;
        --skip-install-preflight)
            skip_install_preflight=1
            ;;
        --skip-release-smoke)
            skip_release_smoke=1
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

require_command date
require_command git
require_command mktemp
require_command security
require_command sw_vers
require_command uname
require_command xcode-select
require_command xcodebuild

cd "$REPO_ROOT"

blockers=()
warnings=()
detailed_sections=()
check_rows=()

run_capture() {
    local check_name="$1"
    shift
    local tmp_file
    tmp_file="$(mktemp)"

    set +e
    "$@" >"$tmp_file" 2>&1
    local status=$?
    set -e

    local output
    output="$(cat "$tmp_file")"
    rm -f "$tmp_file"

    local label
    if [[ "$status" -eq 0 ]]; then
        label="PASS"
    else
        label="FAIL"
    fi

    local summary
    summary="$(printf "%s\n" "$output" | awk '/^Status:/ {sub(/^Status:[[:space:]]*/, ""); print; found=1} END {if (!found) print "See detailed output."}' | tail -1)"
    check_rows+=("| $check_name | $label | $(escape_table_cell "$summary") |")

    detailed_sections+=("## $check_name"$'\n\n```text\n'"$output"$'\n```')
    return "$status"
}

xcode_ref_args=("$REPO_ROOT/scripts/validate-xcode-file-references.sh")
if [[ "$skip_xcodegen" -eq 1 ]]; then
    xcode_ref_args+=("--skip-generate")
fi
if ! run_capture "Xcode file references" "${xcode_ref_args[@]}"; then
    add_blocker "Xcode project contains missing Swift file references."
fi

if ! run_capture "Privacy log safety" "$REPO_ROOT/scripts/scan-privacy-log-safety.sh"; then
    add_blocker "App logging may expose clipboard content or sensitive data."
fi

if ! run_capture "App icon assets" "$REPO_ROOT/scripts/verify-app-icon-assets.sh"; then
    add_blocker "App icon asset catalog is incomplete or has invalid PNG dimensions."
fi

if [[ "$skip_release_smoke" -eq 1 ]]; then
    check_rows+=("| Release smoke test | SKIP | Skipped by --skip-release-smoke. |")
    add_warning "Release smoke test was skipped; run scripts/release-smoke-test.sh before final release."
else
    if ! run_capture "Release smoke test" "$REPO_ROOT/scripts/release-smoke-test.sh"; then
        add_blocker "Release smoke test failed for sandbox, clipboard capture, persistence, large content, or cleanup behavior."
    fi
fi

if [[ "$skip_install_preflight" -eq 1 ]]; then
    check_rows+=("| Release install preflight | SKIP | Skipped by --skip-install-preflight. |")
    add_warning "Release install preflight was skipped; run scripts/release-install-preflight.sh before final release."
else
    install_preflight_args=("$REPO_ROOT/scripts/release-install-preflight.sh")
    if [[ "$skip_release_smoke" -eq 0 ]]; then
        install_preflight_args+=("--no-build")
    fi
    if ! run_capture "Release install preflight" "${install_preflight_args[@]}"; then
        add_blocker "Copied Release app failed install-copy launch, local storage initialization, or quit preflight."
    fi
fi

xcode_path="$(xcode-select -p)"
xcode_version="$(xcodebuild -version | tr '\n' ' ')"
if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    first_launch_status="passed"
else
    first_launch_status="not complete"
    add_blocker "Xcode first-launch authorization is not complete."
fi
if xcodebuild -license status >/dev/null 2>&1; then
    license_status="accepted"
else
    license_status="not accepted"
    add_blocker "Xcode license is not accepted."
fi
check_rows+=("| Xcode authorization | PASS | Developer dir: \`$(escape_table_cell "$xcode_path")\`; first launch: \`$first_launch_status\`; license: \`$license_status\` |")

identity_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
identity_count="$(printf "%s\n" "$identity_output" | awk '/valid identities found/ {print $1; found=1} END {if (!found) print 0}')"
if [[ "$identity_count" -eq 0 ]]; then
    if [[ "$allow_adhoc" -eq 1 ]]; then
        check_rows+=("| Signing identities | WARN | No valid identities found; allowed only for internal QA. |")
        add_warning "No valid code signing identities are installed; formal distribution remains blocked."
    else
        check_rows+=("| Signing identities | FAIL | No valid code signing identities found. |")
        add_blocker "Install an Apple Development, Apple Distribution, or Developer ID Application signing identity."
    fi
else
    check_rows+=("| Signing identities | PASS | Valid code signing identities: \`$identity_count\` |")
fi
detailed_sections+=("## Signing Identities"$'\n\n```text\n'"$identity_output"$'\n```')

required_docs=(
    "docs/user-guide.md"
    "docs/privacy-policy.md"
    "docs/release/screenshots/README.md"
)
missing_docs=()
for relative_path in "${required_docs[@]}"; do
    if [[ ! -s "$REPO_ROOT/$relative_path" ]]; then
        missing_docs+=("$relative_path")
    fi
done
if [[ "${#missing_docs[@]}" -eq 0 ]]; then
    check_rows+=("| Release docs | PASS | Required user, privacy, and screenshot docs exist. |")
else
    check_rows+=("| Release docs | FAIL | Missing or empty: \`$(escape_table_cell "${missing_docs[*]}")\` |")
    add_blocker "Required release documentation is missing or empty."
fi

required_screenshots=(
    "docs/release/screenshots/01-history-overview.png"
    "docs/release/screenshots/02-image-history.png"
    "docs/release/screenshots/03-settings-controls.png"
    "docs/release/screenshots/04-local-privacy.png"
)
missing_screenshots=()
for relative_path in "${required_screenshots[@]}"; do
    if [[ ! -s "$REPO_ROOT/$relative_path" ]]; then
        missing_screenshots+=("$relative_path")
    fi
done
if [[ "${#missing_screenshots[@]}" -eq 0 ]]; then
    check_rows+=("| Screenshot assets | PASS | Four required release screenshots exist. |")
else
    check_rows+=("| Screenshot assets | FAIL | Missing or empty: \`$(escape_table_cell "${missing_screenshots[*]}")\` |")
    add_blocker "Required release screenshot assets are missing or empty."
fi

manual_args=("$REPO_ROOT/scripts/validate-manual-qa-record.sh")
if [[ "$allow_adhoc" -eq 1 ]]; then
    manual_args+=("--allow-adhoc")
fi
manual_args+=("$manual_record")
if ! run_capture "Manual QA record" "${manual_args[@]}"; then
    add_blocker "Manual QA record is incomplete or still contains release blockers."
fi

git_status="$(git status --short)"
if [[ -z "$git_status" ]]; then
    check_rows+=("| Git worktree | PASS | Worktree is clean. |")
else
    check_rows+=("| Git worktree | WARN | Worktree has uncommitted changes. |")
    add_warning "Git worktree has uncommitted changes; commit or discard intentional changes before final release."
    detailed_sections+=("## Git Status"$'\n\n```text\n'"$git_status"$'\n```')
fi

machine_arch="$(uname -m)"
macos_version="$(sw_vers -productVersion)"
macos_build="$(sw_vers -buildVersion)"
git_commit="$(git rev-parse --short HEAD)"
manual_record_display="$(cd "$REPO_ROOT" && python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], os.getcwd()))' "$manual_record" 2>/dev/null || printf "%s" "$manual_record")"

emit_report() {
    cat <<EOF
# Release Readiness Report

Generated: $(date '+%Y-%m-%d %H:%M:%S %z')

| Field | Value |
|---|---|
| Repository | \`$REPO_ROOT\` |
| Git commit | \`$git_commit\` |
| macOS | \`$macos_version ($macos_build)\` |
| Architecture | \`$machine_arch\` |
| Xcode | \`$(escape_table_cell "$xcode_version")\` |
| Developer directory | \`$(escape_table_cell "$xcode_path")\` |
| Manual QA record | \`$(escape_table_cell "$manual_record_display")\` |
| Internal ad-hoc mode | \`$([[ "$allow_adhoc" -eq 1 ]] && printf "yes" || printf "no")\` |
| Release smoke skipped | \`$([[ "$skip_release_smoke" -eq 1 ]] && printf "yes" || printf "no")\` |
| Install preflight skipped | \`$([[ "$skip_install_preflight" -eq 1 ]] && printf "yes" || printf "no")\` |

## Automated Checks

| Check | Status | Notes |
|---|---|---|
EOF

    local row
    for row in "${check_rows[@]}"; do
        printf "%s\n" "$row"
    done

    cat <<EOF

## Blockers

EOF

    if [[ "${#blockers[@]}" -eq 0 ]]; then
        echo "- None detected by automated readiness checks."
    else
        for row in "${blockers[@]}"; do
            printf -- "- %s\n" "$row"
        done
    fi

    cat <<EOF

## Warnings

EOF

    if [[ "${#warnings[@]}" -eq 0 ]]; then
        echo "- None."
    else
        for row in "${warnings[@]}"; do
            printf -- "- %s\n" "$row"
        done
    fi

    cat <<'EOF'

## Manual Evidence Still Required

- Signed Release build with the intended distribution certificate and Team ID.
- Menu bar, history window, restore, delete, clear-all, pause, blacklist, and launch-at-login manual QA.
- Apple Silicon, Intel, and supported macOS version coverage or explicit release decision records.
- Final reviewer decision in the manual QA record.

## Detailed Outputs

EOF

    for row in "${detailed_sections[@]}"; do
        printf "%s\n\n" "$row"
    done
}

if [[ -n "$output_path" ]]; then
    mkdir -p "$(dirname "$output_path")"
    emit_report | tee "$output_path"
else
    emit_report
fi

if [[ "${#blockers[@]}" -gt 0 ]]; then
    exit 1
fi
