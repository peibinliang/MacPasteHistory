#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /private/tmp/macpastehistory-sparkle-artifacts.XXXXXX)"
EXPECTED_PUBLIC_KEY="$(
    /usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' \
        "$REPO_ROOT/MacPasteHistory/Resources/Info.plist"
)"
EXPECTED_URL="https://github.com/peibinliang/MacPasteHistory/releases/download/v1.0.1/%E7%B2%98%E6%98%93-1.0.1-2.zip"

case "$TEST_ROOT" in
    /private/tmp/macpastehistory-sparkle-artifacts.*) ;;
    *)
        echo "Unsafe temporary test directory: $TEST_ROOT" >&2
        exit 1
        ;;
esac

trap 'rm -rf "$TEST_ROOT"' EXIT

failures=()

add_failure() {
    failures+=("$1")
}

write_appcast() {
    local appcast_path="$1"
    local enclosure_url="$2"
    local enclosure_length="$3"
    local signature_attribute="$4"

    {
        printf '%s\n' '<?xml version="1.0" encoding="utf-8"?>'
        printf '%s\n' '<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">'
        printf '%s\n' '  <channel>'
        printf '%s\n' '    <title>Fixture updates</title>'
        printf '%s\n' '    <item>'
        printf '%s\n' '      <title>1.0.1</title>'
        printf '%s\n' '      <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>'
        printf '%s\n' '      <sparkle:version>2</sparkle:version>'
        printf '      <enclosure url="%s" length="%s" type="application/octet-stream"%s />\n' \
            "$enclosure_url" "$enclosure_length" "$signature_attribute"
        printf '%s\n' '    </item>'
        printf '%s\n' '  </channel>'
        printf '%s\n' '</rss>'
    } >"$appcast_path"
}

expect_failure_containing() {
    local label="$1"
    local expected_message="$2"
    shift 2
    local output=""

    if output="$("$@" 2>&1)"; then
        add_failure "$label: command unexpectedly passed."
        return
    fi
    if ! printf '%s\n' "$output" | grep -Fq "$expected_message"; then
        add_failure "$label: expected error '$expected_message', got '$output'."
    fi
}

expect_success() {
    local label="$1"
    shift
    local output=""

    if ! output="$("$@" 2>&1)"; then
        add_failure "$label: command failed with '$output'."
    fi
}

fixture_repo="$TEST_ROOT/repository"
release_dir="$fixture_repo/release"
archive_app="$TEST_ROOT/archive-root/粘易.app"
archive_path="$release_dir/粘易-1.0.1-2.zip"
appcast_path="$release_dir/appcast.xml"
source_plist="$fixture_repo/MacPasteHistory/Resources/Info.plist"

mkdir -p \
    "$fixture_repo/scripts" \
    "$fixture_repo/docs" \
    "$fixture_repo/MacPasteHistory/Resources" \
    "$release_dir" \
    "$archive_app/Contents/MacOS"

cp "$REPO_ROOT/scripts/verify-sparkle-appcast.sh" "$fixture_repo/scripts/verify-sparkle-appcast.sh" 2>/dev/null || true
cp "$REPO_ROOT/scripts/generate-sparkle-appcast.sh" "$fixture_repo/scripts/generate-sparkle-appcast.sh" 2>/dev/null || true
cp "$REPO_ROOT/MacPasteHistory/Resources/Info.plist" "$source_plist"

/usr/bin/plutil -create xml1 "$archive_app/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleIdentifier -string com.peibin.MacPasteHistory "$archive_app/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleShortVersionString -string 1.0.1 "$archive_app/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleVersion -string 2 "$archive_app/Contents/Info.plist"
/usr/bin/plutil -insert SUPublicEDKey -string "$EXPECTED_PUBLIC_KEY" "$archive_app/Contents/Info.plist"
cp /usr/bin/true "$archive_app/Contents/MacOS/粘易"
chmod +x "$archive_app/Contents/MacOS/粘易"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$archive_app" "$archive_path"
(
    cd "$release_dir"
    /usr/bin/shasum -a 256 "$(basename "$archive_path")" >"$(basename "$archive_path").sha256"
)
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"

write_appcast "$appcast_path" "$EXPECTED_URL" "$archive_length" ""
expect_failure_containing \
    "unsigned appcast" \
    "missing sparkle:edSignature" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    ' sparkle:edSignature="SYNTHETIC_FIXTURE_SIGNATURE"'
