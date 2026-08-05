#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ICONSET_DIR="$REPO_ROOT/MacPasteHistory/Resources/Assets.xcassets/AppIcon.appiconset"
CONTENTS_JSON="$ICONSET_DIR/Contents.json"
STATUS_ICONSET_DIR="$REPO_ROOT/MacPasteHistory/Resources/Assets.xcassets/StatusBarIcon.imageset"

usage() {
    cat <<'EOF'
Usage: scripts/verify-app-icon-assets.sh

Verify that the macOS AppIcon asset catalog contains all required PNG files
with the expected pixel dimensions.
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

ruby -W0 -rjson - "$CONTENTS_JSON" "$ICONSET_DIR" <<'RUBY'
contents_path = ARGV.fetch(0)
iconset_dir = ARGV.fetch(1)

unless File.file?(contents_path)
  warn "AppIcon Contents.json not found: #{contents_path}"
  exit 1
end

expected = {
  ["16x16", "1x"] => 16,
  ["16x16", "2x"] => 32,
  ["32x32", "1x"] => 32,
  ["32x32", "2x"] => 64,
  ["128x128", "1x"] => 128,
  ["128x128", "2x"] => 256,
  ["256x256", "1x"] => 256,
  ["256x256", "2x"] => 512,
  ["512x512", "1x"] => 512,
  ["512x512", "2x"] => 1024
}

json = JSON.parse(File.read(contents_path))
images = json.fetch("images", [])
violations = []
checked = 0
filenames = []

expected.each do |(size, scale), pixels|
  match = images.find { |image| image["idiom"] == "mac" && image["size"] == size && image["scale"] == scale }
  unless match
    violations << "Missing Contents.json entry for #{size} #{scale}."
    next
  end

  filename = match["filename"]
  if filename.nil? || filename.strip.empty?
    violations << "Missing filename for #{size} #{scale}."
    next
  end
  filenames << filename

  path = File.join(iconset_dir, filename)
  unless File.file?(path)
    violations << "Missing PNG file for #{size} #{scale}: #{filename}."
    next
  end

  unless File.extname(filename).downcase == ".png"
    violations << "Icon file is not PNG for #{size} #{scale}: #{filename}."
    next
  end

  output = `sips -g pixelWidth -g pixelHeight "#{path}" 2>/dev/null`
  width = output[/pixelWidth:\s*(\d+)/, 1].to_i
  height = output[/pixelHeight:\s*(\d+)/, 1].to_i
  if width != pixels || height != pixels
    violations << "Icon #{filename} has #{width}x#{height}, expected #{pixels}x#{pixels}."
    next
  end

  checked += 1
end

duplicates = filenames.group_by(&:itself).select { |_filename, values| values.length > 1 }.keys
duplicates.each do |filename|
  violations << "Filename is reused by multiple icon slots: #{filename}."
end

puts "# App Icon Asset Verification"
puts
puts "| Field | Value |"
puts "|---|---|"
puts "| Iconset | `#{iconset_dir}` |"
puts "| Expected icons | `#{expected.length}` |"
puts "| Valid icons | `#{checked}` |"
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

for status_icon in "status-bar-icon.png:18" "status-bar-icon@2x.png:36"; do
    filename="${status_icon%%:*}"
    expected_pixels="${status_icon##*:}"
    path="$STATUS_ICONSET_DIR/$filename"
    if [[ ! -f "$path" ]]; then
        echo "Missing status bar icon: $path" >&2
        exit 1
    fi
    width="$(sips -g pixelWidth "$path" 2>/dev/null | awk '/pixelWidth/ {print $2}')"
    height="$(sips -g pixelHeight "$path" 2>/dev/null | awk '/pixelHeight/ {print $2}')"
    if [[ "$width" != "$expected_pixels" || "$height" != "$expected_pixels" ]]; then
        echo "Status bar icon $filename has ${width}x${height}, expected ${expected_pixels}x${expected_pixels}." >&2
        exit 1
    fi
done

echo "Status bar icons: PASS (18x18 and 36x36 template assets)"
