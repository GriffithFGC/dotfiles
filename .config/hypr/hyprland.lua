-- ~/.config/hypr/hyprland.lua
-- Docs: https://wiki.hypr.land/Configuring/Start/

---- MY PROGRAMS ----

mainMod    = "SUPER"
terminal   = "kitty"
menu       = "rofi -show drun"
fileManager = "thunar"
browser    = "zen-browser"

---- AUTOSTART ----

hl.on("hyprland.start", function()
    hl.exec_cmd("hyprlock")
    hl.exec_cmd("dunst")  
    hl.exec_cmd("nm-applet")
    hl.exec_cmd("wl-paste --type text --watch cliphist store")
    hl.exec_cmd("wl-paste --type image --watch cliphist store")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("~/.config/hypr/scripts/wallpaper-restore.sh")
    hl.exec_cmd("sleep 2 && QSG_RENDER_LOOP=basic qs")
    hl.exec_cmd("keepassxc")
    hl.exec_cmd("steam")
end)

---- ENVIRONMENT VARIABLES ----

hl.env("XCURSOR_SIZE", "14")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("MOZ_ENABLE_WAYLAND", "1")

---- INPUT ----

hl.config({
    input = {
        kb_layout = "fr",
        follow_mouse = 1,
        sensitivity = -0.75,
	accel_profile ="flat",
        touchpad = {
            natural_scroll = false,
            tap_to_click = true,
        },
    },
})

-- LAYOUT
hl.config({
    dwindle = { preserve_split = true },
})
hl.config({
    master = { new_status = "master" },
})

-- MISC
hl.config({
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
    },
})

---- SPLIT-OUT FILES ----

require("monitors")
require("keybinds")
require("look")
require("rules")

-- HyprMod managed settings
require("hyprland-gui")
