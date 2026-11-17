#!/bin/sh
# Full installation, including runtime compilation and configuration links.
set -eu

DOTFILES_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd -P)
zsh -df "$DOTFILES_ROOT/zsh/helpers/shell-packages.zsh"
DOTFILES_DIR="$DOTFILES_ROOT" zsh -dfc \
  'source "$DOTFILES_DIR/zsh/runtime/dotsh-startup.zsh" && dotsh_prepare_runtime'
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
for config in fastfetch mise oh-my-posh; do
  destination="${XDG_CONFIG_HOME:-$HOME/.config}/$config"
  if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
    ln -s "$DOTFILES_ROOT/$config" "$destination"
  fi
done
printf '%s\n' 'Pinned shell dependencies are ready.'
