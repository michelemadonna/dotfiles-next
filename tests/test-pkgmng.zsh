#!/usr/bin/env zsh

set -eu
setopt NO_BG_NICE

ROOT=${0:A:h:h}
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-pkgmng-test.XXXXXX")
trap 'rm -rf -- "$TEST_ROOT"' EXIT HUP INT TERM

export HOME=$TEST_ROOT/home
export XDG_STATE_HOME=$TEST_ROOT/state
export DOTFILES_DIR=$ROOT
export DOTFILES_INTEL_PACKAGE_MANAGER=macports
export MACPORTS_PREFIX=$TEST_ROOT/macports
export HOMEBREW_PREFIX=$TEST_ROOT/homebrew
export HOMEBREW_BREW=$HOMEBREW_PREFIX/bin/brew
export PLUGIN_TEST_OSTYPE=darwin26.0
export TEST_UNAME_MACHINE=x86_64

mkdir -p \
    "$HOME" \
    "$TEST_ROOT/test-bin" \
    "$MACPORTS_PREFIX/bin" \
    "$MACPORTS_PREFIX/sbin" \
    "$HOMEBREW_PREFIX/bin" \
    "$HOMEBREW_PREFIX/sbin" \
    "$HOMEBREW_PREFIX/opt/jq/bin"

cat >"$TEST_ROOT/test-bin/uname" <<'EOF'
#!/bin/sh
printf '%s\n' "${TEST_UNAME_MACHINE:-x86_64}"
EOF
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
    info)
        [ "$4" != missing ]
        ;;
    deps)
        case "$7:$8" in
            bottled:)
                printf 'dep-bottle\ndep-source\n'
                ;;
            dependency-error:)
                exit 1
                ;;
            multi-one:multi-two)
                printf 'dep-shared\ndep-one\ndep-shared\n'
                ;;
        esac
        ;;
    --cache)
        if [ "$3" = --build-from-source ]; then
            formula=$5
            printf '/cache/%s.source.tar.gz\n' "$formula"
        else
            formula=$4
            case $formula in
                dep-source|source-only)
                    printf '/cache/%s.source.tar.gz\n' "$formula"
                    ;;
                cache-error)
                    exit 1
                    ;;
                *)
                    printf '/cache/%s.bottle.tar.gz\n' "$formula"
                    ;;
            esac
        fi
        ;;
    formulae)
        printf 'bottled\nsource-only\n'
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
cat >"$MACPORTS_PREFIX/bin/port" <<'EOF'
#!/bin/sh
exit 0
EOF
chmod +x \
    "$TEST_ROOT/test-bin/uname" \
    "$HOMEBREW_BREW" \
    "$HOMEBREW_PREFIX/opt/jq/bin/jq" \
    "$MACPORTS_PREFIX/bin/jq" \
    "$MACPORTS_PREFIX/bin/port"

OSTYPE=$PLUGIN_TEST_OSTYPE
path=("$TEST_ROOT/test-bin" "$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin" /usr/bin /bin)
source "$ROOT/zsh/z4h.custom.plugins/z4h-pkgmng.plugin.zsh"

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

set +e
bottle_output=$(brew-bottle-check bottled)
bottle_status=$?
brew-bottle-check missing >/dev/null 2>&1
missing_status=$?
brew-bottle-check dependency-error >/dev/null 2>&1
dependency_error_status=$?
brew-bottle-check >/dev/null 2>&1
usage_status=$?
set -e

[[ $bottle_output == *'bottled                                BOTTLE'* ]]
[[ $bottle_output == *'dep-bottle                             BOTTLE'* ]]
[[ $bottle_output == *'dep-source                             SOURCE'* ]]
[[ $bottle_output == *'Checked: 3'* ]]
[[ $bottle_output == *'RESULT: SOURCE BUILD REQUIRED'* ]]
(( bottle_status == 1 ))
(( missing_status == 2 ))
(( dependency_error_status == 2 ))
(( usage_status == 2 ))

bottles_only_output=$(brew-bottle-check bottles-only)
[[ $bottles_only_output == *'Checked: 1'* ]]
[[ $bottles_only_output == *'RESULT: BOTTLES ONLY'* ]]

