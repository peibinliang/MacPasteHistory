#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_support_dir=""

usage() {
    cat <<'EOF'
Usage: scripts/seed-preview-data.sh APP_SUPPORT_DIR

Seed an isolated MacPasteHistory Application Support directory with synthetic
preview history. Intended for local Release previews only.
EOF
}

require_command() {
    local command_name="$1"
    if ! command -v "$command_name" >/dev/null 2>&1; then
        echo "Missing required command: $command_name" >&2
        exit 1
    fi
}

sql_escape() {
    printf "%s" "$1" | sed "s/'/''/g"
}

hash_text() {
    printf "%s" "$1" | shasum -a 256 | awk '{print $1}'
}

file_size() {
    wc -c <"$1" | tr -d ' '
}

insert_text() {
    local db_path="$1"
    local text="$2"
    local source_app="$3"
    local source_bundle_id="$4"
    local favorite="$5"
    local minutes_ago="$6"
    local hash
    local escaped_text
    local escaped_source_app
    local escaped_source_bundle_id

    hash="$(hash_text "$text")"
    escaped_text="$(sql_escape "$text")"
    escaped_source_app="$(sql_escape "$source_app")"
    escaped_source_bundle_id="$(sql_escape "$source_bundle_id")"

    sqlite3 "$db_path" <<SQL
DELETE FROM clipboard_history WHERE content_hash = '$hash';
INSERT INTO clipboard_history (
    content_type,
    text_content,
    source_app,
    source_bundle_id,
    content_hash,
    text_length,
    is_favorite,
    created_at,
    updated_at
) VALUES (
    'text',
    '$escaped_text',
    '$escaped_source_app',
    '$escaped_source_bundle_id',
    '$hash',
    ${#text},
    $favorite,
    datetime('now', '-$minutes_ago minutes'),
    datetime('now', '-$minutes_ago minutes')
);
SQL
}

insert_image() {
    local db_path="$1"
    local source_file="$2"
    local image_name="$3"
    local source_app="$4"
    local source_bundle_id="$5"
    local width="$6"
    local height="$7"
    local favorite="$8"
    local minutes_ago="$9"
    local images_dir="${10}"
    local thumbnails_dir="${11}"
    local hash
    local image_path
    local thumbnail_path
    local size
    local escaped_source_app
    local escaped_source_bundle_id

    hash="$(shasum -a 256 "$source_file" | awk '{print $1}')"
    image_path="$images_dir/$image_name"
    thumbnail_path="$thumbnails_dir/$image_name"
    cp "$source_file" "$image_path"
    cp "$source_file" "$thumbnail_path"
    size="$(file_size "$image_path")"
    escaped_source_app="$(sql_escape "$source_app")"
    escaped_source_bundle_id="$(sql_escape "$source_bundle_id")"

    sqlite3 "$db_path" <<SQL
DELETE FROM clipboard_history WHERE content_hash = '$hash';
INSERT INTO clipboard_history (
    content_type,
    file_path,
    thumbnail_path,
    source_app,
    source_bundle_id,
    content_hash,
    file_size,
    image_width,
    image_height,
    image_format,
    is_favorite,
    created_at,
    updated_at
) VALUES (
    'image',
    '$(sql_escape "$image_path")',
    '$(sql_escape "$thumbnail_path")',
    '$escaped_source_app',
    '$escaped_source_bundle_id',
    '$hash',
    $size,
    $width,
    $height,
    'png',
    $favorite,
    datetime('now', '-$minutes_ago minutes'),
    datetime('now', '-$minutes_ago minutes')
);
SQL
}

if [[ $# -ne 1 ]]; then
    usage >&2
    exit 2
fi

case "$1" in
    -h|--help)
        usage
        exit 0
        ;;
esac

app_support_dir="$1"

require_command awk
require_command cp
require_command mkdir
require_command shasum
require_command sqlite3
require_command swift
require_command wc

db_path="$app_support_dir/clipboard.db"
images_dir="$app_support_dir/images"
thumbnails_dir="$app_support_dir/thumbnails"
fixtures_dir="$app_support_dir/preview-fixtures"

mkdir -p "$images_dir" "$thumbnails_dir" "$fixtures_dir" "$app_support_dir/logs"
"$REPO_ROOT/scripts/generate-manual-qa-fixtures.swift" "$fixtures_dir" >/tmp/macpastehistory-preview-fixtures.log

sqlite3 "$db_path" <<'SQL'
CREATE TABLE IF NOT EXISTS schema_migrations (
    version INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    applied_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS clipboard_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    content_type TEXT NOT NULL,
    text_content TEXT,
    file_path TEXT,
    thumbnail_path TEXT,
    source_app TEXT,
    source_bundle_id TEXT,
    content_hash TEXT NOT NULL,
    text_length INTEGER NOT NULL DEFAULT 0,
    file_size INTEGER,
    image_width INTEGER,
    image_height INTEGER,
    is_favorite INTEGER NOT NULL DEFAULT 0,
    is_sensitive INTEGER NOT NULL DEFAULT 0,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    image_format TEXT
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_clipboard_hash
ON clipboard_history(content_hash);

CREATE INDEX IF NOT EXISTS idx_clipboard_created_at
ON clipboard_history(created_at);

CREATE INDEX IF NOT EXISTS idx_clipboard_content_type
ON clipboard_history(content_type);

CREATE INDEX IF NOT EXISTS idx_clipboard_favorite
ON clipboard_history(is_favorite);

CREATE INDEX IF NOT EXISTS idx_clipboard_text_content
ON clipboard_history(text_content);

INSERT OR IGNORE INTO schema_migrations (version, name) VALUES (1, 'create_clipboard_history');
INSERT OR IGNORE INTO schema_migrations (version, name) VALUES (2, 'add_image_format_to_clipboard_history');
SQL

browser_text="$(cat "$fixtures_dir/01-browser-text-sample.txt")"
code_text="$(cat "$fixtures_dir/02-vscode-code-sample.swift")"
chat_text="$(cat "$fixtures_dir/03-chat-copy-sample.txt")"
large_preview_text="$(printf '%s\n' \
    'MacPasteHistory preview large text sample.' \
    'This synthetic item lets you check long previews, detail scrolling, and search.' \
    'Search token: preview-large-text-history.' \
    '' \
    "$(sed -n '1,80p' "$fixtures_dir/04-large-text-sample.txt")")"

insert_text "$db_path" "$browser_text" "Google Chrome" "com.google.Chrome" 1 6
insert_text "$db_path" "$code_text" "Visual Studio Code" "com.microsoft.VSCode" 0 12
insert_text "$db_path" "$chat_text" "DingTalk" "com.alibaba.DingTalk" 0 18
insert_text "$db_path" "$large_preview_text" "TextEdit" "com.apple.TextEdit" 0 24
insert_image "$db_path" "$fixtures_dir/05-standard-image-1024x768.png" "preview-standard-image.png" "Safari" "com.apple.Safari" 1024 768 1 30 "$images_dir" "$thumbnails_dir"
insert_image "$db_path" "$fixtures_dir/06-large-image-2400x1600.png" "preview-large-image.png" "Preview" "com.apple.Preview" 2400 1600 0 36 "$images_dir" "$thumbnails_dir"

echo "Seeded preview data:"
echo "  App support: $app_support_dir"
echo "  Database: $db_path"
echo "  Text items: $(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_type = 'text';")"
echo "  Image items: $(sqlite3 "$db_path" "SELECT COUNT(*) FROM clipboard_history WHERE content_type = 'image';")"
