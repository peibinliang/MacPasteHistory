#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manual_record="$REPO_ROOT/docs/release/manual-qa-record.md"
qa_session=""
output_path=""
json_output_path=""
allow_adhoc=0
skip_xcodegen=0
skip_install_preflight=0
skip_release_smoke=0
strict_final=0

usage() {
    cat <<'EOF'
Usage: scripts/release-readiness-report.sh [options]

Generate a Markdown release-readiness report from automated checks and
manual QA evidence.

Options:
  --manual-record PATH  Manual QA record to validate.
  --qa-session PATH     Validate a generated manual QA session directory.
  --output PATH         Write the report to PATH as well as stdout.
  --json-output PATH    Write a machine-readable readiness summary to PATH.
  --allow-adhoc         Allow ad-hoc or missing signing for internal QA only.
  --skip-xcodegen       Validate the existing Xcode project without regenerating it.
  --skip-install-preflight
                        Skip launching a copied Release app during readiness checks.
  --skip-release-smoke  Skip the synthetic Release smoke test during readiness checks.
  --strict-final        Treat warnings as blockers for final distribution approval.
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
        --qa-session)
            if [[ $# -lt 2 ]]; then
                echo "--qa-session requires a path" >&2
                exit 2
            fi
            qa_session="$2"
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
        --json-output)
            if [[ $# -lt 2 ]]; then
                echo "--json-output requires a path" >&2
                exit 2
            fi
            json_output_path="$2"
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
        --strict-final)
            strict_final=1
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
require_command python3
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
check_names=()
check_statuses=()
check_notes=()

add_check_row() {
    local check_name="$1"
    local check_status="$2"
    local note_text="$3"

    check_names+=("$check_name")
    check_statuses+=("$check_status")
    check_notes+=("$note_text")
    check_rows+=("| $check_name | $check_status | $(escape_table_cell "$note_text") |")
}

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

    local summary
    summary="$(printf "%s\n" "$output" | awk '/^Status:/ {sub(/^Status:[[:space:]]*/, ""); print; found=1} END {if (!found) print "See detailed output."}' | tail -1)"
    local label
    case "$summary" in
        PASS|WARN|SKIP|FAIL)
            label="$summary"
            ;;
        *)
            if [[ "$status" -eq 0 ]]; then
                label="PASS"
            else
                label="FAIL"
            fi
            ;;
    esac
    add_check_row "$check_name" "$label" "$summary"

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

if ! run_capture "Privacy usage descriptions" "$REPO_ROOT/scripts/verify-privacy-usage-descriptions.sh"; then
    add_blocker "Info.plist privacy usage descriptions are missing or incomplete."
fi

if ! run_capture "Supported macOS targets" "$REPO_ROOT/scripts/verify-supported-macos-targets.sh"; then
    add_blocker "Supported macOS target declarations or QA matrix rows are inconsistent."
fi

if ! run_capture "Release version and build" "$REPO_ROOT/scripts/verify-release-version-build.sh"; then
    add_blocker "Release version or build declarations are inconsistent."
fi

if ! run_capture "Release entitlements" "$REPO_ROOT/scripts/verify-release-entitlements.sh"; then
    add_blocker "Release entitlement configuration is inconsistent or too broad."
fi

if ! run_capture "Release identity" "$REPO_ROOT/scripts/verify-release-identity.sh"; then
    add_blocker "Release bundle identity or menu-bar app declarations are inconsistent."
fi

if ! run_capture "App icon assets" "$REPO_ROOT/scripts/verify-app-icon-assets.sh"; then
    add_blocker "App icon asset catalog is incomplete or has invalid PNG dimensions."
fi

if ! run_capture "Screenshot assets" "$REPO_ROOT/scripts/verify-release-screenshot-assets.sh"; then
    add_blocker "Required release screenshot assets are missing or have invalid PNG dimensions."
fi

if ! run_capture "Manual QA fixtures" "$REPO_ROOT/scripts/verify-manual-qa-fixtures.sh"; then
    add_blocker "Manual QA fixtures failed generation or validation."
fi

if [[ -n "$qa_session" ]]; then
    if ! run_capture "Manual QA session" "$REPO_ROOT/scripts/verify-manual-release-qa-session.sh" "$qa_session"; then
        add_blocker "Manual Release QA session directory is incomplete."
    fi
