-- ~/.config/hypr/perso.lua
-- Personal additions (fork GriffithFGC). This file does not exist upstream
-- (43PR/dotfiles), so it never conflicts on merge: put personal binds and
-- rules here rather than in keybinds.lua / rules.lua.
-- Loaded last from hyprland.lua.

---- BINDS ----

hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("chromium --app=https://claude.ai"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("steam steam://rungameid/1364780")) -- Street Fighter 6
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("obsidian --ozone-platform=x11"))   -- Obsidian (X11)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("discord"))
hl.bind(mainMod .. " + Z", hl.dsp.exec_cmd("spotify"))

-- Pick a color with hyprpicker, copy the hex to the clipboard
hl.bind(mainMod .. " + G", hl.dsp.exec_cmd([[sh -c 'c=$(hyprpicker -n -z -r | tr -d "#"); [ -n "$c" ] && printf %s "$c" | wl-copy && notify-send "Couleur copiée" "$c"']]))

-- Bring the running Steam game window to the current workspace
hl.bind(mainMod .. " + SHIFT + G", function()
    local w = "class:steam_app_.*"
    hl.dispatch(hl.dsp.window.move({ workspace = hl.get_active_workspace(), window = w }))
    hl.dispatch(hl.dsp.focus({ window = w }))
    hl.dispatch(hl.dsp.window.bring_to_top())
end)

---- RULES ----

hl.window_rule({
    name = "keepassxc-ws",
    match = { class = "^(org.keepassxc.KeePassXC)$" },
    workspace = "4 silent",
})

hl.window_rule({
    name = "steam-ws",
    match = { class = "^(steam)$" },
    workspace = "4 silent",
})
