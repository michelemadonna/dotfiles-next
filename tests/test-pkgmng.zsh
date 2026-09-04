#!/usr/bin/env zsh

set -eu
setopt NO_BG_NICE

ROOT=${0:A:h:h}
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pkgmng-test.XXXXXX")
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

export HOME=$TEST_ROOT/home
export XDG_STATE_HOME=$TEST_ROOT/state
export DOTFILES_DIR=$ROOT
export MACPORTS_PREFIX=$TEST_ROOT/macports
export HOMEBREW_PREFIX=$TEST_ROOT/homebrew
export HOMEBREW_BREW=$HOMEBREW_PREFIX/bin/brew

mkdir -p \
    "$HOME" \
    "$MACPORTS_PREFIX/bin" \
    "$MACPORTS_PREFIX/sbin" \
    "$HOMEBREW_PREFIX/bin" \
    "$HOMEBREW_PREFIX/sbin" \
    "$HOMEBREW_PREFIX/opt/jq/bin"

cat >"$HOMEBREW_BREW" <<'EOF'
#!/bin/sh
case $1 in
    shellenv)
        printf 'export PATH="%s/bin:%s/sbin:$PATH"\n' "$HOMEBREW_PREFIX" "$HOMEBREW_PREFIX"
        ;;
    list)
        printf 'jq\n'
        ;;
    --prefix)
        printf '%s/opt/%s\n' "$HOMEBREW_PREFIX" "$2"
        ;;
    *)
        printf 'brew:%s\n' "$*"
        ;;
esac
EOF
cat >"$HOMEBREW_PREFIX/opt/jq/bin/jq" <<'EOF'
#!/bin/sh
printf 'brew:%s\n' "$PATH"
EOF
cat >"$MACPORTS_PREFIX/bin/jq" <<'EOF'
#!/bin/sh
printf 'macports\n'
EOF
chmod +x \
    "$HOMEBREW_BREW" \
    "$HOMEBREW_PREFIX/opt/jq/bin/jq" \
    "$MACPORTS_PREFIX/bin/jq"

path=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" /usr/bin /bin)
source "$ROOT/zsh/helpers/pkgmng"

[[ -f $PKGMGR_DB ]]
[[ $path[1] == "$MACPORTS_PREFIX/bin" ]]
[[ ${path[(Ie)$HOMEBREW_PREFIX/bin]} == 0 ]]
[[ ${path[(Ie)$HOMEBREW_PREFIX/sbin]} == 0 ]]

pkg-rescan jq >/dev/null
[[ $(_pkgmgr_db_provider jq) == brew ]]
[[ $(jq) == brew:* ]]
[[ $(jq) == *"$HOMEBREW_PREFIX/bin"* ]]

pkg-default jq macports >/dev/null
[[ $(_pkgmgr_db_provider jq) == macports ]]
[[ $(jq) == macports ]]

pkg-rescan jq >/dev/null
pkg-clean >/dev/null
[[ $(_pkgmgr_db_provider jq) == macports ]]
[[ $(jq) == macports ]]
brew upgrade >/dev/null
[[ $(_pkgmgr_db_provider jq) == macports ]]

pkg-default jq brew >/dev/null
[[ $(_pkgmgr_db_provider jq) == brew ]]
[[ $(jq) == brew:* ]]

functions[compdef]='return 0'
typeset -gA _comps
_comps[jq]=_jq
_pkgmgr_setup_completions
[[ $_comps[jq] == _jq ]]

cat >"$TEST_ROOT/test-shell" <<'EOF'
#!/bin/sh
printf 'BREW_SHELL:%s:%s\n' "$PKGMGR_BREW_SHELL" "$PATH"
EOF
chmod +x "$TEST_ROOT/test-shell"
SHELL=$TEST_ROOT/test-shell
brew_shell_output=$(brew-shell)
[[ $brew_shell_output == *"BREW_SHELL:1:"*"$HOMEBREW_PREFIX/bin"* ]]

(
    export HOME=$TEST_ROOT/no-brew-home
    export XDG_STATE_HOME=$TEST_ROOT/no-brew-state
    export HOMEBREW_PREFIX=$TEST_ROOT/missing-homebrew
    export HOMEBREW_BREW=$HOMEBREW_PREFIX/bin/brew
    path=(/usr/bin /bin)
    source "$ROOT/zsh/helpers/pkgmng"
    [[ -f $PKGMGR_DB ]]
    if brew --version >/dev/null 2>&1; then
        return 1
    else
        [[ $? == 127 ]]
    fi
)

: >"$PKGMGR_DB"
(
    source "$ROOT/zsh/helpers/pkgmng"
    _pkgmgr_db_set one one brew
) &
(
    source "$ROOT/zsh/helpers/pkgmng"
    _pkgmgr_db_set two two macports
) &
wait
[[ $(awk '$1 == "one" { ++n } END { print n + 0 }' "$PKGMGR_DB") == 1 ]]
[[ $(awk '$1 == "two" { ++n } END { print n + 0 }' "$PKGMGR_DB") == 1 ]]

mkdir -p "$TEST_ROOT/preview-bin" "$TEST_ROOT/preview-state"
ln -s /bin/echo "$TEST_ROOT/preview-bin/port"
ln -s /usr/bin/true "$TEST_ROOT/preview-bin/fzf"
port_preview=$(
    PATH="$TEST_ROOT/preview-bin:/usr/bin:/bin" \
        XDG_STATE_HOME="$TEST_ROOT/preview-state" \
        DOTFILES_DIR="$ROOT" \
        /bin/zsh -dfc '
            autoload -Uz compinit
            compinit -D
            source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-fzf.plugin.zsh"
            zstyle -s ":fzf-tab:complete:port-install:ports" \
                fzf-preview preview
            group="Available ports"
            word=jq
            eval "$preview"
        '
)
[[ $port_preview == *'MacPorts package'*jq*'info jq'* ]]

printf 'pkgmng_tests=ok\n'
