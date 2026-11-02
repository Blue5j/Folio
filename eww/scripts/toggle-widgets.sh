#!/usr/bin/env bash
# Toggle all three Paperr scraps with SUPER+Escape.
set -u

CONFIG="${HOME}/.config/eww"
cd "$CONFIG" 2>/dev/null || exit 1

if ! eww ping >/dev/null 2>&1; then
    exec "$CONFIG/scripts/start-widgets.sh"
fi

if eww active-windows 2>/dev/null | grep -q .; then
    eww close-all
else
    "$CONFIG/scripts/start-widgets.sh"
fi