expect_success \
    "isolated valid appcast fixture" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

perl -pi -e 's/shortVersionString>1\.0\.1/shortVersionString>1.0.0/' "$appcast_path"
expect_failure_containing \
    "unexpected appcast short version" \
    "latest item short version is not 1.0.1" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

printf '%s\n' '<rss>' >"$appcast_path"
expect_failure_containing \
    "malformed appcast XML" \
    "appcast XML does not parse" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

wrong_url="https://example.invalid/粘易-1.0.1-2.zip"
write_appcast \
    "$appcast_path" \
    "$wrong_url" \
    "$archive_length" \
    ' sparkle:edSignature="SYNTHETIC_FIXTURE_SIGNATURE"'
expect_failure_containing \
    "unexpected enclosure URL" \
    "enclosure URL does not match" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$((archive_length + 1))" \
    ' sparkle:edSignature="SYNTHETIC_FIXTURE_SIGNATURE"'
expect_failure_containing \
    "unexpected enclosure length" \
    "enclosure length does not match archive" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    ' sparkle:edSignature="SYNTHETIC_FIXTURE_SIGNATURE"'
cp "$archive_path.sha256" "$TEST_ROOT/original-checksum"
printf '%064d  %s\n' 0 "$(basename "$archive_path")" >"$archive_path.sha256"
expect_failure_containing \
    "archive checksum mismatch" \
    "archive SHA-256 does not match adjacent checksum file" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"
cp "$TEST_ROOT/original-checksum" "$archive_path.sha256"

/usr/bin/plutil -replace CFBundleIdentifier -string com.example.invalid "$archive_app/Contents/Info.plist"
rm -f "$archive_path"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$archive_app" "$archive_path"
(
    cd "$release_dir"
    /usr/bin/shasum -a 256 "$(basename "$archive_path")" >"$(basename "$archive_path").sha256"
)
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    ' sparkle:edSignature="SYNTHETIC_FIXTURE_SIGNATURE"'
expect_failure_containing \
    "archive bundle identifier mismatch" \
    "archive bundle identifier is not com.peibin.MacPasteHistory" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

/usr/bin/plutil -replace CFBundleIdentifier -string com.peibin.MacPasteHistory "$archive_app/Contents/Info.plist"
rm -f "$archive_path"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$archive_app" "$archive_path"
(
    cd "$release_dir"
    /usr/bin/shasum -a 256 "$(basename "$archive_path")" >"$(basename "$archive_path").sha256"
)
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    ' sparkle:edSignature="SYNTHETIC_FIXTURE_SIGNATURE"'

wrong_public_key="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
expect_failure_containing \
    "source public key mismatch" \
    "expected public key does not match source Info.plist" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$wrong_public_key"

sparkle_bin="$TEST_ROOT/fake-sparkle-bin"
sparkle_args_record="$TEST_ROOT/generate-appcast-args.txt"
formal_gate_record="$TEST_ROOT/formal-gate-args.txt"
mkdir -p "$sparkle_bin"
cat >"$fixture_repo/scripts/verify-release-qa-package.sh" <<'FAKE_FORMAL_GATE'
#!/usr/bin/env bash
set -euo pipefail

: "${FORMAL_GATE_RECORD:?}"
printf '%s\n' "$@" >"$FORMAL_GATE_RECORD"
[[ "$#" -eq 2 && "$1" == "--formal-update" && -f "$2" ]]
FAKE_FORMAL_GATE
chmod +x "$fixture_repo/scripts/verify-release-qa-package.sh"
cat >"$sparkle_bin/generate_appcast" <<'FAKE_GENERATE_APPCAST'
#!/usr/bin/env bash
set -euo pipefail

: "${SPARKLE_ARGS_RECORD:?}"
printf '%s\n' "$@" >"$SPARKLE_ARGS_RECORD"
release_directory=""
for argument in "$@"; do
    release_directory="$argument"
done
archive_path="$release_directory/粘易-1.0.1-2.zip"
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
signature_attribute=' sparkle:edSignature="SYNTHETIC_FIXTURE_SIGNATURE"'
if [[ "${SPARKLE_UNSIGNED_FIXTURE:-0}" == "1" ]]; then
    signature_attribute=""
