#!/usr/bin/env bash
#
# sync-upstream.sh — bring 43PR/dotfiles updates into this fork safely.
#
# Fork-only file (does not exist upstream, never conflicts).
#
#   ./sync-upstream.sh status          what upstream has that we don't, and which
#                                      of those files we customized (= at risk)
#   ./sync-upstream.sh merge           merge ALL pending upstream commits (no commit)
#   ./sync-upstream.sh merge --step    merge only the NEXT upstream commit (no commit)
#   ./sync-upstream.sh verify          link new files, prune dead links, check
#                                      packages/zsh/lua/hyprland/quickshell
#   ./sync-upstream.sh finish          verify, then commit the merge
#   ./sync-upstream.sh rollback        go back to the state before the last merge
#
# Typical session:
#   ./sync-upstream.sh status
#   ./sync-upstream.sh merge --step    # repeat until status says up to date
#   (resolve conflicts if any: git mergetool / editor, then git add <file>)
#   ./sync-upstream.sh finish
#   git push origin main
#
# Rules this script enforces:
#   - never resolve a conflict blindly with --theirs on a file we customized;
#   - a backup tag (backup/pre-sync-<date>) is created before every merge;
#   - personal binds/rules go in .config/hypr/perso.lua, not in upstream files.

set -uo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UPSTREAM_REMOTE="upstream"
UPSTREAM_BRANCH="main"
UPSTREAM="$UPSTREAM_REMOTE/$UPSTREAM_BRANCH"
QS_CMD=(env QSG_RENDER_LOOP=basic qs)

cd "$REPO_DIR" || exit 1

