#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
#  Paperr · installer
#  A warm, hand-drawn, scrapbook desktop for Arch Linux + Hyprland.
#
#  Usage:
#     ./setup.sh                 interactive, installs packages and configs
#     ./setup.sh --yes           accept defaults
#     ./setup.sh --no-packages   only install configs and fonts
#     ./setup.sh --with-apps     also install Nautilus + Firefox
#     ./setup.sh --apply         reload the running Hyprland session afterwards
#     ./setup.sh --lua           use hyprland.lua instead of hyprland.conf (0.55+)
#     ./setup.sh --help
#
#  Nothing is deleted: existing configs are copied to
#  ~/.config/paperr-backup-YYYYmmdd-HHMMSS before being replaced.
# ─────────────────────────────────────────────────────────────────────────────
set -Eeuo pipefail

# ── presentation ─────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
    C_RESET=$'\033[0m'; C_DIM=$'\033[2m'; C_BOLD=$'\033[1m'
    C_RED=$'\033[38;5;131m'; C_GREEN=$'\033[38;5;107m'
    C_YELLOW=$'\033[38;5;179m'; C_BLUE=$'\033[38;5;110m'
else
    C_RESET=""; C_DIM=""; C_BOLD=""; C_RED=""; C_GREEN=""; C_YELLOW=""; C_BLUE=""
fi

say()  { printf '%s\n' "${C_BLUE}::${C_RESET} $*"; }
ok()   { printf '%s\n' "${C_GREEN} ✓${C_RESET} $*"; }
warn() { printf '%s\n' "${C_YELLOW} !${C_RESET} $*" >&2; }
die()  { printf '%s\n' "${C_RED} ✗${C_RESET} $*" >&2; exit 1; }
hr()   { printf '%s\n' "${C_DIM}────────────────────────────────────────────────────────────${C_RESET}"; }

# ── args ─────────────────────────────────────────────────────────────────────
ASSUME_YES=0
INSTALL_PACKAGES=1
WITH_APPS=0
APPLY=0
SKIP_FONTS=0
USE_LUA=0

usage() {
    sed -n '3,15p' "$0" | sed -e '/^#$/d' -e 's/^#  \{0,1\}//'
    exit 0
}

while (($#)); do
    case "$1" in
        -y|--yes)          ASSUME_YES=1 ;;
        --no-packages)     INSTALL_PACKAGES=0 ;;
        --with-apps)       WITH_APPS=1 ;;
        --apply)           APPLY=1 ;;
        --lua)             USE_LUA=1 ;;
        --skip-fonts)      SKIP_FONTS=1 ;;
        -h|--help)         usage ;;
        *) die "Unknown option: $1 (try --help)" ;;
    esac
    shift
done

# ── preflight ────────────────────────────────────────────────────────────────
[[ $EUID -ne 0 ]] || die "Run this as your normal user, not with sudo/root."
[[ -n "${HOME:-}" && "$HOME" != "/" ]] || die "HOME is not set sensibly."
[[ -f /etc/arch-release ]] || die "This installer is for Arch Linux."
PAPERR_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
[[ -f "$PAPERR_DIR/setup.sh" && -d "$PAPERR_DIR/assets" ]] \
    || die "Run setup.sh from inside the Paperr directory."

command -v pacman >/dev/null 2>&1 || die "pacman was not found."

[[ -w "$HOME" ]] || die "$HOME is not writable."

hr
printf '%s\n' "${C_BOLD}  Paperr${C_RESET}  ·  a scrapbook desktop for Arch + Hyprland"
hr
printf '  source   %s\n' "$PAPERR_DIR"
printf '  target   %s\n' "$HOME/.config"
printf '  backup   %s\n' "$HOME/.config/paperr-backup-<timestamp>"
hr

if (( ! ASSUME_YES )); then
    printf '\nThis will install packages and replace the Paperr-related config files.\n'
    printf 'Existing configs are backed up first. Continue? [Y/n] '
    read -r answer
    case "$answer" in
        [nN]|[nN][oO]) die "Nothing changed." ;;
    esac
fi

