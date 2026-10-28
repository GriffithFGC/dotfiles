#!/usr/bin/env bash
# Personal (fork GriffithFGC): AZERTY <-> Japanese (fcitx5 + Mozc, AZERTY layout).
#   perso-ime.sh toggle  AZERTY <-> Japonais (always lands in hiragana)
#   perso-ime.sh kana    hiragana <-> katakana (only while Mozc is active)
# Mozc has no CLI for its input mode, so the mode is switched by sending the
# Hiragana / Katakana keysyms, which the IME receives like a real key:
# - Wayland windows: wtype (virtual keyboard, routed through the IME)
# - XWayland windows (Obsidian on x11...): XWayland ignores wtype's keymap and
#   garbles the key, so Hyprland's send_shortcut sends it with the real fr
#   keymap (it has <HIRA> / <KATA>) and the app forwards it to fcitx5.
# Mozc keeps one mode per input field, so the mode is remembered per window.

WIN="$(hyprctl activewindow -j)"
ADDR="$(jq -r '.address // "none"' <<<"$WIN")"
STATE="${XDG_RUNTIME_DIR:-/tmp}/perso-ime-kana-$ADDR"

send_kana() {
    if [ "$(jq -r '.xwayland // false' <<<"$WIN")" = "true" ]; then
        hyprctl dispatch "hl.dsp.send_shortcut({ mods = \"\", key = \"$1\", window = \"address:$ADDR\" })" >/dev/null
    else
        wtype -k "$1"
    fi
}
NOTIFY=(notify-send -a "Clavier" -h string:x-canonical-private-synchronous:perso-ime -t 1500)

pgrep -x fcitx5 >/dev/null || { fcitx5 -d --replace; sleep 1; }

case "$1" in
    toggle)
        fcitx5-remote -t
        sleep 0.1
        if [ "$(fcitx5-remote -n)" = "mozc" ]; then
            send_kana Hiragana
            echo hiragana > "$STATE"
            "${NOTIFY[@]}" "Japonais" "ひらがな"
        else
            "${NOTIFY[@]}" "AZERTY" "Français"
        fi
        ;;
    kana)
        [ "$(fcitx5-remote -n)" = "mozc" ] || exit 0
        if [ "$(cat "$STATE" 2>/dev/null)" = "katakana" ]; then
            send_kana Hiragana
            echo hiragana > "$STATE"
            "${NOTIFY[@]}" "Japonais" "ひらがな"
        else
            send_kana Katakana
            echo katakana > "$STATE"
            "${NOTIFY[@]}" "Japonais" "カタカナ"
        fi
        ;;
    *)
        echo "usage: $0 toggle|kana" >&2
        exit 1
        ;;
esac
