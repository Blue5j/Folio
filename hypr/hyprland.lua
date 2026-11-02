-- ─────────────────────────────────────────────────────────────────────────────
--  Paperr · Hyprland (Lua config for Hyprland 0.55+)
--  This is the same desk as hyprland.conf, expressed for the newer Lua API.
--  setup.sh installs whichever format your Hyprland build prefers.
-- ─────────────────────────────────────────────────────────────────────────────

local home = os.getenv("HOME")

-- Monitors -----------------------------------------------------------------
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- Environment --------------------------------------------------------------
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("MOZ_ENABLE_WAYLAND", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- The desk -----------------------------------------------------------------
hl.config({
    general = {
        gaps_in             = 8,
        gaps_out            = 22,
        border_size         = 4,
        resize_on_border    = true,
        allow_tearing       = false,
        layout              = "dwindle",
        col                 = {
            active_border   = {
                colors = { "rgba(f4f1eaff)", "rgba(e7dcc8ff)" },
                angle  = 35,
            },
            inactive_border = "rgba(cfc3b0aa)",
        },
    },

    decoration = {
        rounding       = 3,
        rounding_power = 3.0,
        active_opacity = 1.0,
        inactive_opacity = 0.98,
        fullscreen_opacity = 1.0,
        dim_inactive   = true,
        dim_strength   = 0.06,

        shadow = {
            enabled        = true,
            range          = 22,
            render_power   = 3,
            color          = "rgba(44,44,44,0.26)",
            color_inactive = "rgba(44,44,44,0.10)",
            offset         = "2 7",
        },

        blur = {
            enabled           = true,
            size              = 4,
            passes            = 2,
            new_optimizations = true,
            ignore_opacity    = true,
            xray              = false,
        },
    },

    dwindle = {
        preserve_split = true,
        smart_split    = false,
        smart_resizing = true,
    },

    master = {
        new_status = "master",
        mfact      = 0.55,
    },

    misc = {
        disable_hyprland_logo   = true,
        force_default_wallpaper = 0,
        disable_splash_rendering = true,
        font_family             = "Caveat",
        mouse_move_enables_dpms = true,
        key_press_enables_dpms  = true,
        focus_on_activate       = true,
    },

    input = {
        kb_layout = "us",
        kb_options = "compose:ralt",
        follow_mouse = 1,
        sensitivity = 0,
        numlock_by_default = false,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            disable_while_typing = true,
            scroll_factor = 0.8,
        },
    },

    binds = {
        workspace_back_and_forth = true,
        allow_workspace_cycles   = true,
        pass_mouse_when_bound    = false,
    },
})

-- Animation curves ---------------------------------------------------------
hl.curve("paper",  { type = "bezier", points = { { 0.22, 1.0 }, { 0.36, 1.0 } } })
hl.curve("settle", { type = "bezier", points = { { 0.16, 0.84 }, { 0.44, 1.0 } } })

