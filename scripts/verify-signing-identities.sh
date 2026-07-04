#!/usr/bin/env bash
set -euo pipefail

allow_adhoc=0

usage() {
    cat <<'EOF'
Usage: scripts/verify-signing-identities.sh [options]

Verify local macOS code signing identities for Release QA and distribution.

Options:
  --allow-adhoc  Treat missing identities as WARN for internal QA only.
  -h, --help     Show this help.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --allow-adhoc)
            allow_adhoc=1
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

identity_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
identity_count="$(printf "%s\n" "$identity_output" | awk '/valid identities found/ {print $1; found=1} END {if (!found) print 0}')"
development_count="$(printf "%s\n" "$identity_output" | grep -Ec '"Apple Development:|Mac Developer:|iPhone Developer:' || true)"
distribution_count="$(printf "%s\n" "$identity_output" | grep -Ec '"Apple Distribution:|Developer ID Application:|3rd Party Mac Developer Application:' || true)"

echo "# Signing Identity Verification"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Valid code signing identities | \`$identity_count\` |"
echo "| Development-capable identities | \`$development_count\` |"
echo "| Distribution-capable identities | \`$distribution_count\` |"
echo "| Ad-hoc allowed | \`$([[ "$allow_adhoc" -eq 1 ]] && printf "yes" || printf "no")\` |"
echo

if [[ "$identity_count" -gt 0 ]]; then
    echo "Status: PASS"
    echo
    echo "## Identities"
    echo
    echo '```text'
    printf "%s\n" "$identity_output"
    echo '```'
    exit 0
fi

if [[ "$allow_adhoc" -eq 1 ]]; then
    echo "Status: WARN"
    echo
    echo "## Warning"
    echo
    echo "- No valid code signing identities are installed. This is acceptable only for local or internal QA using ad-hoc signing."
    echo "- Formal distribution remains blocked until an Apple Development, Apple Distribution, or Developer ID Application identity is installed."
    echo
    echo "## Identities"
    echo
    echo '```text'
    printf "%s\n" "$identity_output"
    echo '```'
    exit 0
fi

echo "Status: FAIL"
echo
echo "## Blocker"
echo
echo "- No valid code signing identities are installed."
echo "- Install an Apple Development identity for development QA, or an Apple Distribution / Developer ID Application identity for formal distribution."
echo
echo "## Identities"
echo
echo '```text'
printf "%s\n" "$identity_output"
echo '```'

exit 1
