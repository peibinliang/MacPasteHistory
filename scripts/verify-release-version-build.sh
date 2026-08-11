#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFO_PLIST="$REPO_ROOT/MacPasteHistory/Resources/Info.plist"
RELEASE_GUIDE="$REPO_ROOT/docs/release/RELEASE_PREP_GUIDE.md"
MANUAL_QA_RECORD="$REPO_ROOT/docs/release/manual-qa-record.md"

EXPECTED_VERSION="1.0.2"
EXPECTED_BUILD="3"
EXPECTED_VERSION_BUILD="$EXPECTED_VERSION ($EXPECTED_BUILD)"

add_violation() {
    violations+=("$1")
}

plist_value() {
    local key="$1"
    /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" 2>/dev/null || true
}

violations=()

plist_version="$(plist_value CFBundleShortVersionString)"
plist_build="$(plist_value CFBundleVersion)"

if [[ "$plist_version" != "$EXPECTED_VERSION" ]]; then
    add_violation "Info.plist CFBundleShortVersionString is '$plist_version', expected '$EXPECTED_VERSION'."
fi

if [[ "$plist_build" != "$EXPECTED_BUILD" ]]; then
    add_violation "Info.plist CFBundleVersion is '$plist_build', expected '$EXPECTED_BUILD'."
fi

if ! grep -Fq "> **版本**: v$EXPECTED_VERSION |" "$RELEASE_GUIDE"; then
    add_violation "Release guide header does not mention v$EXPECTED_VERSION."
fi

if ! grep -Fq "CFBundleShortVersionString\`: \`$EXPECTED_VERSION\`" "$RELEASE_GUIDE"; then
    add_violation "Release guide does not document CFBundleShortVersionString as $EXPECTED_VERSION."
fi

if ! grep -Fq "CFBundleVersion\`: \`$EXPECTED_BUILD\`" "$RELEASE_GUIDE"; then
    add_violation "Release guide does not document CFBundleVersion as $EXPECTED_BUILD."
fi

if ! grep -Fq "版本号为 \`$EXPECTED_VERSION_BUILD\`" "$RELEASE_GUIDE"; then
    add_violation "Release guide acceptance checklist does not mention version $EXPECTED_VERSION_BUILD."
fi

if ! grep -Fq "| Version / build | \`$EXPECTED_VERSION_BUILD\` |" "$MANUAL_QA_RECORD"; then
    add_violation "Manual QA record template does not use Version / build '$EXPECTED_VERSION_BUILD'."
fi

echo "# Release Version And Build Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Expected version | \`$EXPECTED_VERSION\` |"
echo "| Expected build | \`$EXPECTED_BUILD\` |"
echo "| Expected version / build | \`$EXPECTED_VERSION_BUILD\` |"
echo "| Info.plist CFBundleShortVersionString | \`$plist_version\` |"
echo "| Info.plist CFBundleVersion | \`$plist_build\` |"
echo "| Violations | \`${#violations[@]}\` |"
echo

if [[ "${#violations[@]}" -eq 0 ]]; then
    echo "Status: PASS"
    exit 0
fi

echo "Status: FAIL"
echo
echo "## Violations"
echo
for violation in "${violations[@]}"; do
    echo "- $violation"
done

exit 1
