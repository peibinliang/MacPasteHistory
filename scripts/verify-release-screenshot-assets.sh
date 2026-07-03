#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCREENSHOT_DIR="$REPO_ROOT/docs/release/screenshots"

usage() {
    cat <<'EOF'
Usage: scripts/verify-release-screenshot-assets.sh

Verify that the release screenshot assets exist as readable PNG files with
the expected generated dimensions.
EOF
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

require_command ruby
require_command sips

cd "$REPO_ROOT"

ruby -W0 - "$SCREENSHOT_DIR" <<'RUBY'
screenshot_dir = ARGV.fetch(0)

expected = {
  "01-history-overview.png" => [5760, 3600],
  "02-image-history.png" => [5760, 3600],
  "03-settings-controls.png" => [5760, 3600],
  "04-local-privacy.png" => [5760, 3600]
}

violations = []
checked = 0

expected.each do |filename, (expected_width, expected_height)|
  path = File.join(screenshot_dir, filename)

  unless File.file?(path)
    violations << "Missing screenshot: #{filename}."
    next
  end

  unless File.extname(filename).downcase == ".png"
    violations << "Screenshot file is not PNG: #{filename}."
    next
  end

  if File.size(path).zero?
    violations << "Screenshot file is empty: #{filename}."
    next
  end

  output = `sips -g pixelWidth -g pixelHeight "#{path}" 2>/dev/null`
  width = output[/pixelWidth:\s*(\d+)/, 1].to_i
  height = output[/pixelHeight:\s*(\d+)/, 1].to_i

  if width != expected_width || height != expected_height
    violations << "Screenshot #{filename} has #{width}x#{height}, expected #{expected_width}x#{expected_height}."
    next
  end

  checked += 1
end

puts "# Release Screenshot Asset Verification"
puts
puts "| Field | Value |"
puts "|---|---|"
puts "| Screenshot directory | `#{screenshot_dir}` |"
puts "| Expected screenshots | `#{expected.length}` |"
puts "| Valid screenshots | `#{checked}` |"
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
