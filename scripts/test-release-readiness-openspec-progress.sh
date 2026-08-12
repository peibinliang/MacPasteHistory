#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_ROOT="$(mktemp -d /private/tmp/macpastehistory-readiness-openspec.XXXXXX)"
CURRENT_CHANGE="add-v1-0-1-sensitive-filter-and-updates"
LEGACY_CHANGE="prepare-release-testing-and-store-assets"
FENCED_FIXTURE="$REPO_ROOT/scripts/fixtures/release-readiness-openspec-fenced-tasks.md"
FENCED_CHANGE="test-readiness-fences-${TEST_ROOT##*.}"
FENCED_CHANGE_DIR="$REPO_ROOT/openspec/changes/$FENCED_CHANGE"

case "$TEST_ROOT" in
    /private/tmp/macpastehistory-readiness-openspec.*) ;;
    *)
        echo "Unsafe temporary test directory: $TEST_ROOT" >&2
        exit 1
        ;;
esac

cleanup() {
    case "$FENCED_CHANGE_DIR" in
        "$REPO_ROOT"/openspec/changes/test-readiness-fences-*)
            rm -rf "$FENCED_CHANGE_DIR"
            ;;
        *)
            echo "Refusing to remove unexpected fenced fixture directory" >&2
            ;;
    esac
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

mkdir -p "$FENCED_CHANGE_DIR"
cp "$FENCED_FIXTURE" "$FENCED_CHANGE_DIR/tasks.md"

failures=()

add_failure() {
    failures+=("$1")
}

run_readiness() {
    local label="$1"
    local json_path="$2"
    shift 2
    local output_path="$TEST_ROOT/$label.txt"

    set +e
    env PATH="/usr/bin:/bin:/usr/sbin:/sbin" \
        "$REPO_ROOT/scripts/release-readiness-report.sh" \
        --skip-xcodegen \
        --skip-release-smoke \
        --skip-install-preflight \
        --allow-adhoc \
        --json-output "$json_path" \
        "$@" >"$output_path" 2>&1
    local status=$?
    set -e

    if [[ "$status" -eq 0 ]]; then
        add_failure "$label: incomplete readiness fixture unexpectedly passed."
    fi
    if [[ ! -s "$json_path" ]]; then
        add_failure "$label: JSON summary was not produced."
    fi
}

assert_progress() {
    local label="$1"
    local json_path="$2"
    local expected_change="$3"
    local expected_complete="$4"
    local expected_total="$5"
    local expected_remaining="$6"

    if [[ ! -s "$json_path" ]]; then
        return
    fi

    if ! /usr/bin/python3 - \
        "$json_path" \
        "$expected_change" \
        "$expected_complete" \
        "$expected_total" \
        "$expected_remaining" <<'PY'
import json
import sys

json_path, expected_change, expected_complete, expected_total, expected_remaining = sys.argv[1:]
with open(json_path, encoding="utf-8") as handle:
    payload = json.load(handle)

progress = payload["openSpecProgress"]
expected = {
    "change": expected_change,
    "complete": int(expected_complete),
    "total": int(expected_total),
    "remaining": int(expected_remaining),
}
if progress != expected:
    raise SystemExit(f"expected progress {expected}, got {progress}")

progress_checks = [row for row in payload["checks"] if row["name"] == "OpenSpec progress"]
if len(progress_checks) != 1:
    raise SystemExit(f"expected one OpenSpec progress check, got {progress_checks}")
check = progress_checks[0]
if check["status"] != "WARN":
    raise SystemExit(f"expected WARN without openspec CLI, got {check}")
if f"{expected_complete}/{expected_total}" not in check["notes"]:
    raise SystemExit(f"Markdown progress missing from check notes: {check}")
if "CLI is not available" not in check["notes"]:
    raise SystemExit(f"CLI warning missing from check notes: {check}")

warnings = payload["warnings"]
if not any("openspec CLI is not available" in warning for warning in warnings):
    raise SystemExit(f"CLI warning missing from JSON warnings: {warnings}")
PY
    then
        add_failure "$label: JSON did not contain the selected Markdown task progress."
    fi
}

default_json="$TEST_ROOT/default.json"
run_readiness "default" "$default_json" --strict-final
assert_progress "default" "$default_json" "$CURRENT_CHANGE" 24 32 8

if [[ -s "$default_json" ]] && ! /usr/bin/python3 - "$default_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)

checks = [row for row in payload["checks"] if row["name"] == "Update identity continuity"]
if len(checks) != 1 or checks[0]["status"] != "SKIP":
    raise SystemExit(f"expected one skipped update identity check, got {checks}")
if not any("Accessibility permission continuity" in warning for warning in payload["warnings"]):
    raise SystemExit("missing Accessibility permission continuity warning")
PY
then
    add_failure "default: missing update identity continuity release gate."
fi

