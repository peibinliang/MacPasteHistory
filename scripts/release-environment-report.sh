#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE_ID="com.peibin.MacPasteHistory"
COMMON_APPS=(
    "Google Chrome:/Applications/Google Chrome.app"
    "Safari:/Applications/Safari.app"
    "VS Code:/Applications/Visual Studio Code.app"
    "WeChat:/Applications/WeChat.app"
    "DingTalk:/Applications/DingTalk.app"
)

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

checkbox() {
    local condition="$1"
    if [[ "$condition" == "true" ]]; then
        printf "[x]"
    else
        printf "[ ]"
    fi
}

require_command sw_vers
require_command uname
require_command sysctl
require_command xcode-select
require_command xcodebuild
require_command security

machine_arch="$(uname -m)"
chip_name="$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo "unknown")"
macos_version="$(sw_vers -productVersion)"
macos_build="$(sw_vers -buildVersion)"
xcode_path="$(xcode-select -p)"
xcode_version="$(xcodebuild -version | tr '\n' ' ')"
identity_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
identity_count="$(printf "%s\n" "$identity_output" | awk '/valid identities found/ {print $1; found=1} END {if (!found) print 0}')"

echo "# Local Release Environment Report"
echo
echo "Generated: $(date '+%Y-%m-%d %H:%M:%S %z')"
echo
echo "## Machine"
echo
echo "- Architecture: \`$machine_arch\`"
echo "- CPU: \`$chip_name\`"
echo "- macOS: \`$macos_version ($macos_build)\`"
echo
echo "## Xcode"
echo
echo "- Developer directory: \`$xcode_path\`"
echo "- Version: \`$xcode_version\`"
if xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1; then
    echo "- First launch status: passed"
else
    echo "- First launch status: not complete"
fi
if xcodebuild -license status >/dev/null 2>&1; then
    echo "- License status: accepted"
else
    echo "- License status: not accepted"
fi
echo
echo "## Signing"
echo
echo "- Bundle identifier: \`$APP_BUNDLE_ID\`"
echo "- Valid code signing identities: \`$identity_count\`"
if [[ "$identity_count" -eq 0 ]]; then
    echo "- Distribution readiness: blocked until an Apple Development, Apple Distribution, or Developer ID Application identity is installed."
else
    echo "- Distribution readiness: signing identities are available; verify the correct Team and distribution method in Xcode."
fi
echo
echo "## Common App Availability"
echo
for entry in "${COMMON_APPS[@]}"; do
    app_name="${entry%%:*}"
    app_path="${entry#*:}"
    if [[ -d "$app_path" ]]; then
        echo "- $(checkbox true) $app_name: \`$app_path\`"
    else
        echo "- $(checkbox false) $app_name: \`$app_path\`"
    fi
done
echo
echo "## Compatibility Notes"
echo
if [[ "$machine_arch" == "arm64" ]]; then
    echo "- Current machine can provide Apple Silicon evidence."
    echo "- Intel Mac evidence is still required from separate hardware or equivalent CI."
else
    echo "- Current machine can provide Intel evidence."
    echo "- Apple Silicon evidence is still required from separate hardware or equivalent CI."
fi
echo "- Supported macOS version coverage is limited to the current machine unless additional devices or VMs are used."