# ── package installation ─────────────────────────────────────────────────────
PACMAN_PKGS=(
    hyprland
    hyprpaper
    waybar
    kitty
    wofi
    papirus-icon-theme
    ttf-firacode-nerd
    jq
    playerctl
    trash-cli
    libnotify
    grim
    slurp
    wl-clipboard
    brightnessctl
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
)
[[ "$WITH_APPS" == 1 ]] && PACMAN_PKGS+=(nautilus firefox)

AUR_PKGS=(eww neofetch)

install_yay() {
    if command -v yay >/dev/null 2>&1; then
        return 0
    fi
    say "yay was not found; building it from the AUR (one-time step)."
    command -v git >/dev/null 2>&1 || sudo pacman -S --needed --noconfirm git
    sudo pacman -S --needed --noconfirm base-devel
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth 1 https://aur.archlinux.org/yay.git "$tmp/yay"
    ( cd "$tmp/yay" && makepkg -si --noconfirm )
    rm -rf -- "$tmp"
    command -v yay >/dev/null 2>&1 || die "yay installation failed."
}

if (( INSTALL_PACKAGES )); then
    command -v sudo >/dev/null 2>&1 || die "sudo is required to install packages; install it or use --no-packages."
    say "Installing pacman packages (this is the long part)…"
    sudo -v || die "sudo authentication failed."
    # A full system upgrade is deliberately left to you; Arch users should keep
    # their system current.  If pacman complains about partial upgrades, run
    # `sudo pacman -Syu` first and re-run this installer.
    sudo pacman -S --needed --noconfirm "${PACMAN_PKGS[@]}" \
        || die "pacman failed. Run 'sudo pacman -Syu' and try once more."

    install_yay

    say "Installing AUR packages: ${AUR_PKGS[*]} (eww compiles from source)…"
    if ! yay -S --needed --noconfirm "${AUR_PKGS[@]}"; then
        warn "The AUR install failed. Trying eww-git as a fallback…"
        yay -S --needed --noconfirm eww-git || warn "eww is still missing; install it manually before starting the widgets."
    fi
    ok "Packages installed."
else
    warn "Skipping package installation (--no-packages)."
fi

for cmd in Hyprland waybar kitty jq playerctl; do
    command -v "$cmd" >/dev/null 2>&1 || warn "$cmd is not on PATH; Paperr may not start correctly."
done
command -v eww >/dev/null 2>&1 || warn "eww is not on PATH; install it with 'yay -S eww'."

# ── fonts ────────────────────────────────────────────────────────────────────
if (( ! SKIP_FONTS )); then
    say "Installing bundled hand-written fonts…"
    FONT_DIR="$HOME/.local/share/fonts/paperr"
    install -d "$FONT_DIR"

    # The two fonts are OFL-licensed and shipped in assets/fonts.  The fallback
    # download makes the repo robust if the binary files were omitted.
    if [[ -f "$PAPERR_DIR/assets/fonts/Caveat[wght].ttf" ]]; then
        install -m644 "$PAPERR_DIR/assets/fonts/Caveat[wght].ttf" "$FONT_DIR/"
    else
        command -v curl >/dev/null 2>&1 || die "Caveat is missing and curl is not installed."
        warn "Caveat is missing from assets/fonts; downloading from Google Fonts…"
        curl -fsSL --max-time 90 \
            'https://raw.githubusercontent.com/google/fonts/main/ofl/caveat/Caveat%5Bwght%5D.ttf' \
            -o "$FONT_DIR/Caveat[wght].ttf"
    fi

    if [[ -f "$PAPERR_DIR/assets/fonts/PatrickHand-Regular.ttf" ]]; then
        install -m644 "$PAPERR_DIR/assets/fonts/PatrickHand-Regular.ttf" "$FONT_DIR/"
    else
        command -v curl >/dev/null 2>&1 || die "Patrick Hand is missing and curl is not installed."
        warn "Patrick Hand is missing from assets/fonts; downloading from Google Fonts…"
        curl -fsSL --max-time 90 \
            'https://raw.githubusercontent.com/google/fonts/main/ofl/patrickhand/PatrickHand-Regular.ttf' \
            -o "$FONT_DIR/PatrickHand-Regular.ttf"
    fi

    if [[ -f "$PAPERR_DIR/assets/fonts/OFL-Caveat.txt" ]]; then
        install -m644 "$PAPERR_DIR/assets/fonts/OFL-Caveat.txt" "$FONT_DIR/"
    fi
    if [[ -f "$PAPERR_DIR/assets/fonts/OFL-PatrickHand.txt" ]]; then
        install -m644 "$PAPERR_DIR/assets/fonts/OFL-PatrickHand.txt" "$FONT_DIR/"
    fi

    if command -v fc-cache >/dev/null 2>&1; then
        fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1 || true
    fi
    if command -v fc-match >/dev/null 2>&1; then
        fc-match "Caveat" | grep -qi 'caveat' || warn "fontconfig does not see Caveat yet (a re-login may help)."
        fc-match "Patrick Hand" | grep -qi 'patrick' || warn "fontconfig does not see Patrick Hand yet (a re-login may help)."
    fi
    ok "Fonts installed to $FONT_DIR."
