#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
scan_roots=("$REPO_ROOT/MacPasteHistory")

usage() {
    cat <<'EOF'
Usage: scripts/scan-privacy-log-safety.sh [path ...]

Scan Swift app sources for logging patterns that could expose clipboard content
or sensitive data. By default, scans MacPasteHistory/ only.
EOF
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

if [[ $# -gt 0 ]]; then
    case "$1" in
        -h|--help)
            usage
            exit 0
            ;;
    esac
    scan_roots=("$@")
fi

require_command ruby

ruby -W0 - "${scan_roots[@]}" <<'RUBY'
roots = ARGV
swift_files = roots.flat_map do |root|
  if File.file?(root)
    [root]
  elsif File.directory?(root)
    Dir.glob(File.join(root, "**", "*.swift"))
  else
    warn "Scan path not found: #{root}"
    exit 1
  end
end.uniq.sort

violations = []
logger_calls = 0
direct_console_calls = 0
logger_privacy_files = []

sensitive_terms = /
  textContent|
  text_content|
  normalizedText|
  clipboardText|
  pasteboardText|
  item\.textContent|
  candidate\.pngData|
  pngData|
  NSPasteboard|
  string\(forType:
/x

swift_files.each do |path|
  relative_path = path.sub(Dir.pwd + "/", "")
  File.readlines(path, chomp: true).each_with_index do |line, index|
    line_number = index + 1

    if File.basename(path) == "Logger.swift"
      logger_privacy_files << relative_path if line.include?("privacy: .private")
      if line.include?("privacy: .public")
        violations << [relative_path, line_number, "Logger wrapper must not mark messages public by default."]
      end
      next
    end

    if line.match?(/\b(print|debugPrint|dump|NSLog|os_log)\s*\(/)
      direct_console_calls += 1
      violations << [relative_path, line_number, "Direct console logging is not allowed in app sources."]
    end

    next unless line.match?(/\blogger\.(info|warning|error)\s*\(/)

    logger_calls += 1
    if line.match?(sensitive_terms)
      violations << [relative_path, line_number, "Logger call references clipboard content or pasteboard data."]
    end

    interpolation = line.scan(/\\\((.*?)\)/).flatten
    interpolation.each do |expression|
      next if expression.match?(/\b(text|data|pngData)\.count\b/)
      next if expression.match?(/\b(error|status|registerStatus|keyCode|modifiers|removed|excessIDs\.count|recordsToTrim\.count|recordsToEvict\.count|retentionDays|maxCount|maxStorage)\b/)
      if expression.match?(/\b(text|data|content|item|candidate|pasteboard|clipboard)\b/i)
        violations << [relative_path, line_number, "Logger interpolation may include raw clipboard data: #{expression}"]
      end
    end
  end
end

puts "# Privacy Log Safety Scan"
puts
puts "| Field | Value |"
puts "|---|---|"
puts "| Swift files scanned | `#{swift_files.length}` |"
puts "| Logger calls checked | `#{logger_calls}` |"
puts "| Direct console calls | `#{direct_console_calls}` |"
puts "| Logger private wrapper found | `#{logger_privacy_files.empty? ? "no" : "yes"}` |"
puts

if logger_privacy_files.empty? && swift_files.any? { |path| File.basename(path) == "Logger.swift" }
  violations << ["MacPasteHistory/Utils/Logger.swift", 1, "Logger wrapper must use OSLog private privacy by default."]
end

if violations.empty?
  puts "Status: PASS"
  puts
  puts "No app-source logging patterns were found that obviously expose clipboard content."
  exit 0
end

puts "Status: FAIL"
puts
puts "## Violations"
puts
violations.each do |path, line_number, message|
  puts "- `#{path}:#{line_number}` #{message}"
end

exit 1
RUBY
