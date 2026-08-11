#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /private/tmp/macpastehistory-sparkle-artifacts.XXXXXX)"
EXPECTED_PUBLIC_KEY="$(
    /usr/libexec/PlistBuddy -c 'Print :SUPublicEDKey' \
        "$REPO_ROOT/MacPasteHistory/Resources/Info.plist"
)"
EXPECTED_URL="https://github.com/peibinliang/MacPasteHistory/releases/download/V1.0.2/MacPasteHistory-1.0.2-4.zip"
VALID_SIGNATURE_SHAPE="$(
    /bin/dd if=/dev/zero bs=64 count=1 2>/dev/null \
        | /usr/bin/base64 \
        | /usr/bin/tr -d '\r\n'
)"

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
        printf '%s\n' '      <title>1.0.2</title>'
        printf '%s\n' '      <sparkle:shortVersionString>1.0.2</sparkle:shortVersionString>'
        printf '%s\n' '      <sparkle:version>4</sparkle:version>'
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
archive_path="$release_dir/MacPasteHistory-1.0.2-4.zip"
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
/usr/bin/plutil -insert CFBundleShortVersionString -string 1.0.2 "$archive_app/Contents/Info.plist"
/usr/bin/plutil -insert CFBundleVersion -string 4 "$archive_app/Contents/Info.plist"
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
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
expect_success \
    "isolated valid-signature-shape appcast fixture" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    ' sparkle:edSignature="SYNTHETIC_FIXTURE_SIGNATURE"'
expect_failure_containing \
    "synthetic text is not an Ed25519 signature" \
    "sparkle:edSignature must be strict Base64 for a 64-byte Ed25519 signature" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
perl -pi -e 's#http://www\.andymatuschak\.org/xml-namespaces/sparkle#https://evil.invalid/sparkle#' \
    "$appcast_path"
expect_failure_containing \
    "evil Sparkle namespace" \
    "latest item must use the Sparkle namespace URI" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""

perl -pi -e 's/shortVersionString>1\.0\.2/shortVersionString>1.0.0/' "$appcast_path"
expect_failure_containing \
    "unexpected appcast short version" \
    "latest item short version is not 1.0.2" \
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

wrong_url="https://example.invalid/MacPasteHistory-1.0.2-4.zip"
write_appcast \
    "$appcast_path" \
    "$wrong_url" \
    "$archive_length" \
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
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
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
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
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
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
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
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
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""

wrong_public_key="AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
expect_failure_containing \
    "source public key mismatch" \
    "expected public key does not match source Info.plist" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$wrong_public_key"

cp "$archive_path" "$TEST_ROOT/normal-archive.zip"
cp "$archive_path.sha256" "$TEST_ROOT/normal-archive.zip.sha256"

/usr/bin/python3 - "$archive_path" "$archive_app" <<'PY'
import stat
import sys
import zipfile

archive_path, target = sys.argv[1:]
entry = zipfile.ZipInfo("粘易.app")
entry.create_system = 3
entry.external_attr = (stat.S_IFLNK | 0o777) << 16
with zipfile.ZipFile(archive_path, "w") as archive:
    archive.writestr(entry, target)
PY
(
    cd "$release_dir"
    /usr/bin/shasum -a 256 "$(basename "$archive_path")" >"$(basename "$archive_path").sha256"
)
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
expect_failure_containing \
    "appcast verifier rejects symlink-only app archive" \
    "top-level application path must not be a symbolic link" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"
expect_failure_containing \
    "formal package verifier rejects symlink-only app archive" \
    "top-level application path must not be a symbolic link" \
    "$REPO_ROOT/scripts/verify-release-qa-package.sh" \
    --formal-update \
    "$archive_path"

/usr/bin/python3 - "$archive_path" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w") as archive:
    archive.writestr("../escaped.txt", "must not escape extraction root")
PY
(
    cd "$release_dir"
    /usr/bin/shasum -a 256 "$(basename "$archive_path")" >"$(basename "$archive_path").sha256"
)
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
expect_failure_containing \
    "appcast verifier rejects zip-slip entry" \
    "unsafe archive entry path" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"
expect_failure_containing \
    "formal package verifier rejects zip-slip entry" \
    "unsafe archive entry path" \
    "$REPO_ROOT/scripts/verify-release-qa-package.sh" \
    --formal-update \
    "$archive_path"

/usr/bin/python3 - "$archive_path" <<'PY'
import sys
import zipfile

with zipfile.ZipFile(sys.argv[1], "w") as archive:
    archive.writestr("/absolute-escape.txt", "must not use an absolute extraction path")