else
    warn "Skipping font installation (--skip-fonts)."
fi

# ── backup ───────────────────────────────────────────────────────────────────
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_ROOT="$HOME/.config/paperr-backup-$STAMP"
made_backup=0

backup_rel() {
    local rel="$1"
    [[ -e "$HOME/$rel" ]] || return 0
    mkdir -p "$BACKUP_ROOT/$(dirname "$rel")"
    cp -a "$HOME/$rel" "$BACKUP_ROOT/$rel"
    made_backup=1
}

say "Backing up existing configs…"
for rel in \
    .config/hypr \
    .config/waybar \
    .config/kitty \
    .config/eww \
    .config/gtk-3.0 \
    .config/gtk-4.0 \
    .config/neofetch \
    .config/wofi
do
    backup_rel "$rel"
done

if (( made_backup )); then
    ok "Backup: $BACKUP_ROOT"
    BACKUP_NOTE="$BACKUP_ROOT"
else
    rmdir "$BACKUP_ROOT" 2>/dev/null || true
    ok "No existing configs to back up."
    BACKUP_NOTE="none (no existing configs)"
fi

# ── helpers ──────────────────────────────────────────────────────────────────
escape_sed_replacement() {
    # HOME can contain & or \ on unusual setups; escape both for sed.
    printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'
}
HOME_ESC="$(escape_sed_replacement "$HOME")"

render_to() {
    local src="$1" dest="$2" mode="${3:-644}" tmp
    tmp="$(mktemp)"
    sed "s|@HOME@|$HOME_ESC|g" "$src" > "$tmp"
    install -D -m "$mode" "$tmp" "$dest"
    rm -f -- "$tmp"
}

copy_to() {
    local src="$1" dest="$2" mode="${3:-644}"
    install -D -m "$mode" "$src" "$dest"
}

# ── Hyprland ─────────────────────────────────────────────────────────────────
say "Installing Hyprland and wallpaper…"
install -d "$HOME/.config/hypr"
render_to "$PAPERR_DIR/hypr/hyprland.conf" "$HOME/.config/hypr/hyprland.conf" 644
render_to "$PAPERR_DIR/hypr/hyprpaper.conf" "$HOME/.config/hypr/hyprpaper.conf" 644
copy_to   "$PAPERR_DIR/assets/wallpaper.png" "$HOME/.config/hypr/wallpaper.png" 644

# Hyprland 0.55+ prefers hyprland.lua.  The requested, classic hyprland.conf is
# the default; --lua installs the equivalent Lua config instead.  Both formats
# have been syntax-checked with the matching Hyprland generation.
if (( USE_LUA )); then
    render_to "$PAPERR_DIR/hypr/hyprland.lua" "$HOME/.config/hypr/hyprland.lua" 644
    ok "Hyprland Lua config installed (0.55+ API); hyprland.conf kept as a reference."
    printf '%s\n' "Paperr: using hyprland.lua (installed with --lua)." \
        > "$HOME/.config/hypr/PAPERR-README.txt"
else
    # A file named hyprland.lua wins over hyprland.conf on 0.55+.  Move it out
    # of the way, after the backup above, so the classic config actually loads.
    if [[ -f "$HOME/.config/hypr/hyprland.lua" ]]; then
        mv "$HOME/.config/hypr/hyprland.lua" \
           "$HOME/.config/hypr/hyprland.lua.paperr-disabled-$STAMP"
        warn "Moved the previous hyprland.lua aside (backup + .paperr-disabled-$STAMP)."
        warn "Log out and back in so Hyprland switches from Lua to hyprland.conf."
    fi
    ok "Hyprland hyprland.conf installed."
    printf '%s\n' "Paperr: using hyprland.conf. Re-enable hyprland.lua if you prefer the Lua API." \
        > "$HOME/.config/hypr/PAPERR-README.txt"