multiple_output=$(brew-bottle-check multi-one multi-two)
[[ $multiple_output == *'dep-shared                             BOTTLE'* ]]
[[ $multiple_output == *'dep-one                                BOTTLE'* ]]
[[ $multiple_output == *'Checked: 4'* ]]
[[ $multiple_output == *'RESULT: BOTTLES ONLY'* ]]

typeset -gA _comps
functions[compdef]='_comps[$2]=$1'
_comps[jq]=_jq
_pkgmgr_setup_completions
[[ $_comps[jq] == _jq ]]
[[ $_comps[brew-bottle-check] == _brew_bottle_check_completion ]]

cat >"$TEST_ROOT/test-shell" <<'EOF'
#!/bin/sh
printf 'BREW_SHELL:%s:%s\n' "$PKGMGR_BREW_SHELL" "$PATH"
EOF
chmod +x "$TEST_ROOT/test-shell"
SHELL=$TEST_ROOT/test-shell
brew_shell_output=$(brew-shell)
[[ $brew_shell_output == *"BREW_SHELL:1:"*"$HOMEBREW_PREFIX/bin"* ]]

assert_plugin_disabled() {
    local test_name=$1
    local test_ostype=$2
    local test_machine=$3
    local test_provider=$4
    local test_brew=$5
    local test_state=$TEST_ROOT/disabled-$test_name

    HOME=$TEST_ROOT/disabled-home \
        XDG_STATE_HOME=$test_state \
        DOTFILES_DIR=$ROOT \
        DOTFILES_INTEL_PACKAGE_MANAGER=$test_provider \
        MACPORTS_PREFIX=$MACPORTS_PREFIX \
        HOMEBREW_PREFIX=$HOMEBREW_PREFIX \
        HOMEBREW_BREW=$test_brew \
        PLUGIN_TEST_OSTYPE=$test_ostype \
        TEST_UNAME_MACHINE=$test_machine \
        PATH="$TEST_ROOT/test-bin:/usr/bin:/bin" \
        /bin/zsh -dfc '
            OSTYPE=$PLUGIN_TEST_OSTYPE
            source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-pkgmng.plugin.zsh"
            (( ! $+functions[brew] ))
            (( ! ${+parameters[PKGMGR_DB]} ))
            [[ ! -e "$XDG_STATE_HOME/zsh/package-providers.db" ]]
        '
}

assert_plugin_disabled apple-silicon darwin26.0 arm64 macports "$HOMEBREW_BREW"
assert_plugin_disabled linux linux-gnu x86_64 macports "$HOMEBREW_BREW"
assert_plugin_disabled homebrew-primary darwin26.0 x86_64 homebrew "$HOMEBREW_BREW"
assert_plugin_disabled missing-brew darwin26.0 x86_64 macports "$TEST_ROOT/missing-brew"

: >"$PKGMGR_DB"
(
    source "$ROOT/zsh/z4h.custom.plugins/z4h-pkgmng.plugin.zsh"
    _pkgmgr_db_set one one brew
) &
(
    source "$ROOT/zsh/z4h.custom.plugins/z4h-pkgmng.plugin.zsh"
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
            zstyle -s ":fzf-tab:complete:port:argument-2" \
                fzf-preview preview
            group="Available ports"
            word=jq
            eval "$preview"
        '
)
[[ $port_preview == 'info jq' ]]

brew_bottle_preview=$(
    PATH="$TEST_ROOT/preview-bin:/usr/bin:/bin" \
        XDG_STATE_HOME="$TEST_ROOT/preview-state" \
        DOTFILES_DIR="$ROOT" \
        /bin/zsh -dfc '
            autoload -Uz compinit
            compinit -D
            brew() {
                [[ $1 == info && $2 == --formula && $3 == -- ]] || return 1
                printf "brew info %s\n" "$4"
            }
            PKGMGR_BREW_MANAGED=true
            source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-fzf.plugin.zsh"
            zstyle -s ":fzf-tab:complete:brew-bottle-check:argument-1" \
                fzf-preview preview
            word=jq
            eval "$preview"
        '
)
[[ $brew_bottle_preview == 'brew info jq' ]]

printf 'pkgmng_tests=ok\n'
