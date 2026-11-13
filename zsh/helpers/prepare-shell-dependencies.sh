#!/bin/sh
# Explicit installation only. Shell startup never invokes this script.
set -eu

DOTFILES_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd -P)
packages="$DOTFILES_ROOT/zsh/vendor/packages"
manifest="$DOTFILES_ROOT/zsh/vendor/packages.lock"
mkdir -p "$packages"
staging=
trap '[ -z "$staging" ] || rm -rf -- "$staging"' EXIT
trap 'exit 1' HUP INT TERM

while read -r name repository revision; do
  case "$name" in ''|'#'*) continue ;; esac
  destination="$packages/$name"
  if [ -d "$destination/.git" ] &&
     [ "$(git -C "$destination" rev-parse HEAD)" = "$revision" ]; then
    continue
  fi
  printf 'Preparing %s at %s\n' "$name" "$revision"
  staging=$(mktemp -d "$packages/.prepare-$name.XXXXXX")
  git -C "$staging" init -q
  git -C "$staging" remote add origin "$repository"
  git -C "$staging" -c advice.detachedHead=false fetch -q --depth=1 origin "$revision"
  git -C "$staging" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD
  [ "$(git -C "$staging" rev-parse HEAD)" = "$revision" ]
  rm -rf -- "$destination"
  mv -- "$staging" "$destination"
  staging=
done < "$manifest"

# Retain p10k's direct widget-dispatch optimization for the extracted runtime.
patch_file="$DOTFILES_ROOT/zsh/vendor/patches/powerlevel10k-dotsh-runtime.patch"
patch_record="$packages/.powerlevel10k-dotsh-runtime.patch"
previous_patch="$DOTFILES_ROOT/zsh/vendor/patches/powerlevel10k-runtime-v1.patch"
if [ ! -f "$patch_record" ] &&
   ! git -C "$packages/powerlevel10k" apply --reverse --check "$patch_file" >/dev/null 2>&1 &&
   git -C "$packages/powerlevel10k" apply --reverse --check "$previous_patch" >/dev/null 2>&1; then
  # Earlier preparations did not record their patch. Reverse only the exact
  # known predecessor; conflicting local edits still fail the checks below.
  git -C "$packages/powerlevel10k" apply --reverse "$previous_patch"
fi
if [ -f "$patch_record" ] && ! cmp -s "$patch_file" "$patch_record" &&
   ! git -C "$packages/powerlevel10k" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
  git -C "$packages/powerlevel10k" apply --reverse --check "$patch_record"
  git -C "$packages/powerlevel10k" apply --reverse "$patch_record"
fi
if ! git -C "$packages/powerlevel10k" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
  git -C "$packages/powerlevel10k" apply --check "$patch_file"
  git -C "$packages/powerlevel10k" apply "$patch_file"
  rm -f "$packages/powerlevel10k/internal/p10k.zsh.zwc"
fi
cp "$patch_file" "$patch_record"
patch_file="$DOTFILES_ROOT/zsh/vendor/patches/fast-syntax-highlighting-offline.patch"
if ! git -C "$packages/fast-syntax-highlighting" apply --reverse --check "$patch_file" >/dev/null 2>&1; then
  git -C "$packages/fast-syntax-highlighting" apply --check "$patch_file"
  git -C "$packages/fast-syntax-highlighting" apply "$patch_file"
  rm -f "$packages/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh.zwc"
fi

if [ ! -x "$packages/fzf/bin/fzf" ]; then
  bash "$packages/fzf/install" --bin
fi
[ -x "$packages/fzf/bin/fzf" ] || {
  printf '%s\n' 'fzf binary installation failed.' >&2
  exit 1
}
GITSTATUS_CACHE_DIR="$packages/powerlevel10k/gitstatus/usrbin" \
  sh "$packages/powerlevel10k/gitstatus/install"
DOTFILES_DIR="$DOTFILES_ROOT" zsh -dfc \
  'source "$DOTFILES_DIR/zsh/dotsh-startup.zsh" && dotsh_prepare_runtime'
mkdir -p "${XDG_CONFIG_HOME:-$HOME/.config}"
for config in fastfetch mise oh-my-posh; do
  destination="${XDG_CONFIG_HOME:-$HOME/.config}/$config"
  if [ ! -e "$destination" ] && [ ! -L "$destination" ]; then
    ln -s "$DOTFILES_ROOT/$config" "$destination"
  fi
done
printf '%s\n' 'Pinned shell dependencies are ready.'
