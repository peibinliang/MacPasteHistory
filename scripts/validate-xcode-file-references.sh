#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="$REPO_ROOT/MacPasteHistory.xcodeproj"
should_generate=1

usage() {
    cat <<'EOF'
Usage: scripts/validate-xcode-file-references.sh [options]

Regenerate and validate Swift file references in MacPasteHistory.xcodeproj.

Options:
  --skip-generate  Validate the existing project without running xcodegen.
  -h, --help       Show this help.
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
        --skip-generate)
            should_generate=0
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

cd "$REPO_ROOT"

if [[ "$should_generate" -eq 1 ]]; then
    require_command xcodegen
    xcodegen generate --spec project.yml >/tmp/macpastehistory-xcode-file-reference-xcodegen.log
fi

ruby -W0 <<'RUBY'
project_path = File.expand_path("MacPasteHistory.xcodeproj/project.pbxproj", Dir.pwd)
unless File.file?(project_path)
  warn "Project file not found: #{project_path}"
  exit 1
end

content = File.read(project_path)
objects = {}

current_id = nil
current_body = []

content.each_line do |line|
  if current_id.nil?
    match = line.match(/^\s*([A-F0-9]{24}) \/\* .*? \*\/ = \{(.*)$/)
    next unless match

    current_id = match[1]
    rest = match[2]
    if rest.match?(/\};\s*$/)
      objects[current_id] = rest.sub(/\};\s*$/, "")
      current_id = nil
    else
      current_body = [rest]
    end
    next
  end

  if line.match?(/^\s*\};/)
    objects[current_id] = current_body.join
    current_id = nil
    current_body = []
  else
    current_body << line
  end
end

def field(body, key)
  match = body.match(/(?:^|;)\s*#{Regexp.escape(key)} = (.*?);/m)
  return nil unless match

  value = match[1].strip
  value = value[1...-1] if value.start_with?('"') && value.end_with?('"')
  value
end

def children(body)
  match = body.match(/^\s*children = \(\n(.*?)^\s*\);/m)
  return [] unless match

  match[1].scan(/^\s*([A-F0-9]{24}) /).flatten
end

parents = {}
objects.each do |id, body|
  next unless field(body, "isa") == "PBXGroup"

  children(body).each do |child_id|
    parents[child_id] = id
  end
end

def resolved_group_path(id, objects, parents)
  parts = []
  current = parents[id]

  while current
    body = objects[current]
    break unless body

    path = field(body, "path")
    parts.unshift(path) if path && !path.empty?
    current = parents[current]
  end

  File.join(parts)
end

missing = []
checked = 0

objects.each do |id, body|
  next unless field(body, "isa") == "PBXFileReference"
  next unless field(body, "lastKnownFileType") == "sourcecode.swift"
  next unless field(body, "sourceTree") == "<group>"

  path = field(body, "path")
  next unless path && !path.empty?

  checked += 1
  relative_path = File.join(resolved_group_path(id, objects, parents), path)
  next if File.file?(relative_path)

  missing << relative_path
end

puts "# Xcode File Reference Validation"
puts
puts "| Field | Value |"
puts "|---|---|"
puts "| Project | `#{project_path}` |"
puts "| Swift references checked | `#{checked}` |"
puts "| Missing Swift files | `#{missing.length}` |"
puts

if missing.empty?
  puts "Status: PASS"
  exit 0
end

puts "Status: FAIL"
puts
puts "## Missing Files"
puts
missing.sort.each do |path|
  puts "- `#{path}`"
end

exit 1
RUBY