hl.animation({ leaf = "windows",         enabled = true, speed = 5, bezier = "paper",  style = "popin 85%" })
hl.animation({ leaf = "windowsOut",      enabled = true, speed = 4, bezier = "settle", style = "popin 80%" })
hl.animation({ leaf = "border",          enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade",            enabled = true, speed = 6, bezier = "default" })
hl.animation({ leaf = "workspaces",      enabled = true, speed = 5, bezier = "paper",  style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "paper", style = "slidevert" })

-- Autostart ----------------------------------------------------------------
hl.on("hyprland.start", function()
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("hyprpaper")
    hl.exec_cmd("waybar")
    hl.exec_cmd("sleep 1; " .. home .. "/.config/eww/scripts/start-widgets.sh")
    hl.exec_cmd("gsettings set org.gnome.desktop.interface color-scheme default")
end)

-- Keys ---------------------------------------------------------------------
hl.bind("SUPER + Return", hl.dsp.exec_cmd("kitty"))
hl.bind("SUPER + Space",  hl.dsp.exec_cmd("wofi --show drun"))
hl.bind("SUPER + E",      hl.dsp.exec_cmd("nautilus"))
hl.bind("SUPER + B",      hl.dsp.exec_cmd("firefox"))
hl.bind("SUPER + Q",      hl.dsp.window.close())
hl.bind("SUPER + SHIFT + E", hl.dsp.exec_cmd("hyprctl dispatch exit"))
hl.bind("SUPER + V",      hl.dsp.window.float())
hl.bind("SUPER + F",      hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind("SUPER + SHIFT + F", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind("SUPER + P",      hl.dsp.exec_cmd("hyprctl dispatch pseudo"))
hl.bind("SUPER + ALT + J",  hl.dsp.exec_cmd("hyprctl dispatch layoutmsg togglesplit"))
hl.bind("SUPER + C",      hl.dsp.window.center())
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(home .. "/.config/eww/scripts/toggle-widgets.sh"))
hl.bind("SUPER + SHIFT + R", hl.dsp.exec_cmd("hyprctl reload"))
hl.bind("SUPER + ALT + L",  hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind("SUPER + Tab",    hl.dsp.window.cycle_next())
hl.bind("SUPER + grave",  hl.dsp.exec_cmd("hyprctl dispatch togglespecialworkspace magic"))

local directions = { left = "left", right = "right", up = "up", down = "down" }
for key, direction in pairs(directions) do
    hl.bind("SUPER + " .. key,   hl.dsp.focus({ direction = direction }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end
for key, direction in pairs({ H = "left", L = "right", K = "up", J = "down" }) do
    hl.bind("SUPER + " .. key,   hl.dsp.focus({ direction = direction }))
    hl.bind("SUPER + SHIFT + " .. key, hl.dsp.window.move({ direction = direction }))
end

for i = 1, 9 do
    hl.bind("SUPER + " .. i, hl.dsp.focus({ workspace = tostring(i) }))
    hl.bind("SUPER + SHIFT + " .. i, hl.dsp.window.move({ workspace = tostring(i) }))
end
hl.bind("SUPER + 0", hl.dsp.focus({ workspace = "10" }))
hl.bind("SUPER + SHIFT + 0", hl.dsp.window.move({ workspace = "10" }))

-- Volume, media and light.
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })

-- Screenshots.
hl.bind("Print", hl.dsp.exec_cmd("grim - | wl-copy"))
hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd('mkdir -p "$HOME/Pictures"; grim -g "$(slurp)" "$HOME/Pictures/paperr-$(date +%Y%m%d-%H%M%S).png"'))
hl.bind("SUPER + Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))

-- Mouse.
hl.bind("SUPER + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind("SUPER + mouse:273", hl.dsp.window.resize(), { mouse = true })
hl.bind("SUPER + mouse_down", hl.dsp.focus({ workspace = "+1" }))
hl.bind("SUPER + mouse_up",   hl.dsp.focus({ workspace = "-1" }))

-- Rules --------------------------------------------------------------------
hl.window_rule({ match = { class = "^(kitty)$" }, border_size = 5, rounding = 4 })
hl.window_rule({ match = { class = "^(firefox)$" }, border_size = 4, rounding = 3 })
hl.window_rule({ match = { class = "^(org.gnome.Nautilus)$" }, border_size = 5, rounding = 2 })
hl.window_rule({ match = { class = "^(org.gnome.Nautilus)$" }, opacity = "1.0 0.98" })
hl.window_rule({ match = { class = "^(mpv)$" }, border_size = 3, rounding = 2 })
hl.window_rule({ match = { class = "^(pavucontrol)$" }, float = true, size = "820 560", center = true })
hl.window_rule({ match = { class = "^(nm-connection-editor)$" }, float = true, size = "820 560", center = true })
hl.window_rule({ match = { class = "^(wofi)$" }, border_size = 0, rounding = 0 })
hl.window_rule({ match = { title = "^(Picture-in-Picture)$" }, float = true, pin = true, size = "520 300", move = "72% 12%" })
hl.window_rule({ match = { class = "^(xdg-desktop-portal-gtk)$" }, float = true, center = true })

hl.layer_rule({ match = { namespace = "waybar" }, blur = true, ignore_alpha = 0.1 })
hl.layer_rule({ match = { namespace = "eww" }, blur = true, ignore_alpha = 0.1 })
