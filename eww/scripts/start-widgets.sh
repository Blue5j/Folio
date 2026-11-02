#!/usr/bin/env bash
# Start eww (if needed) and open all three Paperr scraps.
set -u

CONFIG="${HOME}/.config/eww"
CACHE="${HOME}/.cache/paperr"
LOG="${CACHE}/eww.log"
mkdir -p "$CACHE"
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin"

if [[ ! -d "$CONFIG" ]]; then
    echo "Paperr: missing $CONFIG" >&2
    exit 1
fi

cd "$CONFIG" || exit 1

if ! command -v eww >/dev/null 2>&1; then
    echo "Paperr: eww is not installed" >&2
    exit 1
fi

if ! eww ping >/dev/null 2>&1; then
    eww daemon >>"$LOG" 2>&1 &
    for _ in $(seq 1 80); do
        eww ping >/dev/null 2>&1 && break
        sleep 0.1
    done
fi

if ! eww ping >/dev/null 2>&1; then
    echo "Paperr: eww daemon did not start; see $LOG" >&2
    exit 1
fi

# Reloading after an edit is a nice side effect of calling open-many again.
eww open-many clock-window todo-window music-window >>"$LOG" 2>&1 || {
    echo "Paperr: could not open widgets; see $LOG" >&2
    exit 1
}
