-- ~/.config/hypr/perso.lua
-- Personal additions (fork GriffithFGC). This file does not exist upstream
-- (43PR/dotfiles), so it never conflicts on merge: put personal binds and
-- rules here rather than in keybinds.lua / rules.lua.
-- Loaded last from hyprland.lua.

---- BINDS ----

hl.bind(mainMod .. " + A", hl.dsp.exec_cmd("chromium --app=https://claude.ai"))
hl.bind(mainMod .. " + P", hl.dsp.exec_cmd("steam steam://rungameid/1364780")) -- Street Fighter 6
hl.bind(mainMod .. " + O", hl.dsp.exec_cmd("obsidian --ozone-platform=x11"))   -- Obsidian (X11)
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("vesktop"))                        -- Discord (Vesktop, 43pr theme)
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

---- KEYBOARD LAYOUT (AZERTY <-> Japonais) ----
-- Japanese goes through fcitx5 + Mozc with the fr layout (romaji typed on
-- AZERTY -> kana). Upstream's layout key (SUPER + X, cycles xkb layouts) is
-- rebound here to toggle the IME instead; SHIFT adds hiragana <-> katakana.

hl.env("XMODIFIERS", "@im=fcitx")   -- XWayland apps
hl.env("QT_IM_MODULE", "fcitx")     -- Qt apps (KeePassXC, ...)

hl.on("hyprland.start", function()
    hl.exec_cmd("fcitx5 -d --replace")
end)

local ime_key    = kb_layout or "X"
local ime_script = os.getenv("HOME") .. "/.config/hypr/scripts/perso-ime.sh"
hl.unbind(mainMod .. " + " .. ime_key)
hl.bind(mainMod .. " + " .. ime_key,           hl.dsp.exec_cmd(ime_script .. " toggle"))
hl.bind(mainMod .. " + SHIFT + " .. ime_key,   hl.dsp.exec_cmd(ime_script .. " kana"))

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
