#!/usr/bin/env zsh
# Run with zsh -df from the fake HOME; no startup cache or network is needed.
emulate -L zsh
setopt err_exit
[[ ${DOTFILES_FAKE_HOME:-} == $HOME && $DOTFILES_DIR == $HOME/* ]] || exit 1
zmodload zsh/zle zsh/zleparameter || exit 1
local test_cache=$(mktemp -d "$HOME/.cache/cold-highlighting.XXXXXX")
trap 'command rm -rf -- "$test_cache"' EXIT
export XDG_CACHE_HOME=$test_cache
export FAST_WORK_DIR="$test_cache/fsh"
curl() { print -r -- curl >> "$test_cache/network-attempts"; return 1; }
wget() { print -r -- wget >> "$test_cache/network-attempts"; return 1; }
source "$DOTFILES_DIR/zsh/dotsh-startup.zsh" || exit 1
dotsh_load_highlighting || exit 1
[[ -s $FAST_WORK_DIR/secondary_theme.zsh && ! -e $test_cache/network-attempts ]] || exit 1
command cmp "$FAST_WORK_DIR/secondary_theme.zsh" "$DOTSH_PACKAGES/fast-syntax-highlighting/share/free_theme.zsh" || exit 1
print -r -- 'Cold highlighting: bundled theme, no startup download PASS'
