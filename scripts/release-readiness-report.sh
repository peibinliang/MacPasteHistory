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
formal_update_archive=""
appcast_path=""
openspec_change="add-v1-0-1-sensitive-filter-and-updates"
readiness_extract_dir=""
formal_app_path=""

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
  --formal-update-archive PATH
                        Verify an explicit 粘易-1.0.1-2.zip formal update.
  --appcast PATH        Verify an explicit appcast against the formal update archive.
  --openspec-change NAME
                        Read progress from openspec/changes/NAME/tasks.md.
                        Defaults to add-v1-0-1-sensitive-filter-and-updates.
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

cleanup() {
    if [[ -n "$readiness_extract_dir" && -d "$readiness_extract_dir" ]]; then
        rm -rf "$readiness_extract_dir"
    fi
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
        --formal-update-archive)
            if [[ $# -lt 2 ]]; then
                echo "--formal-update-archive requires a path" >&2
                exit 2
            fi
            formal_update_archive="$2"
            shift
            ;;
        --appcast)
            if [[ $# -lt 2 ]]; then
                echo "--appcast requires a path" >&2
                exit 2
            fi
            appcast_path="$2"
            shift
            ;;
        --openspec-change)
            if [[ $# -lt 2 ]]; then
                echo "--openspec-change requires a change name" >&2
                exit 2
            fi
            openspec_change="$2"
            shift
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

if [[ ! "$openspec_change" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    echo "--openspec-change must be a single safe change directory name" >&2
    exit 2
fi

require_command date
require_command git
require_command grep
require_command mktemp
require_command python3
require_command security
require_command sw_vers
require_command uname
require_command xcode-select
require_command xcodebuild

trap cleanup EXIT

cd "$REPO_ROOT"

blockers=()
warnings=()
detailed_sections=()
check_rows=()
check_names=()
check_statuses=()
check_notes=()
openspec_progress_total=0
openspec_progress_complete=0
openspec_progress_remaining=0
openspec_remaining_tasks=()

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

verify_developer_id_app() {
    local app_path="$1"
    local codesign_output authority signature team_identifier

    codesign_output="$(codesign -dvvv "$app_path" 2>&1 || true)"
    authority="$(printf '%s\n' "$codesign_output" | awk -F= '/^Authority=/ {print $2; exit}')"
    signature="$(printf '%s\n' "$codesign_output" | awk -F= '/^Signature=/ {print $2; exit}')"
    team_identifier="$(printf '%s\n' "$codesign_output" | awk -F= '/^TeamIdentifier=/ {print $2; exit}')"

    if [[ "$signature" == "adhoc" || "$authority" != "Developer ID Application:"* \
        || -z "$team_identifier" || "$team_identifier" == "not set" ]]; then
        echo "Developer ID Application signature is missing or invalid."
        echo "Status: FAIL"
        return 1
    fi
    if ! codesign --verify --deep --strict "$app_path" >/dev/null 2>&1; then
        echo "Strict code-signature verification failed."
        echo "Status: FAIL"
        return 1
    fi

    echo "Developer ID Application signature and Team ID verified."
    echo "Status: PASS"
}

verify_notarized_app() {
    local app_path="$1"
    local output command_status

    set +e
    output="$(spctl --assess --type execute --verbose=4 "$app_path" 2>&1)"
    command_status=$?
    set -e
    if [[ "$command_status" -ne 0 ]] \
        || ! printf '%s\n' "$output" | grep -Fq 'source=Notarized Developer ID'; then
        echo "spctl did not accept the app as Notarized Developer ID."
        echo "Status: FAIL"
        return 1
    fi

    echo "spctl accepted the app as Notarized Developer ID."
    echo "Status: PASS"
}

verify_upgrade_evidence() {
    local record_path="$1"
    local section_text scenario
    local required_scenarios=(
        "V1.0.0 baseline captured"
        "Manual update check"
        "Automatic update prompt"
        "Download, install, and restart"
        "History and favorites preserved"
        "Settings and shortcut preserved"
    )

    if [[ ! -f "$record_path" ]]; then
        echo "Upgrade evidence record is missing."
        echo "Status: WARN"
        return 1
    fi
    section_text="$(awk '
        /^## V1\.0\.0 → V1\.0\.1 Upgrade Evidence$/ {in_section=1; next}
        in_section && /^## / {exit}
        in_section {print}
    ' "$record_path")"
    if [[ -z "$section_text" ]]; then
        echo "Upgrade evidence section is missing."
        echo "Status: WARN"
        return 1
    fi

    for scenario in "${required_scenarios[@]}"; do
        if ! printf '%s\n' "$section_text" \
            | grep -F "| $scenario |" \
            | grep -Fq '| ✅ Pass |'; then
            echo "Upgrade evidence is incomplete for: $scenario"
            echo "Status: WARN"
            return 1
        fi
    done

    echo "All required V1.0.0 → V1.0.1 upgrade scenarios contain direct pass evidence."
    echo "Status: PASS"
}

collect_openspec_progress() {
    local tasks_file="$REPO_ROOT/openspec/changes/$openspec_change/tasks.md"
    local cli_output cli_error cli_note="" check_status="PASS"

    if [[ ! -f "$tasks_file" ]]; then
        add_check_row "OpenSpec progress" "FAIL" "Tasks file is missing for change $openspec_change."
        add_blocker "OpenSpec tasks file is missing for selected change $openspec_change."
        return
    fi

    openspec_summary=()
    while IFS= read -r line; do
        openspec_summary+=("$line")
    done < <(python3 - "$tasks_file" <<'PY'
import re
import sys

task_pattern = re.compile(r"^- \[([ xX])\] ([0-9]+(?:\.[0-9]+)+) (.+)$")
tasks = []
with open(sys.argv[1], encoding="utf-8") as handle:
    for raw_line in handle:
        match = task_pattern.match(raw_line.rstrip("\n"))
        if match:
            tasks.append(
                {
                    "done": match.group(1).lower() == "x",
                    "id": match.group(2),
                    "description": match.group(3),
                }
            )

complete = sum(task["done"] for task in tasks)
print(len(tasks))
print(complete)
print(len(tasks) - complete)
for task in tasks:
    if not task["done"]:
        print(f"{task['id']}\t{task['description']}")
PY
    )

    openspec_progress_total="${openspec_summary[0]:-0}"
    openspec_progress_complete="${openspec_summary[1]:-0}"
    openspec_progress_remaining="${openspec_summary[2]:-0}"
    openspec_remaining_tasks=()

    if [[ "$openspec_progress_total" -eq 0 ]]; then
        add_check_row "OpenSpec progress" "FAIL" "No task checkboxes were found for change $openspec_change."
        add_blocker "Selected OpenSpec change $openspec_change has no readable Markdown tasks."
        return
    fi

    local index
    for ((index = 3; index < ${#openspec_summary[@]}; index++)); do
        openspec_remaining_tasks+=("${openspec_summary[$index]}")
    done

    cli_output="$(mktemp)"
    cli_error="$(mktemp)"
    if ! command -v openspec >/dev/null 2>&1; then
        check_status="WARN"
        cli_note=" openspec CLI is not available."
        add_warning "openspec CLI is not available; Markdown progress for $openspec_change was included, but final readiness requires the CLI check."
    elif ! openspec instructions apply --change "$openspec_change" --json >"$cli_output" 2>"$cli_error"; then
        check_status="WARN"
        cli_note=" openspec CLI could not validate the selected change."
        add_warning "OpenSpec CLI could not validate change $openspec_change; inspect the selected change manually."
        detailed_sections+=("## OpenSpec CLI"$'\n\n```text\n'"$(cat "$cli_error")"$'\n```')
    fi
    rm -f "$cli_output" "$cli_error"

    if [[ "$openspec_progress_remaining" -gt 0 ]]; then
        check_status="WARN"
        add_warning "OpenSpec change $openspec_change still has $openspec_progress_remaining pending tasks."
    fi

    if [[ "$openspec_progress_remaining" -eq 0 ]]; then
        add_check_row \
            "OpenSpec progress" \
            "$check_status" \
            "$openspec_progress_complete/$openspec_progress_total tasks complete for $openspec_change.$cli_note"
    else
        add_check_row \
            "OpenSpec progress" \
            "$check_status" \
            "$openspec_progress_complete/$openspec_progress_total tasks complete for $openspec_change; $openspec_progress_remaining remaining.$cli_note"
    fi
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

if ! run_capture "Sparkle configuration" "$REPO_ROOT/scripts/verify-sparkle-configuration.sh"; then
    add_blocker "Sparkle version, feed, public key, service flags, or sandbox boundaries are invalid."
fi

if [[ -z "$formal_update_archive" ]]; then
    add_check_row "Formal update ZIP" "SKIP" "No --formal-update-archive provided."
    add_check_row "Embedded Sparkle framework and XPC services" "SKIP" "Formal update archive was not provided."
    add_check_row "Developer ID signature" "SKIP" "Formal update archive was not provided."
    add_check_row "Apple notarization" "SKIP" "Formal update archive was not provided."
    add_warning "Formal update ZIP, embedded Sparkle services, Developer ID signature, and notarization were not validated."
else
    require_command codesign
    require_command ditto
    require_command spctl

    if ! run_capture \
        "Formal update ZIP" \
        "$REPO_ROOT/scripts/verify-release-qa-package.sh" \
        --formal-update \
        "$formal_update_archive"; then
        add_blocker "Formal update ZIP failed checksum, identity, signature, notarization, or bundle validation."
    fi

    if [[ -f "$formal_update_archive" ]]; then
        readiness_extract_dir="$(mktemp -d /private/tmp/macpastehistory-readiness-update.XXXXXX)"
        case "$readiness_extract_dir" in
            /private/tmp/macpastehistory-readiness-update.*) ;;
            *)
                echo "Unsafe readiness extraction directory: $readiness_extract_dir" >&2
                exit 1
                ;;
        esac
        if /usr/bin/ditto -x -k "$formal_update_archive" "$readiness_extract_dir" >/dev/null 2>&1; then
            formal_app_path="$readiness_extract_dir/粘易.app"
        fi
    fi

    if [[ -d "$formal_app_path" ]]; then
        if ! run_capture \
            "Embedded Sparkle framework and XPC services" \
            "$REPO_ROOT/scripts/verify-sparkle-release-bundle.sh" \
            "$formal_app_path"; then
            add_blocker "Formal update app is missing the required Sparkle framework or XPC services."
        fi
        if ! run_capture "Developer ID signature" verify_developer_id_app "$formal_app_path"; then
            add_blocker "Formal update app is not signed with Developer ID Application."
        fi
        if ! run_capture "Apple notarization" verify_notarized_app "$formal_app_path"; then
            add_blocker "Formal update app is not accepted by spctl as notarized."
        fi
    else
        add_check_row "Embedded Sparkle framework and XPC services" "FAIL" "Formal update app could not be extracted."
        add_check_row "Developer ID signature" "FAIL" "Formal update app could not be extracted."
        add_check_row "Apple notarization" "FAIL" "Formal update app could not be extracted."
        add_blocker "Formal update archive does not contain the expected 粘易.app bundle."
    fi
fi

if [[ -z "$appcast_path" ]]; then
    add_check_row "Sparkle appcast" "SKIP" "No --appcast provided."
    add_warning "Sparkle appcast was not validated against a formal update ZIP."
elif [[ -z "$formal_update_archive" ]]; then
    add_check_row "Sparkle appcast" "FAIL" "--appcast also requires --formal-update-archive."
    add_blocker "Appcast validation requires the exact formal update ZIP."
else
    expected_public_key="$(
        /usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' \
            "$REPO_ROOT/MacPasteHistory/Resources/Info.plist" 2>/dev/null || true
    )"
    if ! run_capture \
        "Sparkle appcast" \
        "$REPO_ROOT/scripts/verify-sparkle-appcast.sh" \
        --appcast "$appcast_path" \
        --archive "$formal_update_archive" \
        --expected-public-key "$expected_public_key"; then
        add_blocker "Sparkle appcast failed URL, length, signature, checksum, version, bundle ID, or public-key validation."
    fi
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
if [[ -d "$formal_app_path" ]]; then
    release_app_signature_args+=("--app" "$formal_app_path")
fi
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

if ! run_capture "V1.0.0 → V1.0.1 upgrade evidence" verify_upgrade_evidence "$manual_record"; then
    add_warning "V1.0.0 → V1.0.1 upgrade evidence is incomplete; final release approval is blocked in --strict-final mode."
fi

git_status="$(git status --short)"
if [[ -z "$git_status" ]]; then
    add_check_row "Git worktree" "PASS" "Worktree is clean."
else
    add_check_row "Git worktree" "WARN" "Worktree has uncommitted changes."
    add_warning "Git worktree has uncommitted changes; commit or discard intentional changes before final release."
    detailed_sections+=("## Git Status"$'\n\n```text\n'"$git_status"$'\n```')
fi

collect_openspec_progress

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
| Formal update archive | \`$(escape_table_cell "${formal_update_archive:-not provided}")\` |
| Appcast | \`$(escape_table_cell "${appcast_path:-not provided}")\` |
| OpenSpec change | \`$(escape_table_cell "$openspec_change")\` |

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

## OpenSpec Remaining Tasks

EOF

    echo "| Progress | Value |"
    echo "|---|---|"
    echo "| Change | \`$openspec_change\` |"
    echo "| Complete | \`$openspec_progress_complete/$openspec_progress_total\` |"
    echo "| Remaining | \`$openspec_progress_remaining\` |"
    echo

    if [[ "${#openspec_remaining_tasks[@]}" -eq 0 ]]; then
        echo "- None."
    else
        for row in "${openspec_remaining_tasks[@]}"; do
            task_id="${row%%$'\t'*}"
            task_description="${row#*$'\t'}"
            printf -- "- %s: %s\n" "$task_id" "$task_description"
        done
    fi

    cat <<'EOF'

## Manual Evidence Still Required

- Signed Release build with the intended distribution certificate and Team ID.
- Developer ID notarization and a verified Sparkle appcast/formal ZIP pair.
- Direct V1.0.0 → V1.0.1 manual and automatic update evidence, including restart and data preservation.
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
    local openspec_tasks_path="$tmp_dir/openspec-tasks.tsv"

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
    if [[ "${#openspec_remaining_tasks[@]}" -gt 0 ]]; then
        printf "%s\n" "${openspec_remaining_tasks[@]}" >"$openspec_tasks_path"
    else
        : >"$openspec_tasks_path"
    fi

    mkdir -p "$(dirname "$json_output_path")"
    python3 - "$json_output_path" "$checks_path" "$blockers_path" "$warnings_path" "$openspec_tasks_path" <<PY
import json
import sys

json_path, checks_path, blockers_path, warnings_path, openspec_tasks_path = sys.argv[1:6]

checks = []
with open(checks_path, encoding="utf-8") as handle:
    for line in handle:
        name, status, notes = line.rstrip("\n").split("\t", 2)
        checks.append({"name": name, "status": status, "notes": notes})

def read_lines(path):
    with open(path, encoding="utf-8") as handle:
        return [line.rstrip("\n") for line in handle if line.strip()]

def read_openspec_tasks(path):
    tasks = []
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.rstrip("\n")
            if not line:
                continue
            task_id, description = line.split("\t", 1)
            tasks.append({"id": task_id, "description": description})
    return tasks

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
    "formalUpdateArchive": "${formal_update_archive}",
    "appcast": "${appcast_path}",
    "openSpecProgress": {
        "change": "$openspec_change",
        "total": int("$openspec_progress_total"),
        "complete": int("$openspec_progress_complete"),
        "remaining": int("$openspec_progress_remaining"),
    },
    "openSpecRemainingTasks": read_openspec_tasks(openspec_tasks_path),
    "checks": checks,
    "blockers": read_lines(blockers_path),
    "warnings": read_lines(warnings_path),
    "manualEvidenceStillRequired": [
        "Signed Release build with the intended distribution certificate and Team ID.",
        "Developer ID notarization and a verified Sparkle appcast/formal ZIP pair.",
        "Direct V1.0.0 to V1.0.1 manual and automatic update evidence, including restart and data preservation.",
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
