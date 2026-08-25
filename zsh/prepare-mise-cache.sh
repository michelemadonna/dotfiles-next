#!/bin/sh

set -eu

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

[ -n "${HOME:-}" ] || die 'HOME is not set.'

mise_binary=${MISE_BIN:-}
if [ -z "$mise_binary" ]; then
  mise_binary=$(command -v mise 2>/dev/null || true)
fi
if [ -z "$mise_binary" ] && [ -x "$HOME/.local/bin/mise" ]; then
  mise_binary=$HOME/.local/bin/mise
fi
[ -x "$mise_binary" ] || die 'Mise is not installed.'
command -v git >/dev/null 2>&1 || die 'Git is required to prepare Mise.'
command -v zsh >/dev/null 2>&1 || die 'Zsh is required to validate the Mise cache.'

xdg_cache_home=${XDG_CACHE_HOME:-"$HOME/.cache"}
xdg_data_home=${XDG_DATA_HOME:-"$HOME/.local/share"}
zsh_cache_dir=${ZSH_CACHE_DIR:-"$xdg_cache_home/zsh"}
asdf_data_dir="$xdg_data_home/asdf"
activation_cache="$zsh_cache_dir/mise-activate-lazy.zsh"
completion_dir="$zsh_cache_dir/completions"
completion_cache="$completion_dir/_mise"

if [ ! -d "$asdf_data_dir" ]; then
  [ ! -e "$asdf_data_dir" ] || die "$asdf_data_dir exists and is not a directory."
  asdf_tmp="${asdf_data_dir}.tmp.$$"
  mkdir -p "$(dirname "$asdf_data_dir")"
  if ! git clone --quiet --depth 1 \
    https://github.com/asdf-vm/asdf-plugins.git "$asdf_tmp"; then
    rm -rf "$asdf_tmp"
    die 'Could not prepare ASDF compatibility data.'
  fi

  for plugin in "$asdf_tmp"/plugins/*; do
    if [ -f "$plugin" ] || [ -L "$plugin" ]; then
      plugin_name=${plugin##*/}
      rm -f "$plugin"
      mkdir -p "$asdf_tmp/plugins/$plugin_name"
    fi
  done
  mv "$asdf_tmp" "$asdf_data_dir"
fi

mkdir -p "$zsh_cache_dir" "$completion_dir"

activation_raw="${activation_cache}.raw.$$"
activation_tmp="${activation_cache}.tmp.$$"
if ! "$mise_binary" --quiet activate zsh >"$activation_raw"; then
  rm -f "$activation_raw" "$activation_tmp"
  die 'Could not generate the Mise activation cache.'
fi
awk '$0 != "_mise_hook" { print }' "$activation_raw" >"$activation_tmp"
rm -f "$activation_raw"
if ! zsh -n "$activation_tmp"; then
  rm -f "$activation_tmp"
  die 'Mise generated an invalid Zsh activation script.'
fi
mv "$activation_tmp" "$activation_cache"

completion_tmp="${completion_cache}.tmp.$$"
if ! "$mise_binary" --quiet completion zsh >"$completion_tmp"; then
  rm -f "$completion_tmp"
  die 'Could not generate the Mise completion cache.'
fi
mv "$completion_tmp" "$completion_cache"

printf 'Prepared Mise activation, completion, and ASDF compatibility data.\n'
