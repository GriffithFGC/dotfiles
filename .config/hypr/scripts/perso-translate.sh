#!/usr/bin/env bash
# Personal (fork GriffithFGC): translate the highlighted text (primary
# selection) and show it in a Quickshell bubble next to the cursor.
#   perso-translate.sh   (direction picked by perso-translate.py)

QS_DIR="$HOME/.config/quickshell/perso-translate"
# The bubble uses the live 43PR Theme.qml of the main shell
[ -e "$QS_DIR/Theme.qml" ] || ln -s ../Theme.qml "$QS_DIR/Theme.qml"

# One bubble at a time: close the previous one and wait until it is gone
qs kill -p "$QS_DIR" >/dev/null 2>&1
for _ in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -f "qs -n -p $QS_DIR" >/dev/null || break
    sleep 0.05
done

read -r CX CY < <(hyprctl cursorpos -j | jq -r '"\(.x) \(.y)"')
read -r MON MX MY < <(hyprctl monitors -j | jq -r --argjson x "$CX" --argjson y "$CY" '
    map(select($x >= .x and $y >= .y
               and $x < .x + (.width / .scale) and $y < .y + (.height / .scale)))
    | first // empty | "\(.name) \(.x) \(.y)"')

# Hyprland does not bridge PRIMARY between XWayland and Wayland, so XWayland
# windows (Obsidian on x11, Steam...) are read with xclip, the rest with wl-paste.
wl_primary() { wl-paste --primary --no-newline 2>/dev/null; }
x_primary()  { xclip -o -selection primary 2>/dev/null; }
if [ "$(hyprctl activewindow -j | jq -r '.xwayland // false')" = "true" ]; then
    TEXT="$(x_primary)"; [ -n "$TEXT" ] || TEXT="$(wl_primary)"
else
    TEXT="$(wl_primary)"; [ -n "$TEXT" ] || TEXT="$(x_primary)"
fi

TR_TEXT="$(printf %s "$TEXT" | head -c 2000)" \
TR_MON="$MON" \
TR_X="$((CX - ${MX:-0}))" \
TR_Y="$((CY - ${MY:-0}))" \
    exec qs -n -p "$QS_DIR"
