#!/bin/sh
# Exercise an upgrade from a prepared, patched dependency without a patch record.
set -eu
[ "${DOTFILES_FAKE_HOME:-}" = "$HOME" ] || exit 1
DOTFILES_ROOT=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd -P)
fixture=$(mktemp -d "$HOME/.cache/dotsh-patch-test.XXXXXX")
trap 'rm -rf -- "$fixture"' EXIT HUP INT TERM
packages="$fixture/packages"
mkdir -p "$packages"
git clone -q --shared "$DOTFILES_ROOT/zsh/vendor/packages/powerlevel10k" "$packages/powerlevel10k"
git -C "$packages/powerlevel10k" apply "$DOTFILES_ROOT/zsh/vendor/patches/powerlevel10k-runtime-v1.patch"

# Run the shared patch helper without downloading dependencies.
apply_patch() {
  DOTFILES_DIR="$DOTFILES_ROOT" zsh -dfc '
    source "$DOTFILES_DIR/zsh/helpers/shell-packages.zsh"
    dotsh_patch_powerlevel10k "$1/powerlevel10k" "$1/.powerlevel10k-dotsh-runtime.patch"
  ' zsh "$packages"
}
apply_patch
git -C "$packages/powerlevel10k" apply --reverse --check "$DOTFILES_ROOT/zsh/vendor/patches/powerlevel10k-dotsh-runtime.patch"
cmp "$packages/.powerlevel10k-dotsh-runtime.patch" "$DOTFILES_ROOT/zsh/vendor/patches/powerlevel10k-dotsh-runtime.patch"
git -C "$packages/powerlevel10k" diff > "$fixture/first.diff"
apply_patch
git -C "$packages/powerlevel10k" diff > "$fixture/repeat.diff"
cmp "$fixture/first.diff" "$fixture/repeat.diff"
printf '%s\n' 'Previous dependency patch upgrade and idempotency: PASS'