if [[ -s "$default_json" ]] && ! /usr/bin/python3 - "$default_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if not any("Strict final mode requires zero warnings" in blocker for blocker in payload["blockers"]):
    raise SystemExit("strict-final did not block the missing CLI and pending V1.0.1 tasks")
PY
then
    add_failure "default: strict-final did not block warnings from the selected V1.0.1 change."
fi

explicit_current_json="$TEST_ROOT/explicit-current.json"
run_readiness \
    "explicit-current" \
    "$explicit_current_json" \
    --openspec-change "$CURRENT_CHANGE"
assert_progress "explicit-current" "$explicit_current_json" "$CURRENT_CHANGE" 24 32 8

legacy_json="$TEST_ROOT/legacy.json"
run_readiness \
    "legacy" \
    "$legacy_json" \
    --openspec-change "$LEGACY_CHANGE"
assert_progress "legacy" "$legacy_json" "$LEGACY_CHANGE" 4 19 15

special_manual_record=$'docs/release/manual-"quoted"\\record\nUnicode 雪\npayload __import__("pathlib")'
special_appcast=$'appcast-"quoted"\\feed\nUnicode 雪\n__import__("pathlib")'
escaping_json="$TEST_ROOT/escaping.json"
run_readiness \
    "escaping" \
    "$escaping_json" \
    --manual-record "$special_manual_record" \
    --appcast "$special_appcast"
if [[ -s "$escaping_json" ]] && ! /usr/bin/python3 - \
    "$escaping_json" \
    "$special_manual_record" \
    "$special_appcast" <<'PY'
import json
import sys

json_path, expected_manual_record, expected_appcast = sys.argv[1:]
with open(json_path, encoding="utf-8") as handle:
    payload = json.load(handle)
if payload["manualQaRecord"] != expected_manual_record:
    raise SystemExit("manual QA record did not round-trip exactly")
if payload["appcast"] != expected_appcast:
    raise SystemExit("appcast path did not round-trip exactly")
PY
then
    add_failure "escaping: controlled strings did not produce valid JSON with exact values."
fi

injection_marker="$TEST_ROOT/python-injection-marker"
marker_hex="$(printf '%s' "$injection_marker" | /usr/bin/xxd -p | /usr/bin/tr -d '\n')"
printf -v injection_manual_record \
    'docs/release/x",\n    "pwn": __import__("pathlib").Path(bytes.fromhex("%s").decode()).write_text("executed"),\n    "manualQaRecord2": "y' \
    "$marker_hex"
injection_json="$TEST_ROOT/injection.json"
run_readiness \
    "injection" \
    "$injection_json" \
    --manual-record "$injection_manual_record"
if [[ -e "$injection_marker" ]]; then
    add_failure "injection: a controlled manual-record value executed Python code."
fi
if [[ -s "$injection_json" ]] && ! /usr/bin/python3 - \
    "$injection_json" \
    "$injection_manual_record" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
if payload["manualQaRecord"] != sys.argv[2]:
    raise SystemExit("injection-shaped manual record did not remain inert data")
if "pwn" in payload:
    raise SystemExit("injection-shaped manual record created an extra JSON field")
PY
then
    add_failure "injection: payload-shaped input was not serialized as inert JSON data."
fi

fenced_json="$TEST_ROOT/fenced.json"
run_readiness \
    "fenced" \
    "$fenced_json" \
    --openspec-change "$FENCED_CHANGE"
assert_progress "fenced" "$fenced_json" "$FENCED_CHANGE" 2 3 1
if [[ -s "$fenced_json" ]] && ! /usr/bin/python3 - "$fenced_json" <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as handle:
    payload = json.load(handle)
expected = [{"id": "1.2", "description": 'Pending "quoted" \\ path — 雪'}]
if payload["openSpecRemainingTasks"] != expected:
    raise SystemExit(
        f"expected quoted Unicode task outside fences only, got {payload['openSpecRemainingTasks']}"
    )
PY
then
    add_failure "fenced: code-fence checkboxes or task text were parsed incorrectly."
fi

echo "# Release Readiness OpenSpec Progress Self-Test"
echo
echo "| Field | Value |"
echo "|---|---|"
echo "| Default change | \`$CURRENT_CHANGE\` |"
echo "| Default Markdown progress | \`24/32; 8 remaining\` |"
echo "| Explicit legacy progress | \`4/19; 15 remaining\` |"
echo "| JSON escaping/injection fixtures | \`expected inert round-trip\` |"
echo "| Fenced checkbox fixture | \`2/3; 1 remaining\` |"
echo "| openspec CLI fixture | \`intentionally unavailable\` |"
echo "| Failures | \`${#failures[@]}\` |"
echo

if [[ "${#failures[@]}" -eq 0 ]]; then
    echo "Status: PASS"
    exit 0
fi

echo "Status: FAIL"
echo
echo "## Failures"
for failure in "${failures[@]}"; do
    echo "- $failure"
done
exit 1
