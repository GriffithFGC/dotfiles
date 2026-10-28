#!/usr/bin/env bash
# Personal (fork GriffithFGC): translate the highlighted text (primary
# selection) and show it in a Quickshell bubble next to the cursor.
#   perso-translate.sh [langs]   default ja:en (translate-shell syntax)

QS_DIR="$HOME/.config/quickshell/perso-translate"
# The bubble uses the live 43PR Theme.qml of the main shell
[ -e "$QS_DIR/Theme.qml" ] || ln -s ../Theme.qml "$QS_DIR/Theme.qml"

# One bubble at a time
qs kill -p "$QS_DIR" >/dev/null 2>&1

read -r CX CY < <(hyprctl cursorpos -j | jq -r '"\(.x) \(.y)"')
read -r MON MX MY < <(hyprctl monitors -j | jq -r --argjson x "$CX" --argjson y "$CY" '
    map(select($x >= .x and $y >= .y
               and $x < .x + (.width / .scale) and $y < .y + (.height / .scale)))
    | first // empty | "\(.name) \(.x) \(.y)"')

TR_TEXT="$(wl-paste --primary --no-newline 2>/dev/null | head -c 2000)" \
TR_LANGS="${1:-ja:en}" \
TR_MON="$MON" \
TR_X="$((CX - ${MX:-0}))" \
TR_Y="$((CY - ${MY:-0}))" \
    exec qs -n -p "$QS_DIR"