else
    add_check_row "Manual QA session" "SKIP" "No --qa-session provided."
    add_warning "Manual Release QA session directory was not validated; run scripts/start-manual-release-qa-session.sh and pass --qa-session before final release."
fi

if [[ "$skip_release_smoke" -eq 1 ]]; then
    add_check_row "Release smoke test" "SKIP" "Skipped by --skip-release-smoke."
    add_warning "Release smoke test was skipped; run scripts/release-smoke-test.sh before final release."
else
    if ! run_capture "Release smoke test" "$REPO_ROOT/scripts/release-smoke-test.sh"; then
        add_blocker "Release smoke test failed for sandbox, clipboard capture, persistence, large content, or cleanup behavior."
    fi
fi

if [[ "$skip_install_preflight" -eq 1 ]]; then
    add_check_row "Release install preflight" "SKIP" "Skipped by --skip-install-preflight."
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

xcode_path="$(xcode-select -p 2>/dev/null || printf "unknown")"
xcode_version="$(xcodebuild -version 2>/dev/null | tr '\n' ' ' || printf "unknown")"
if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    first_launch_status="passed"
else
    first_launch_status="not complete"
fi
if xcodebuild -license status >/dev/null 2>&1; then
    license_status="accepted"
else
    license_status="not accepted"
fi
if ! run_capture "Xcode authorization" "$REPO_ROOT/scripts/verify-xcode-authorization.sh"; then
    add_blocker "Xcode developer directory, first-launch authorization, or license acceptance is incomplete."
fi

signing_identity_args=("$REPO_ROOT/scripts/verify-signing-identities.sh")
if [[ "$allow_adhoc" -eq 1 ]]; then
    signing_identity_args+=("--allow-adhoc")
fi
if ! run_capture "Signing identities" "${signing_identity_args[@]}"; then
    add_blocker "Install an Apple Development, Apple Distribution, or Developer ID Application signing identity."
