#!/usr/bin/env bash
# Personal (fork GriffithFGC): AZERTY <-> Japanese (fcitx5 + Mozc, AZERTY layout).
#   perso-ime.sh toggle  AZERTY <-> Japonais (always lands in hiragana)
#   perso-ime.sh kana    hiragana <-> katakana (only while Mozc is active)
# Mozc has no CLI for its input mode, so the mode is switched by sending the
# Hiragana / Katakana keysyms through a virtual keyboard (wtype), which the IME
# receives like a real key. The current mode is remembered in $STATE.

STATE="${XDG_RUNTIME_DIR:-/tmp}/perso-ime-kana"
NOTIFY=(notify-send -a "Clavier" -h string:x-canonical-private-synchronous:perso-ime -t 1500)

pgrep -x fcitx5 >/dev/null || { fcitx5 -d --replace; sleep 1; }

case "$1" in
    toggle)
        fcitx5-remote -t
        sleep 0.1
        if [ "$(fcitx5-remote -n)" = "mozc" ]; then
            wtype -k Hiragana
            echo hiragana > "$STATE"
            "${NOTIFY[@]}" "Japonais" "ひらがな"
        else
            "${NOTIFY[@]}" "AZERTY" "Français"
        fi
        ;;
    kana)
        [ "$(fcitx5-remote -n)" = "mozc" ] || exit 0
        if [ "$(cat "$STATE" 2>/dev/null)" = "katakana" ]; then
            wtype -k Hiragana
            echo hiragana > "$STATE"
            "${NOTIFY[@]}" "Japonais" "ひらがな"
        else
            wtype -k Katakana
            echo katakana > "$STATE"
            "${NOTIFY[@]}" "Japonais" "カタカナ"
        fi
        ;;
    *)
        echo "usage: $0 toggle|kana" >&2
        exit 1
        ;;
esac
