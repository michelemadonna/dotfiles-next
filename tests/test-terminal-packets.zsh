#!/usr/bin/env zsh
# Run with zsh -df after entering the fake HOME through root fhome.sh.
emulate -L zsh
setopt err_exit extended_glob
zmodload zsh/parameter zsh/stat
[[ ${DOTFILES_FAKE_HOME:-} == $HOME && $DOTFILES_DIR == $HOME/* ]] || exit 1
fpath=("$DOTFILES_DIR/zsh/runtime/fn" $fpath)
autoload -Uz -- -dotsh-enable-iterm2-integration -dotsh-vte-osc7
typeset -g DOTSH_TEST_PACKET=
function -dotsh-tmux-bypass() { builtin printf -v DOTSH_TEST_PACKET "$@" }
-dotsh-enable-iterm2-integration
typeset -g iterm2_hostname=test-host
local escaped_cwd=${${PWD//$'\a'/\\a}//$'\e'/\\e}
local metadata=$'\e]1337;RemoteHost='"${(%):-%n}"$'@test-host\a\e]1337;CurrentDir='"$escaped_cwd"$'\a'

_dotsh_iterm_cmd=0
-dotsh-iterm2-precmd 0
[[ $DOTSH_TEST_PACKET == $metadata ]]
_dotsh_iterm_cmd=1
-dotsh-iterm2-precmd 7
[[ $DOTSH_TEST_PACKET == $'\e]133;C;\a\e]133;D;7\a' ]]
-dotsh-iterm2-preexec
[[ $DOTSH_TEST_PACKET == $'\e]133;C;\a' && $_dotsh_iterm_cmd == 2 ]]
-dotsh-iterm2-precmd 0
[[ $DOTSH_TEST_PACKET == $'\e]133;D;0\a'$metadata ]]
_dotsh_terminal_dirty=1
-dotsh-iterm2-precmd 0
[[ $DOTSH_TEST_PACKET == $'\e]133;C;\a\e]133;D;0\a'$metadata ]]
_dotsh_terminal_dirty=0

-dotsh-vte-osc7
[[ $_dotsh_vte_last_cwd == $PWD && $_dotsh_vte_last_encoded_cwd == *%40* ]]
local encoded=$_dotsh_vte_last_encoded_cwd packet=$DOTSH_TEST_PACKET
-dotsh-vte-osc7
[[ $_dotsh_vte_last_encoded_cwd == $encoded && $DOTSH_TEST_PACKET == $packet ]]

# Use a private file descriptor to check title output without touching the TTY.
local title_file=$(mktemp "$HOME/.cache/terminal-title-test.XXXXXX")
trap 'command rm -f -- "$title_file"' EXIT
local title_fd
exec {title_fd}> "$title_file"
typeset -gi _dotsh_tty_fd=$title_fd
autoload -Uz -- -dotsh-set-term-title
_dotsh_terminal_dirty=1
-dotsh-set-term-title standalone-test
local title_packet=$'\e]0;standalone-test\a'
[[ $(<"$title_file") == $title_packet ]]
_dotsh_terminal_dirty=0
-dotsh-set-term-title standalone-test
[[ $(<"$title_file") == $title_packet ]]
_dotsh_terminal_dirty=1
-dotsh-set-term-title standalone-test
[[ $(<"$title_file") == $title_packet$title_packet ]]
_dotsh_terminal_dirty=0
-dotsh-set-term-title changed-title
[[ $(<"$title_file") == $title_packet$title_packet$'\e]0;changed-title\a' ]]
exec {title_fd}>&-
print -r -- 'Terminal packets: boundaries, metadata, OSC7 and title invalidation PASS'
