#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_dir=""
generated_dir=""

usage() {
    cat <<'EOF'
Usage: scripts/verify-manual-qa-fixtures.sh [options]

Generate and verify synthetic manual QA fixtures, or verify an existing
fixture directory.

Options:
  --fixture-dir DIR  Verify an existing fixture directory instead of generating
                     a temporary one.
  -h, --help         Show this help.
EOF
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --fixture-dir)
            if [[ $# -lt 2 ]]; then
                echo "--fixture-dir requires a path" >&2
                exit 2
            fi
            fixture_dir="$2"
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

require_command ruby
require_command sips

cd "$REPO_ROOT"

if [[ -z "$fixture_dir" ]]; then
    generated_dir="$(mktemp -d "${TMPDIR:-/tmp}/macpastehistory-manual-fixtures.XXXXXX")"
    fixture_dir="$generated_dir"
    scripts/generate-manual-qa-fixtures.swift "$fixture_dir" >/tmp/macpastehistory-manual-fixtures-generate.log
fi

trap '[[ -n "${generated_dir:-}" ]] && rm -rf "$generated_dir"' EXIT

ruby -W0 - "$fixture_dir" <<'RUBY'
fixture_dir = ARGV.fetch(0)

expected_text_files = {
  "01-browser-text-sample.txt" => "browser copy sample",
  "02-vscode-code-sample.swift" => "ClipboardFixture",
  "03-chat-copy-sample.txt" => "QA chat sample",
  "04-large-text-sample.txt" => "release-fixture-clipboard-history",
  "07-structured-actions-fixture.txt" => "jwt-expired"
}
expected_images = {
  "05-standard-image-1024x768.png" => [1024, 768],
  "06-large-image-2400x1600.png" => [2400, 1600]
}

violations = []
valid_text_files = 0
valid_images = 0

unless File.directory?(fixture_dir)
  violations << "Fixture directory not found: #{fixture_dir}."
end

expected_text_files.each do |filename, marker|
  path = File.join(fixture_dir, filename)
  unless File.file?(path)
    violations << "Missing text fixture: #{filename}."
    next
  end
  contents = File.read(path, encoding: "UTF-8")
  if contents.strip.empty?
    violations << "Text fixture is empty: #{filename}."
    next
  end
  unless contents.include?(marker)
    violations << "Text fixture #{filename} does not contain expected marker #{marker.inspect}."
    next
  end
  if filename == "04-large-text-sample.txt" && contents.length < 1_000_000
    violations << "Large text fixture is too small: #{contents.length} characters."
    next
  end
  valid_text_files += 1
end

expected_images.each do |filename, (expected_width, expected_height)|
  path = File.join(fixture_dir, filename)
  unless File.file?(path)
    violations << "Missing image fixture: #{filename}."
    next
  end
  output = `sips -g pixelWidth -g pixelHeight "#{path}" 2>/dev/null`
  width = output[/pixelWidth:\s*(\d+)/, 1].to_i
  height = output[/pixelHeight:\s*(\d+)/, 1].to_i
  if width != expected_width || height != expected_height
    violations << "Image fixture #{filename} has #{width}x#{height}, expected #{expected_width}x#{expected_height}."
    next
  end
  valid_images += 1
end

readme_path = File.join(fixture_dir, "README.md")
if !File.file?(readme_path)
  violations << "Missing fixture README.md."
elsif !File.read(readme_path, encoding: "UTF-8").include?("Manual QA Fixtures")
  violations << "Fixture README.md does not look like the generated manifest."
end

puts "# Manual QA Fixture Verification"
puts
puts "| Field | Value |"
puts "|---|---|"
puts "| Fixture directory | `#{fixture_dir}` |"
puts "| Expected text fixtures | `#{expected_text_files.length}` |"
puts "| Valid text fixtures | `#{valid_text_files}` |"
puts "| Expected image fixtures | `#{expected_images.length}` |"
puts "| Valid image fixtures | `#{valid_images}` |"
puts "| Violations | `#{violations.length}` |"
puts

if violations.empty?
  puts "Status: PASS"
  exit 0
end

puts "Status: FAIL"
puts
puts "## Violations"
puts
violations.each do |violation|
  puts "- #{violation}"
end
exit 1
RUBY
