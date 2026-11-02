#!/usr/bin/env bash
# Paperr · the paper bin
# Left click opens the trash, right click offers to empty it after showing you
# what is inside.  Nothing is deleted without an explicit y/yes.
set -Eeuo pipefail

notify() {
    command -v notify-send >/dev/null 2>&1 && notify-send -a Paperr "$1" "$2" || true
}

if ! command -v trash-list >/dev/null 2>&1; then
    notify "the paper bin" "trash-cli is not installed"
    exit 1
fi

if [[ "${1:-}" == "--empty" ]]; then
    count="$(trash-list 2>/dev/null | wc -l | tr -d ' ')"
    if [[ "$count" == "0" ]]; then
        notify "the paper bin" "already empty — nothing to tidy"
        exit 0
    fi

    if command -v kitty >/dev/null 2>&1; then
        exec kitty --title "paperr · the paper bin" --override background_opacity=1.0 \
            -e bash -c '
                printf "\\n  %s\\n\\n" "── what is in the bin ─────────────────────────────"
                trash-list | sed "s/^/  /"
                printf "\\n  %s\\n" "───────────────────────────────────────────────────"
                printf "  %s\\n\\n" "empty all of it? [y/N] "
                read -r answer
                case "$answer" in
                    [yY]|[yY][eE][sS])
                        trash-empty -f
                        printf "\\n  the bin is empty.  a clean sheet.\\n\\n"
                        ;;
                    *)
                        printf "\\n  left it alone.  nothing lost.\\n\\n"
                        ;;
                esac
                sleep 1.2
            '
    fi

    # No terminal available: be conservative and do nothing.
    notify "the paper bin" "$count item(s) waiting; install kitty to empty them safely"
    exit 0
fi

if command -v nautilus >/dev/null 2>&1; then
    exec nautilus trash:///
elif command -v thunar >/dev/null 2>&1; then
    exec thunar trash:///
elif command -v kitty >/dev/null 2>&1; then
    exec kitty -e bash -c 'trash-list; printf "\npress enter to close\n"; read -r'
else
    notify "the paper bin" "no file manager found to show the trash"
fi
