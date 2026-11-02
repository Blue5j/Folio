#!/usr/bin/env bash
# Paperr · tiny todo ledger
# The file is plain JSON so it is easy to back up, sync, or edit by hand.
set -Eeuo pipefail

DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/paperr"
FILE="$DATA_DIR/todos.json"

mkdir -p "$DATA_DIR"

if [[ ! -f "$FILE" ]]; then
    cat > "$FILE" <<'JSON'
[
  {"text": "water the plants", "done": false},
  {"text": "write a letter", "done": false},
  {"text": "drink something warm", "done": true}
]
JSON
fi

if ! command -v jq >/dev/null 2>&1; then
    echo "Paperr: jq is required by todo.sh" >&2
    exit 1
fi

# If a previous run was interrupted, make sure the ledger is still valid.
if ! jq empty "$FILE" >/dev/null 2>&1; then
    cp "$FILE" "$FILE.broken.$(date +%s)" 2>/dev/null || true
    printf '[]\n' > "$FILE"
fi

case "${1:-list}" in
    list)
        jq -c 'to_entries | map({id: .key, text: .value.text, done: (.value.done // false)})' "$FILE"
        ;;
    count)
        jq '[.[] | select(.done == false)] | length' "$FILE"
        ;;
    total)
        jq 'length' "$FILE"
        ;;
    add)
        shift || true
        text="$(printf '%s ' "$@" | sed 's/[[:space:]]*$//')"
        [[ -z "$text" ]] && exit 0
        tmp="$(mktemp "$DATA_DIR/.todos.XXXXXX")"
        jq --arg text "$text" '. + [{text: $text, done: false}]' "$FILE" > "$tmp" && mv "$tmp" "$FILE"
        ;;
    toggle)
        id="${2:-}"
        [[ "$id" =~ ^[0-9]+$ ]] || exit 1
        tmp="$(mktemp "$DATA_DIR/.todos.XXXXXX")"
        jq --argjson id "$id" '.[$id].done = ((.[$id].done // false) | not)' "$FILE" > "$tmp" && mv "$tmp" "$FILE"
        ;;
    del|delete|remove)
        id="${2:-}"
        [[ "$id" =~ ^[0-9]+$ ]] || exit 1
        tmp="$(mktemp "$DATA_DIR/.todos.XXXXXX")"
        jq --argjson id "$id" 'del(.[$id])' "$FILE" > "$tmp" && mv "$tmp" "$FILE"
        ;;
    clear-done)
        tmp="$(mktemp "$DATA_DIR/.todos.XXXXXX")"
        jq '[.[] | select(.done != true)]' "$FILE" > "$tmp" && mv "$tmp" "$FILE"
        ;;
    path)
        printf '%s\n' "$FILE"
        ;;
    *)
        printf 'usage: %s [list|count|total|add TEXT...|toggle ID|del ID|clear-done|path]\n' "$0" >&2
        exit 2
        ;;
esac
