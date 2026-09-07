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
command -v zsh >/dev/null 2>&1 || die 'Zsh is required to validate the Mise cache.'

xdg_cache_home=${XDG_CACHE_HOME:-"$HOME/.cache"}
zsh_cache_dir=${ZSH_CACHE_DIR:-"$xdg_cache_home/zsh"}
asdf_cache_dir="$xdg_cache_home/zsh"
asdf_data_dir="$asdf_cache_dir/mise-asdf"
asdf_lock_dir="${asdf_data_dir}.lock"
activation_cache="$zsh_cache_dir/mise-activate-lazy.zsh"
completion_dir="$zsh_cache_dir/completions"
completion_cache="$completion_dir/_mise"

cleanup_asdf_compat() {
  rm -rf "$asdf_tmp" "$asdf_old"
  rm -f "$asdf_lock_dir/pid"
  rmdir "$asdf_lock_dir" 2>/dev/null || true
}

prepare_asdf_compat() {
  lock_attempts=0
  while ! mkdir "$asdf_lock_dir" 2>/dev/null; do
    lock_pid=
    if [ -r "$asdf_lock_dir/pid" ]; then
      IFS= read -r lock_pid < "$asdf_lock_dir/pid" || lock_pid=
    fi
    case $lock_pid in
      ''|*[!0-9]*) ;;
      *)
        if ! kill -0 "$lock_pid" 2>/dev/null; then
          stale_lock="${asdf_lock_dir}.stale.$$"
          if mv "$asdf_lock_dir" "$stale_lock" 2>/dev/null; then
            rm -rf "$stale_lock"
            continue
          fi
        fi
        ;;
    esac
    lock_attempts=$((lock_attempts + 1))
    [ "$lock_attempts" -lt 400 ] ||
      die 'Timed out waiting to prepare ASDF compatibility data.'
    sleep 0.05
  done
  printf '%s\n' "$$" > "$asdf_lock_dir/pid"

  asdf_tmp="${asdf_data_dir}.tmp.$$"
  asdf_old="${asdf_data_dir}.old.$$"
  trap 'cleanup_asdf_compat' 0
  trap 'exit 1' HUP INT TERM
  rm -rf "$asdf_tmp" "$asdf_old"
  mkdir -p "$asdf_tmp/plugins" "$asdf_tmp/installs"

  installed_list="$asdf_tmp/.installed"
  installed_pairs="$asdf_tmp/.pairs"
  if ! "$mise_binary" ls --installed --quiet >"$installed_list" 2>/dev/null; then
    die 'Could not list installed Mise runtimes.'
  fi
  if ! awk 'NF >= 2 { print $1, $2 }' "$installed_list" >"$installed_pairs"; then
    die 'Could not parse installed Mise runtimes.'
  fi
  while IFS=' ' read -r tool version; do
    case $tool in
      node) tool=nodejs ;;
    esac
    # Powerlevel10k's ASDF segment can consume only single-directory ASDF
    # plugin names, not backend-qualified Mise identifiers containing '/'.
    case $tool:$version in
      *[!A-Za-z0-9_.+@:-]*|.*:*|*:.*|*..*:*) continue ;;
    esac
    mkdir -p "$asdf_tmp/plugins/$tool" "$asdf_tmp/installs/$tool/$version"
  done < "$installed_pairs"
  rm -f "$installed_list" "$installed_pairs"

  if [ -e "$asdf_data_dir" ]; then
    mv "$asdf_data_dir" "$asdf_old"
  fi
  if mv "$asdf_tmp" "$asdf_data_dir"; then
    rm -rf "$asdf_old"
  else
    [ ! -e "$asdf_old" ] || mv "$asdf_old" "$asdf_data_dir"
    die 'Could not prepare ASDF compatibility data.'
  fi

  cleanup_asdf_compat
  trap - 0 HUP INT TERM
}

mkdir -p "$zsh_cache_dir" "$completion_dir" "$asdf_cache_dir"
prepare_asdf_compat

if [ "${1:-}" = --asdf-only ]; then
  exit 0
fi

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