else
    last_check_index=$((${#check_statuses[@]} - 1))
    if [[ "${check_statuses[$last_check_index]}" == "WARN" ]]; then
        add_warning "No valid code signing identities are installed; formal distribution remains blocked."
    fi
fi

release_app_signature_args=("$REPO_ROOT/scripts/verify-release-app-signature.sh")
if [[ "$allow_adhoc" -eq 1 ]]; then
    release_app_signature_args+=("--allow-adhoc")
fi
if ! run_capture "Release app signature" "${release_app_signature_args[@]}"; then
    add_blocker "Release app is not signed with a distribution-capable Team ID or failed code-signature verification."
else
    last_check_index=$((${#check_statuses[@]} - 1))
    if [[ "${check_statuses[$last_check_index]}" == "WARN" ]]; then
        add_warning "Release app is ad-hoc signed; formal distribution remains blocked until a Team-signed app is produced."
    fi
fi

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
    add_check_row "Release docs" "PASS" "Required user, privacy, and screenshot docs exist."
else
    add_check_row "Release docs" "FAIL" "Missing or empty: \`${missing_docs[*]}\`"
    add_blocker "Required release documentation is missing or empty."
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
    add_check_row "Git worktree" "PASS" "Worktree is clean."
else
    add_check_row "Git worktree" "WARN" "Worktree has uncommitted changes."
    add_warning "Git worktree has uncommitted changes; commit or discard intentional changes before final release."
    detailed_sections+=("## Git Status"$'\n\n```text\n'"$git_status"$'\n```')
fi

if [[ "$strict_final" -eq 1 && "${#warnings[@]}" -gt 0 ]]; then
    add_blocker "Strict final mode requires zero warnings; resolve all warnings before distribution approval."
fi

machine_arch="$(uname -m)"
macos_version="$(sw_vers -productVersion)"
macos_build="$(sw_vers -buildVersion)"
git_commit="$(git rev-parse --short HEAD)"
manual_record_display="$(cd "$REPO_ROOT" && python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], os.getcwd()))' "$manual_record" 2>/dev/null || printf "%s" "$manual_record")"
if [[ -n "$qa_session" ]]; then
    qa_session_display="$(cd "$REPO_ROOT" && python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], os.getcwd()))' "$qa_session" 2>/dev/null || printf "%s" "$qa_session")"
else
    qa_session_display="not provided"
fi
generated_at="$(date '+%Y-%m-%d %H:%M:%S %z')"

emit_report() {
    cat <<EOF
# Release Readiness Report

Generated: $generated_at

| Field | Value |
|---|---|
| Repository | \`$REPO_ROOT\` |
| Git commit | \`$git_commit\` |
| macOS | \`$macos_version ($macos_build)\` |
| Architecture | \`$machine_arch\` |
| Xcode | \`$(escape_table_cell "$xcode_version")\` |
| Developer directory | \`$(escape_table_cell "$xcode_path")\` |
| Manual QA record | \`$(escape_table_cell "$manual_record_display")\` |
| Manual QA session | \`$(escape_table_cell "$qa_session_display")\` |
| Internal ad-hoc mode | \`$([[ "$allow_adhoc" -eq 1 ]] && printf "yes" || printf "no")\` |
| Release smoke skipped | \`$([[ "$skip_release_smoke" -eq 1 ]] && printf "yes" || printf "no")\` |
| Install preflight skipped | \`$([[ "$skip_install_preflight" -eq 1 ]] && printf "yes" || printf "no")\` |
| Strict final mode | \`$([[ "$strict_final" -eq 1 ]] && printf "yes" || printf "no")\` |

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

emit_json_summary() {
    local tmp_dir
    tmp_dir="$(mktemp -d)"
    local checks_path="$tmp_dir/checks.tsv"
    local blockers_path="$tmp_dir/blockers.txt"
    local warnings_path="$tmp_dir/warnings.txt"

    local index
    for index in "${!check_names[@]}"; do
        printf "%s\t%s\t%s\n" "${check_names[$index]}" "${check_statuses[$index]}" "${check_notes[$index]}"
    done >"$checks_path"

    if [[ "${#blockers[@]}" -gt 0 ]]; then
        printf "%s\n" "${blockers[@]}" >"$blockers_path"
    else
        : >"$blockers_path"
    fi
    if [[ "${#warnings[@]}" -gt 0 ]]; then
        printf "%s\n" "${warnings[@]}" >"$warnings_path"
    else
        : >"$warnings_path"
    fi

    mkdir -p "$(dirname "$json_output_path")"
    python3 - "$json_output_path" "$checks_path" "$blockers_path" "$warnings_path" <<PY
import json
import sys

json_path, checks_path, blockers_path, warnings_path = sys.argv[1:5]

checks = []
with open(checks_path, encoding="utf-8") as handle:
    for line in handle:
        name, status, notes = line.rstrip("\n").split("\t", 2)
        checks.append({"name": name, "status": status, "notes": notes})

def read_lines(path):
    with open(path, encoding="utf-8") as handle:
        return [line.rstrip("\n") for line in handle if line.strip()]

payload = {
    "status": "fail" if read_lines(blockers_path) else "pass",
    "generatedAt": "$generated_at",
    "repository": "$REPO_ROOT",
    "gitCommit": "$git_commit",
    "macOS": {"version": "$macos_version", "build": "$macos_build"},
    "architecture": "$machine_arch",
    "xcode": {
        "developerDirectory": "$xcode_path",
        "version": "$xcode_version",
        "firstLaunchStatus": "$first_launch_status",
        "licenseStatus": "$license_status",
    },
    "manualQaRecord": "$manual_record_display",
    "manualQaSession": "$qa_session_display",
    "internalAdhocMode": bool($allow_adhoc),
    "releaseSmokeSkipped": bool($skip_release_smoke),
    "installPreflightSkipped": bool($skip_install_preflight),
    "strictFinalMode": bool($strict_final),
    "checks": checks,
    "blockers": read_lines(blockers_path),
    "warnings": read_lines(warnings_path),
    "manualEvidenceStillRequired": [
        "Signed Release build with the intended distribution certificate and Team ID.",
        "Menu bar, history window, restore, delete, clear-all, pause, blacklist, and launch-at-login manual QA.",
        "Apple Silicon, Intel, and supported macOS version coverage or explicit release decision records.",
        "Final reviewer decision in the manual QA record.",
    ],
}

with open(json_path, "w", encoding="utf-8") as handle:
    json.dump(payload, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
    rm -rf "$tmp_dir"
}

if [[ -n "$output_path" ]]; then
    mkdir -p "$(dirname "$output_path")"
    emit_report | tee "$output_path"
else
    emit_report
fi

if [[ -n "$json_output_path" ]]; then
    emit_json_summary
fi

if [[ "${#blockers[@]}" -gt 0 ]]; then
    exit 1
fi