fi
cat >"$release_directory/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <item>
      <sparkle:shortVersionString>1.0.1</sparkle:shortVersionString>
      <sparkle:version>2</sparkle:version>
      <enclosure url="https://github.com/peibinliang/MacPasteHistory/releases/download/v1.0.1/%E7%B2%98%E6%98%93-1.0.1-2.zip" length="$archive_length"$signature_attribute />
    </item>
  </channel>
</rss>
EOF
FAKE_GENERATE_APPCAST
chmod +x "$sparkle_bin/generate_appcast"
rm -f "$release_dir/appcast.xml" "$fixture_repo/docs/appcast.xml"
export SPARKLE_ARGS_RECORD="$sparkle_args_record"
export FORMAL_GATE_RECORD="$formal_gate_record"
expect_success \
    "appcast generator verifies before copying" \
    "$fixture_repo/scripts/generate-sparkle-appcast.sh" \
    --release-directory "$release_dir" \
    --sparkle-bin-directory "$sparkle_bin"
unset SPARKLE_ARGS_RECORD FORMAL_GATE_RECORD

if [[ ! -f "$fixture_repo/docs/appcast.xml" ]]; then
    add_failure "appcast generator did not copy verified XML to docs/appcast.xml."
elif ! cmp -s "$release_dir/appcast.xml" "$fixture_repo/docs/appcast.xml"; then
    add_failure "copied docs/appcast.xml differs from the verified generated XML."
fi
expected_arguments="$TEST_ROOT/expected-generate-appcast-args.txt"
{
    echo "--download-url-prefix"
    echo "https://github.com/peibinliang/MacPasteHistory/releases/download/v1.0.1/"
    echo "--maximum-versions"
    echo "10"
    echo "$release_dir"
} >"$expected_arguments"
if ! cmp -s "$expected_arguments" "$sparkle_args_record"; then
    add_failure "generate_appcast did not receive the fixed prefix and maximum version arguments."
fi
if [[ "$(sed -n '1p' "$formal_gate_record")" != "--formal-update" \
    || "$(sed -n '2p' "$formal_gate_record")" != "$archive_path" ]]; then
    add_failure "generator did not verify the explicit archive through the formal update gate."
fi

cp "$fixture_repo/docs/appcast.xml" "$TEST_ROOT/verified-docs-appcast.xml"
export SPARKLE_ARGS_RECORD="$sparkle_args_record"
export FORMAL_GATE_RECORD="$formal_gate_record"
export SPARKLE_UNSIGNED_FIXTURE=1
expect_failure_containing \
    "generator refuses unsigned appcast" \
    "missing sparkle:edSignature" \
    "$fixture_repo/scripts/generate-sparkle-appcast.sh" \
    --release-directory "$release_dir" \
    --sparkle-bin-directory "$sparkle_bin"
unset SPARKLE_ARGS_RECORD FORMAL_GATE_RECORD SPARKLE_UNSIGNED_FIXTURE
if ! cmp -s "$fixture_repo/docs/appcast.xml" "$TEST_ROOT/verified-docs-appcast.xml"; then
    add_failure "generator changed docs/appcast.xml after unsigned verification failed."
fi

formal_app="$TEST_ROOT/formal/粘易.app"
mkdir -p "$formal_app/Contents"
cp "$archive_app/Contents/Info.plist" "$formal_app/Contents/Info.plist"
expect_failure_containing \
    "formal packaging rejects unsigned application" \
    "Developer ID Application signature is required" \
    "$REPO_ROOT/scripts/package-release-qa-build.sh" \
    --formal-update \
    --app "$formal_app" \
    --output-dir "$TEST_ROOT/formal-output"

expect_failure_containing \
    "formal archive verifier rejects unsigned application" \
    "Developer ID Application signature is required" \
    "$REPO_ROOT/scripts/verify-release-qa-package.sh" \
    --formal-update \
    "$archive_path"

echo "# Sparkle Release Artifact Tooling Self-Test"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Unsigned fixture | \`expected failure\` |"
echo "| Isolated signed-shape fixture | \`expected pass; not a formal EdDSA release\` |"
echo "| Appcast generation fixture | \`expected verified copy\` |"
echo "| Formal unsigned app fixture | \`expected failure\` |"
echo "| Failures | \`${#failures[@]}\` |"
echo

if [[ "${#failures[@]}" -eq 0 ]]; then
    echo "Status: PASS"
    exit 0
fi

echo "Status: FAIL"
echo
echo "## Failures"
echo
for failure in "${failures[@]}"; do
    echo "- $failure"
done
exit 1