PY
(
    cd "$release_dir"
    /usr/bin/shasum -a 256 "$(basename "$archive_path")" >"$(basename "$archive_path").sha256"
)
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
expect_failure_containing \
    "appcast verifier rejects absolute archive entry" \
    "unsafe archive entry path" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"
expect_failure_containing \
    "formal package verifier rejects absolute archive entry" \
    "unsafe archive entry path" \
    "$REPO_ROOT/scripts/verify-release-qa-package.sh" \
    --formal-update \
    "$archive_path"

cp "$TEST_ROOT/normal-archive.zip" "$archive_path"
cp "$TEST_ROOT/normal-archive.zip.sha256" "$archive_path.sha256"
outside_target="$TEST_ROOT/outside-target"
echo "outside extraction root" >"$outside_target"
ln -s "$outside_target" "$archive_app/Contents/EscapeLink"
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
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
expect_failure_containing \
    "appcast verifier rejects escaping bundle symlink" \
    "bundle symlink escapes application bundle" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"
expect_failure_containing \
    "formal package verifier rejects escaping bundle symlink" \
    "bundle symlink escapes application bundle" \
    "$REPO_ROOT/scripts/verify-release-qa-package.sh" \
    --formal-update \
    "$archive_path"

rm "$archive_app/Contents/EscapeLink"
outside_app_staging="$TEST_ROOT/outside-app-staging"
mkdir -p "$outside_app_staging/__MACOSX"
/usr/bin/ditto "$archive_app" "$outside_app_staging/粘易.app"
echo "outside the application bundle" >"$outside_app_staging/__MACOSX/target"
ln -s "../../__MACOSX/target" "$outside_app_staging/粘易.app/Contents/EscapeLink"
rm -f "$archive_path"
/usr/bin/ditto -c -k --sequesterRsrc "$outside_app_staging" "$archive_path"
(
    cd "$release_dir"
    /usr/bin/shasum -a 256 "$(basename "$archive_path")" >"$(basename "$archive_path").sha256"
)
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
expect_failure_containing \
    "appcast verifier rejects bundle symlink outside app" \
    "bundle symlink escapes application bundle" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"

ln -s "Info.plist" "$archive_app/Contents/InternalInfoLink"
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
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""
expect_success \
    "appcast verifier allows internal bundle symlink" \
    "$fixture_repo/scripts/verify-sparkle-appcast.sh" \
    --appcast "$appcast_path" \
    --archive "$archive_path" \
    --expected-public-key "$EXPECTED_PUBLIC_KEY"
rm "$archive_app/Contents/InternalInfoLink"

cp "$TEST_ROOT/normal-archive.zip" "$archive_path"
cp "$TEST_ROOT/normal-archive.zip.sha256" "$archive_path.sha256"
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
write_appcast \
    "$appcast_path" \
    "$EXPECTED_URL" \
    "$archive_length" \
    " sparkle:edSignature=\"$VALID_SIGNATURE_SHAPE\""

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
archive_path="$release_directory/MacPasteHistory-1.0.2-4.zip"
archive_length="$(/usr/bin/stat -f '%z' "$archive_path")"
valid_signature_shape="$(
    /bin/dd if=/dev/zero bs=64 count=1 2>/dev/null \
        | /usr/bin/base64 \
        | /usr/bin/tr -d '\r\n'
)"
signature_attribute=" sparkle:edSignature=\"$valid_signature_shape\""
if [[ "${SPARKLE_UNSIGNED_FIXTURE:-0}" == "1" ]]; then
    signature_attribute=""
fi
cat >"$release_directory/appcast.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <item>
      <sparkle:shortVersionString>1.0.2</sparkle:shortVersionString>
      <sparkle:version>4</sparkle:version>
      <enclosure url="https://github.com/peibinliang/MacPasteHistory/releases/download/V1.0.2/MacPasteHistory-1.0.2-4.zip" length="$archive_length"$signature_attribute />
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
    echo "https://github.com/peibinliang/MacPasteHistory/releases/download/V1.0.2/"
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

package_fixture="$TEST_ROOT/package-fixture"
package_fake_bin="$package_fixture/fake-bin"
package_app="$package_fixture/input/粘易.app"
package_output="$package_fixture/output"
package_verify_record="$package_fixture/package-verify-args.txt"
package_release_notes="$package_fixture/release-notes.md"
mkdir -p "$package_fixture/scripts" "$package_fake_bin" "$package_fixture/input"
cp "$REPO_ROOT/scripts/package-release-qa-build.sh" "$package_fixture/scripts/package-release-qa-build.sh"
/usr/bin/ditto "$archive_app" "$package_app"
echo "Synthetic fixture release notes." >"$package_release_notes"