fi

# ── Waybar ───────────────────────────────────────────────────────────────────
say "Installing the floating paper bar…"
install -d "$HOME/.config/waybar/scripts" "$HOME/.config/waybar/assets"
render_to "$PAPERR_DIR/waybar/config" "$HOME/.config/waybar/config" 644
render_to "$PAPERR_DIR/waybar/style.css" "$HOME/.config/waybar/style.css" 644
copy_to   "$PAPERR_DIR/waybar/scripts/trash.sh" "$HOME/.config/waybar/scripts/trash.sh" 755
copy_to   "$PAPERR_DIR/assets/torn-bar.png" "$HOME/.config/waybar/assets/torn-bar.png" 644

# ── Kitty ────────────────────────────────────────────────────────────────────
say "Installing kitty…"
install -d "$HOME/.config/kitty"
render_to "$PAPERR_DIR/kitty/kitty.conf" "$HOME/.config/kitty/kitty.conf" 644
copy_to   "$PAPERR_DIR/assets/paper-texture.png" "$HOME/.config/kitty/paper-texture.png" 644

# ── eww ──────────────────────────────────────────────────────────────────────
say "Installing the three paper widgets…"
install -d "$HOME/.config/eww/scripts" "$HOME/.config/eww/assets"
render_to "$PAPERR_DIR/eww/eww.yuck" "$HOME/.config/eww/eww.yuck" 644
render_to "$PAPERR_DIR/eww/eww.scss" "$HOME/.config/eww/eww.scss" 644
copy_to   "$PAPERR_DIR/eww/scripts/start-widgets.sh" "$HOME/.config/eww/scripts/start-widgets.sh" 755
copy_to   "$PAPERR_DIR/eww/scripts/toggle-widgets.sh" "$HOME/.config/eww/scripts/toggle-widgets.sh" 755
copy_to   "$PAPERR_DIR/eww/scripts/todo.sh" "$HOME/.config/eww/scripts/todo.sh" 755
copy_to   "$PAPERR_DIR/eww/scripts/music.sh" "$HOME/.config/eww/scripts/music.sh" 755
for card in card-clock.png card-todo.png card-music.png; do
    copy_to "$PAPERR_DIR/assets/$card" "$HOME/.config/eww/assets/$card" 644
done

# ── GTK ──────────────────────────────────────────────────────────────────────
say "Installing the GTK paper theme…"
install -d "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0"
render_to "$PAPERR_DIR/gtk-3.0/gtk.css" "$HOME/.config/gtk-3.0/gtk.css" 644
render_to "$PAPERR_DIR/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/settings.ini" 644
render_to "$PAPERR_DIR/gtk-4.0/gtk.css" "$HOME/.config/gtk-4.0/gtk.css" 644
render_to "$PAPERR_DIR/gtk-4.0/settings.ini" "$HOME/.config/gtk-4.0/settings.ini" 644

# ── Neofetch + wofi ──────────────────────────────────────────────────────────
say "Installing neofetch art and wofi…"
install -d "$HOME/.config/neofetch" "$HOME/.config/wofi"
render_to "$PAPERR_DIR/neofetch/config.conf" "$HOME/.config/neofetch/config.conf" 644
copy_to   "$PAPERR_DIR/neofetch/paper-ascii.txt" "$HOME/.config/neofetch/paper-ascii.txt" 644
render_to "$PAPERR_DIR/wofi/config" "$HOME/.config/wofi/config" 644
render_to "$PAPERR_DIR/wofi/style.css" "$HOME/.config/wofi/style.css" 644

# ── todo ledger ──────────────────────────────────────────────────────────────
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/paperr"
mkdir -p "$DATA_DIR" "$HOME/.cache/paperr"
if [[ ! -f "$DATA_DIR/todos.json" ]]; then
    cat > "$DATA_DIR/todos.json" <<'JSON'
[
  {"text": "water the plants", "done": false},
  {"text": "write a letter", "done": false},
  {"text": "drink something warm", "done": true}
]
JSON
    ok "Seeded a little todo list."
