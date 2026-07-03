#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCHEME="MacPasteHistory"
BUNDLE_ID="com.peibin.MacPasteHistory"
COMMON_APPS=(
    "Google Chrome:/Applications/Google Chrome.app"
    "Safari:/Applications/Safari.app"
    "VS Code:/Applications/Visual Studio Code.app"
    "WeChat:/Applications/WeChat.app"
    "DingTalk:/Applications/DingTalk.app"
)

should_build=0
app_path=""

usage() {
    cat <<'EOF'
Usage: scripts/release-qa-baseline.sh [options]

Print a Markdown baseline for manual Release QA evidence.

Options:
  --build        Build the Release app before collecting evidence.
  --app <path>   Collect evidence for a specific .app bundle.
  -h, --help     Show this help.
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

checkbox() {
    local condition="$1"
    if [[ "$condition" == "true" ]]; then
        printf "[x]"
    else
        printf "[ ]"
    fi
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

while [[ $# -gt 0 ]]; do
    case "$1" in
        --build)
            should_build=1
            ;;
        --app)
            if [[ $# -lt 2 ]]; then
                echo "--app requires a path" >&2
                exit 2
            fi
            app_path="$2"
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
require_command git
require_command security
require_command sw_vers
require_command sysctl
require_command uname
require_command xcode-select
require_command xcodebuild

cd "$REPO_ROOT"

if [[ "$should_build" -eq 1 ]]; then
    scripts/preview-release-app.sh --build-only >/tmp/macpastehistory-release-qa-baseline-build.log
fi

if [[ -z "$app_path" ]]; then
    app_path="$(release_app_path)"
fi

if [[ ! -d "$app_path" ]]; then
    echo "Release app not found at $app_path" >&2
    echo "Run with --build or pass --app <path>." >&2
    exit 1
fi

info_plist="$app_path/Contents/Info.plist"
version="$(plist_value "$info_plist" CFBundleShortVersionString)"
build_number="$(plist_value "$info_plist" CFBundleVersion)"
git_commit="$(git rev-parse --short HEAD 2>/dev/null || printf "unknown")"
git_dirty="$(git status --short 2>/dev/null || true)"
machine_arch="$(uname -m)"
chip_name="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || printf "unknown")"
macos_version="$(sw_vers -productVersion)"
macos_build="$(sw_vers -buildVersion)"
xcode_path="$(xcode-select -p)"
xcode_version="$(xcodebuild -version | paste -sd ' ' -)"
identity_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
identity_count="$(printf "%s\n" "$identity_output" | awk '/valid identities found/ {print $1; found=1} END {if (!found) print 0}')"
codesign_output="$(codesign -dvv "$app_path" 2>&1 || true)"
authority="$(printf "%s\n" "$codesign_output" | awk -F= '/^Authority=/ {print $2; exit}')"
team_identifier="$(printf "%s\n" "$codesign_output" | awk -F= '/^TeamIdentifier=/ {print $2; exit}')"
signature="$(printf "%s\n" "$codesign_output" | awk -F= '/^Signature=/ {print $2; exit}')"
entitlements_output="$(codesign -d --entitlements :- "$app_path" 2>/dev/null || true)"
sandbox_status="missing"

if printf "%s\n" "$entitlements_output" | grep -q "com.apple.security.app-sandbox"; then
    sandbox_status="present"
fi

if [[ -z "$authority" ]]; then
    authority="not available"
fi
if [[ -z "$team_identifier" ]]; then
    team_identifier="not set"
fi
if [[ -z "$signature" ]]; then
    signature="unknown"
fi

echo "# Release QA Baseline"
echo
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo
echo "## Build Under Test"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Git commit | \`$git_commit\` |"
if [[ -n "$git_dirty" ]]; then
    echo "| Git worktree | Dirty; review \`git status --short\` before final approval. |"
else
    echo "| Git worktree | Clean |"
fi
echo "| App path | \`$app_path\` |"
echo "| Version / build | \`$version ($build_number)\` |"
echo "| Bundle identifier | \`$BUNDLE_ID\` |"
echo
echo "## Machine And Toolchain"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Architecture | \`$machine_arch\` |"
echo "| CPU | \`$chip_name\` |"
echo "| macOS | \`$macos_version ($macos_build)\` |"
echo "| Xcode developer directory | \`$xcode_path\` |"
echo "| Xcode version | \`$xcode_version\` |"
if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    echo "| Xcode first launch | Passed |"
else
    echo "| Xcode first launch | Not complete |"
fi
if xcodebuild -license check >/dev/null 2>&1; then
    echo "| Xcode license | Accepted |"
else
    echo "| Xcode license | Not accepted |"
fi
echo
echo "## Signing And Sandbox"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Available local code signing identities | \`$identity_count\` |"
echo "| App signature | \`$signature\` |"
echo "| Authority | \`$authority\` |"
echo "| Team identifier | \`$team_identifier\` |"
echo "| App Sandbox entitlement | \`$sandbox_status\` |"
if [[ "$identity_count" -eq 0 ]]; then
    echo "| Distribution signing status | Blocked until a valid Apple Development, Apple Distribution, or Developer ID Application identity is installed. |"
else
    echo "| Distribution signing status | Signing identities are available; verify the selected Team and distribution method. |"
fi
echo
echo "## Common App Availability"
echo
echo "| App | Path | Installed |"
echo "|---|---|---|"
for entry in "${COMMON_APPS[@]}"; do
    app_name="${entry%%:*}"
    common_app_path="${entry#*:}"
    if [[ -d "$common_app_path" ]]; then
        echo "| $app_name | \`$common_app_path\` | $(checkbox true) |"
    else
        echo "| $app_name | \`$common_app_path\` | $(checkbox false) |"
    fi
done
echo
echo "## Manual Evidence Still Required"
echo
echo "- Menu bar icon visibility and history window behavior."
echo "- Text and image restore into real target apps."
echo "- Clear All Data through the Release UI."
echo "- Launch at login after logout/login or restart."
echo "- Intel Mac and additional supported macOS version coverage where available."