cat >"$package_fake_bin/codesign" <<'FAKE_CODESIGN'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == "-dvvv" ]]; then
    {
        echo "Signature size=9000"
        echo "Authority=Developer ID Application: Synthetic Fixture (TESTTEAM01)"
        echo "TeamIdentifier=TESTTEAM01"
    } >&2
fi
exit 0
FAKE_CODESIGN
cat >"$package_fake_bin/spctl" <<'FAKE_SPCTL'
#!/usr/bin/env bash
set -euo pipefail
echo "synthetic fixture: accepted"
echo "source=Notarized Developer ID"
FAKE_SPCTL
cat >"$package_fixture/scripts/verify-sparkle-release-bundle.sh" <<'FAKE_BUNDLE_VERIFY'
#!/usr/bin/env bash
set -euo pipefail
[[ "$#" -eq 1 && -d "$1" ]]
FAKE_BUNDLE_VERIFY
cat >"$package_fixture/scripts/verify-release-qa-package.sh" <<'FAKE_PACKAGE_VERIFY'
#!/usr/bin/env bash
set -euo pipefail
: "${PACKAGE_VERIFY_RECORD:?}"
[[ "$#" -eq 2 && "$1" == "--formal-update" && -f "$2" && -f "$2.sha256" ]]
printf '%s\n' "$@" >"$PACKAGE_VERIFY_RECORD"
FAKE_PACKAGE_VERIFY
chmod +x \
    "$package_fake_bin/codesign" \
    "$package_fake_bin/spctl" \
    "$package_fixture/scripts/verify-sparkle-release-bundle.sh" \
    "$package_fixture/scripts/verify-release-qa-package.sh"

expect_failure_containing \
    "formal packaging rejects output inside app" \
    "formal output directory must not be the app bundle or inside it" \
    env PATH="$package_fake_bin:$PATH" \
    "$package_fixture/scripts/package-release-qa-build.sh" \
    --formal-update \
    --app "$package_app" \
    --output-dir "$package_app/Contents/ReleaseOutput"

mkdir -p "$package_app/Contents/AliasedReleaseOutput"
package_output_alias="$package_fixture/output-alias"
ln -s "$package_app/Contents/AliasedReleaseOutput" "$package_output_alias"
expect_failure_containing \
    "formal packaging canonicalizes output symlink into app" \
    "formal output directory must not be the app bundle or inside it" \
    env PATH="$package_fake_bin:$PATH" \
    "$package_fixture/scripts/package-release-qa-build.sh" \
    --formal-update \
    --app "$package_app" \
    --output-dir "$package_output_alias"

package_app_link="$package_fixture/input/AppLink.app"
ln -s "$package_app" "$package_app_link"
expect_failure_containing \
    "formal packaging rejects symlink app input" \
    "formal update app path must not be a symbolic link" \
    env PATH="$package_fake_bin:$PATH" \
    "$package_fixture/scripts/package-release-qa-build.sh" \
    --formal-update \
    --app "$package_app_link" \
    --output-dir "$package_output"
expect_failure_containing \
    "formal packaging rejects symlink app input with trailing slash" \
    "formal update app path must not be a symbolic link" \
    env PATH="$package_fake_bin:$PATH" \
    "$package_fixture/scripts/package-release-qa-build.sh" \
    --formal-update \
    --app "$package_app_link/" \
    --output-dir "$package_output"

export PACKAGE_VERIFY_RECORD="$package_verify_record"
expect_success \
    "formal packaging verifies staged archive before success" \
    env PATH="$package_fake_bin:$PATH" \
    "$package_fixture/scripts/package-release-qa-build.sh" \
    --formal-update \
    --app "$package_app" \
    --output-dir "$package_output" \
    --release-notes "$package_release_notes"
unset PACKAGE_VERIFY_RECORD
if [[ ! -f "$package_output/MacPasteHistory-1.0.2-4.zip" \
    || ! -f "$package_output/MacPasteHistory-1.0.2-4.zip.sha256" \
    || ! -f "$package_output/MacPasteHistory-1.0.2-4-release-notes.md" ]]; then
    add_failure "formal packaging did not produce all three expected artifacts."
fi
if [[ ! -f "$package_verify_record" \
    || "$(sed -n '1p' "$package_verify_record")" != "--formal-update" ]]; then
    add_failure "formal packaging did not verify the staged archive before success."
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