else
    ok "Kept your existing todo list."
fi

# ── validation ───────────────────────────────────────────────────────────────
say "Checking the installation…"
if jq empty "$HOME/.config/waybar/config" >/dev/null 2>&1; then
    ok "Waybar config is valid JSON."
else
    warn "Waybar config did not validate as JSON."
fi

for script in \
    "$HOME/.config/waybar/scripts/trash.sh" \
    "$HOME/.config/eww/scripts/start-widgets.sh" \
    "$HOME/.config/eww/scripts/toggle-widgets.sh" \
    "$HOME/.config/eww/scripts/todo.sh" \
    "$HOME/.config/eww/scripts/music.sh"
do
    bash -n "$script" || warn "Syntax error in $script"
done
ok "Shell scripts parse."

if command -v Hyprland >/dev/null 2>&1; then
    if (( USE_LUA )); then
        if Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.lua" >/dev/null 2>&1; then
            ok "Hyprland accepted the Lua config."
        else
            warn "Hyprland reported an issue with hyprland.lua (run: Hyprland --verify-config -c ~/.config/hypr/hyprland.lua)."
        fi
    else
        if Hyprland --verify-config -c "$HOME/.config/hypr/hyprland.conf" >/dev/null 2>&1; then
            ok "Hyprland accepted hyprland.conf."
        else
            warn "Hyprland reported an issue with hyprland.conf (run: Hyprland --verify-config -c ~/.config/hypr/hyprland.conf)."
        fi
    fi
fi

# Best-effort check that @HOME@ was fully replaced.
if grep -Rqs --include='*.css' --include='*.conf' --include='*.yuck' --include='*.scss' --include='*.ini' --include='config' \
        '@HOME@' "$HOME/.config/waybar" "$HOME/.config/eww" "$HOME/.config/kitty" "$HOME/.config/hypr"; then
    warn "Some @HOME@ placeholders remain in the installed configs."
else
    ok "All home-directory paths resolved."
fi

# ── optional live apply ──────────────────────────────────────────────────────
if (( APPLY )); then
    if [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]] && command -v hyprctl >/dev/null 2>&1; then
        say "Reloading the running session…"
        hyprctl reload >/dev/null 2>&1 || warn "hyprctl reload failed."
        pkill -x waybar   >/dev/null 2>&1 || true
        ( waybar >/dev/null 2>&1 & ) || true
        pkill -x hyprpaper >/dev/null 2>&1 || true
        ( hyprpaper >/dev/null 2>&1 & ) || true
        eww kill >/dev/null 2>&1 || true
        "$HOME/.config/eww/scripts/start-widgets.sh" || warn "Could not open eww widgets."
        ok "Bar, wallpaper and widgets restarted."
    else
        warn "--apply requested but no running Hyprland session was detected."
    fi
fi

# ── finale ───────────────────────────────────────────────────────────────────
hr
if (( USE_LUA )); then
    ok "Paperr is installed. Active Hyprland config: hyprland.lua"
else
    ok "Paperr is installed. Active Hyprland config: hyprland.conf"
fi
hr
cat <<SUMMARY
  Configs      ~/.config/{hypr,waybar,kitty,eww,gtk-3.0,gtk-4.0,neofetch,wofi}
  Wallpaper    ~/.config/hypr/wallpaper.png
  Fonts        ~/.local/share/fonts/paperr
  Todo data    ${DATA_DIR}/todos.json
  Backup       ${BACKUP_NOTE}

  Start Hyprland:
      Hyprland

  Or, from this running session:
      ./setup.sh --apply

  Handy keys:
      SUPER + Return   kitty
      SUPER + Space    wofi launcher
      SUPER + Escape   hide / show the paper widgets
      SUPER + Shift+S  screenshot a region

  Notes:
    • Paperr installs hyprland.conf by default.  On Hyprland 0.55+ an
      existing hyprland.lua is moved aside; pass --lua to use the Lua version.
    • Eww's widgets are opened at login by Hyprland.  Until then:
          ~/.config/eww/scripts/start-widgets.sh
    • Nautilus and Firefox are not installed unless you passed --with-apps.
    • GTK apps pick up the theme at next launch; some browsers need a restart.
    • The eww todo ledger is plain JSON, safe to back up or sync.
SUMMARY
hr
