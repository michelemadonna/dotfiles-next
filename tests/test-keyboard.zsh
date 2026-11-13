#!/usr/bin/env zsh
# Run with zsh -df after entering the project through root fhome.sh.
emulate -L zsh
[[ ${DOTFILES_FAKE_HOME:-} == $HOME && $DOTFILES_DIR == $HOME/* ]] || exit 1
source "$DOTFILES_DIR/zsh/dotsh-startup.zsh" || exit 1
() {
  local OSTYPE DOTSH_KEYBOARD actual
  for OSTYPE in darwin26.0 linux-gnu; do
    DOTSH_KEYBOARD=
    dotsh_configure_keyboard || return 1
    zstyle -s ':dotsh:bindkey' keyboard actual || return 1
    if [[ $OSTYPE == darwin* ]]; then
      [[ $actual == mac ]] || return 1
    else
      [[ $actual == pc ]] || return 1
    fi
    for DOTSH_KEYBOARD in mac pc; do
      dotsh_configure_keyboard || return 1
      zstyle -s ':dotsh:bindkey' keyboard actual || return 1
      [[ $actual == $DOTSH_KEYBOARD ]] || return 1
    done
  done
  DOTSH_KEYBOARD=invalid
  if dotsh_configure_keyboard 2>/dev/null; then return 1; fi
} || exit 1
print -r -- 'Keyboard defaults, explicit mac/pc overrides and invalid value: PASS'