info()    { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()      { printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"; }
warn()    { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
err()     { printf '\033[1;31m[FAIL]\033[0m %s\n' "$1" >&2; }
confirm() { read -r -p "$1 [y/N] " a; [[ "$a" == [yYoO]* ]]; }

merging() { [[ -f "$(git rev-parse --git-dir)/MERGE_HEAD" ]]; }

fetch_upstream() {
    git remote get-url "$UPSTREAM_REMOTE" >/dev/null 2>&1 || {
        err "No '$UPSTREAM_REMOTE' remote. Add it: git remote add upstream https://github.com/43PR/dotfiles.git"
        exit 1
    }
    info "Fetching $UPSTREAM_REMOTE..."
    git fetch --quiet "$UPSTREAM_REMOTE" || { err "git fetch failed"; exit 1; }
}

# Files the fork owner changed (own commits since the fork point + uncommitted).
# Counting only own-authored commits ignores upstream commits that were later
# rewritten upstream, which would otherwise look like local changes.
# $1: ref to look from (default HEAD).
personal_files() {
    local ref="${1:-HEAD}" me
    me="$(git config user.email)"
    git log --no-merges --author="$me" --name-only --format= "$UPSTREAM".."$ref" | grep -v '^$'
    if [[ "$ref" == HEAD ]] && ! merging; then
        git diff --name-only HEAD
        git ls-files --others --exclude-standard
    fi
    return 0
}

cmd_status() {
    fetch_upstream
    local base pending
    base="$(git merge-base HEAD "$UPSTREAM")"
    pending="$(git rev-list --count HEAD.."$UPSTREAM")"

    if [[ "$pending" -eq 0 ]]; then
        ok "Up to date with $UPSTREAM."
        return 0
    fi

    info "$pending upstream commit(s) not merged yet (oldest first):"
    git log --reverse --format='    %h %ad %s' --date=short HEAD.."$UPSTREAM"

    # Upstream force-pushed: commits we merged earlier no longer exist there.
    # Their "new" versions will conflict with the old ones for no real reason.
    local me rewritten
    me="$(git config user.email)"
    rewritten="$(git log --no-merges --format='%h %ae %s' "$UPSTREAM"..HEAD | awk -v me="$me" '$2 != me')"
    if [[ -n "$rewritten" ]]; then
        warn "Upstream rewrote its history (force-push). These upstream commits we had are gone upstream:"
        printf '    %s\n' "$rewritten"
        warn "Conflicts on files listed below but NOT in 'customized' are upstream-vs-upstream: taking theirs is safe for those."
    fi

    local changed customized at_risk=()
    changed="$(git diff --name-only "$base" "$UPSTREAM")"
    customized="$(personal_files | sort -u)"
    while IFS= read -r f; do
        [[ -n "$f" ]] && grep -qxF "$f" <<<"$customized" && at_risk+=("$f")
    done <<<"$changed"

    info "Files changed upstream: $(grep -c . <<<"$changed")"
    if [[ "${#at_risk[@]}" -gt 0 ]]; then
        warn "Customized in the fork AND changed upstream (review these by hand):"
        printf '    %s\n' "${at_risk[@]}"
    else
        ok "None of the upstream changes touch files customized in the fork."
    fi

    local new_files
    new_files="$(git diff --name-only --diff-filter=A "$base" "$UPSTREAM" -- .config)"
    [[ -n "$new_files" ]] && info "New files upstream (verify will symlink them):" && printf '    %s\n' $new_files
    local pkgs
    pkgs="$(git diff "$base" "$UPSTREAM" -- packages.txt | grep '^+[^+]' | cut -c2-)"
    [[ -n "$pkgs" ]] && info "New packages upstream:" && printf '    %s\n' $pkgs
    return 0
}

cmd_merge() {
    local step=0
    [[ "${1:-}" == "--step" ]] && step=1

    merging && { err "A merge is already in progress. Resolve it, then: $0 finish (or $0 rollback)."; exit 1; }
    if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
        err "Uncommitted changes. Commit them first (git add -A && git commit -m '...')."
        exit 1
    fi

    fetch_upstream
    local target
    if [[ "$step" -eq 1 ]]; then
        target="$(git rev-list --reverse HEAD.."$UPSTREAM" | head -1)"
    else
        target="$(git rev-parse "$UPSTREAM")"
    fi
    [[ -z "$target" ]] && { ok "Nothing to merge."; exit 0; }

    local tag="backup/pre-sync-$(date +%Y%m%d-%H%M%S)"
    git tag "$tag" HEAD
    ok "Backup tag: $tag (rollback: $0 rollback)"

    info "Merging $(git log -1 --format='%h %s' "$target")"
    git merge --no-ff --no-commit "$target" >/dev/null 2>&1

    local conflicts
    conflicts="$(git diff --name-only --diff-filter=U)"
    if [[ -n "$conflicts" ]]; then
        local customized; customized="$(personal_files "$tag" | sort -u)"
        warn "Conflicts:"
        while IFS= read -r f; do
            if grep -qxF "$f" <<<"$customized"; then
                printf '    \033[1;31m%s\033[0m  (customized: merge by hand, keep your changes)\n' "$f"
            else
                printf '    %s  (not customized: "git checkout --theirs -- %s && git add %s" is safe)\n' "$f" "$f" "$f"
            fi
        done <<<"$conflicts"
        info "After resolving: $0 finish"
        exit 2
    fi

    ok "Merged without conflicts (not committed yet)."
    info "Review with: git diff --cached --stat   then: $0 finish"
}

cmd_verify() {
    local fails=0

    # 1. No conflict markers left
    if [[ -n "$(git diff --name-only --diff-filter=U)" ]]; then
        err "Unresolved conflicts: $(git diff --name-only --diff-filter=U | tr '\n' ' ')"
        return 1
    fi
    if git grep -nE '^(<<<<<<<|>>>>>>>) ' -- .config >/dev/null 2>&1; then
        err "Conflict markers still present:"; git grep -nE '^(<<<<<<<|>>>>>>>) ' -- .config
        fails=$((fails + 1))
    fi

    # 2. Link new files (upstream updater, no packages), then prune dead links
    info "Linking new files and regenerating theme (update.sh --skip-packages)..."
    ./update.sh --skip-packages >/dev/null 2>&1 || { err "update.sh failed (run it by hand to see why)"; fails=$((fails + 1)); }
    local dead
    dead="$(find "$HOME/.config" -xtype l -lname "$REPO_DIR/*" 2>/dev/null)"
    if [[ -n "$dead" ]]; then
        info "Removing links to files deleted upstream:"; printf '    %s\n' $dead
        find "$HOME/.config" -xtype l -lname "$REPO_DIR/*" -delete
    fi
    ok "Symlinks up to date."

    # 3. Packages
    local missing=()
    while IFS= read -r p; do
        p="${p%%#*}"; p="${p//[[:space:]]/}"
        [[ -z "$p" ]] && continue
        pacman -Qi "$p" >/dev/null 2>&1 || pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
    done < packages.txt
    [[ "${#missing[@]}" -gt 0 ]] && warn "Not installed (from packages.txt): ${missing[*]}  -> ./update.sh installs them"

    # 4. zsh: every sourced file must exist
    local f
    while IFS= read -r f; do
        [[ -r "$f" ]] || warn ".zshrc sources a missing file: $f"
    done < <(grep -oE '^source\s+/\S+' .config/.zshrc | awk '{print $2}')
    zsh -n .config/.zshrc || { err ".zshrc syntax error"; fails=$((fails + 1)); }

    # 5. Hyprland Lua
    if command -v luac >/dev/null 2>&1; then
        for f in .config/hypr/*.lua; do
            luac -p "$f" 2>/dev/null || { err "Lua syntax error: $f"; luac -p "$f"; fails=$((fails + 1)); }
        done
    fi
    if command -v hyprctl >/dev/null 2>&1 && [[ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
        hyprctl reload >/dev/null
        sleep 1
        local errs; errs="$(hyprctl configerrors | grep -v '^\s*$')"
        if [[ -n "$errs" ]]; then err "Hyprland config errors:"; echo "$errs"; fails=$((fails + 1)); else ok "Hyprland config reloaded, no errors ($(hyprctl binds -j | grep -c '"key"') binds)."; fi
    fi

    # 6. Quickshell: restart and check it actually loads
    if command -v qs >/dev/null 2>&1 && [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
        info "Restarting Quickshell..."
        pkill -x qs 2>/dev/null; sleep 1
        setsid -f "${QS_CMD[@]}" >/dev/null 2>&1
        sleep 4
        local log
        log="$(\ls -td /run/user/"$(id -u)"/quickshell/by-id/* 2>/dev/null | head -1)/log.log"
        if ! pgrep -x qs >/dev/null || grep -q 'Failed to load configuration' "$log" 2>/dev/null; then
            err "Quickshell failed to start:"; grep -A3 'ERROR' "$log" 2>/dev/null | head -10
            fails=$((fails + 1))
        else
            ok "Quickshell running."
        fi
    fi

    if [[ "$fails" -gt 0 ]]; then err "$fails check(s) failed."; return 1; fi
    ok "All checks passed. Also try your lock screen: hyprlock (unlock from a TTY with: pkill -USR1 hyprlock)."
}

cmd_finish() {
    cmd_verify || { err "Fix the problems above (or $0 rollback), then re-run $0 finish."; exit 1; }
    if merging; then
        git add -A
        git commit --no-edit >/dev/null && ok "Merge committed: $(git log -1 --format='%h %s')"
    else
        ok "No merge in progress, nothing to commit."
    fi
    local left; left="$(git rev-list --count HEAD.."$UPSTREAM")"
    [[ "$left" -gt 0 ]] && info "$left upstream commit(s) left: $0 merge --step" || ok "Up to date with $UPSTREAM."
    info "Push when happy: git push origin main"
}

cmd_rollback() {
    local tag; tag="$(git tag -l 'backup/pre-sync-*' --sort=-creatordate | head -1)"
    [[ -z "$tag" ]] && { err "No backup tag found."; exit 1; }
    warn "This discards the current merge and returns to $tag ($(git log -1 --format='%h %s' "$tag"))."
    git status --short | head -20
    confirm "Continue?" || exit 1
    merging && git merge --abort
    git reset --hard "$tag" && ok "Back to $tag. Run $0 verify to relink and reload."
}

case "${1:-status}" in
    status)   cmd_status ;;
    merge)    shift; cmd_merge "$@" ;;
    verify)   cmd_verify ;;
    finish)   cmd_finish ;;
    rollback) cmd_rollback ;;
    -h|--help|help) sed -n '3,27p' "$0" | sed 's/^# \{0,1\}//' ;;
    *) err "Unknown command: $1"; exit 1 ;;
esac
