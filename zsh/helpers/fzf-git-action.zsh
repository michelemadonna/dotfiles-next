#!/usr/bin/env zsh

emulate -L zsh
setopt no_aliases

_z4h_fzf_git_preview_pager() {
    local preview_position=right
    if [[ -r ${FZF_TAB_PREVIEW_STATE_FILE:-} ]]; then
        preview_position=$(<"$FZF_TAB_PREVIEW_STATE_FILE")
    fi

    if [[ $preview_position == down || $preview_position == down90 ]] &&
        (( $+commands[delta] )); then
        command delta \
            --side-by-side \
            --paging=never \
            --width="${FZF_PREVIEW_COLUMNS:-120}"
    else
        command cat
    fi
}

_z4h_fzf_git_edit() {
    local mode=$1 value=$2 target=$2 temporary_file= object=
    local editor=${Z4H_FZF_GIT_EDITOR:-${VISUAL:-${EDITOR:-vi}}}
    local -a editor_command=(${(z)editor})
    local -a editor_invocation
    local invocation_string=
    editor_command=("${(@Q)editor_command}")
    (( $#editor_command )) || return 1

    case $mode in
        file) ;;
        ref)
            object=$(command git rev-parse --verify --end-of-options "$value^{object}" 2>/dev/null) || return 1
            temporary_file=$(mktemp "${${TMPDIR:-/tmp}%/}/fzf-git-ref.XXXXXX") || return 1
            trap 'command rm -f -- "$temporary_file"' EXIT HUP INT TERM
            command git --no-pager show --no-ext-diff --color=never "$object" >| "$temporary_file" || return 1
            target=$temporary_file
            ;;
        *) return 1 ;;
    esac

    editor_invocation=("${editor_command[@]}" -- "$target")
    if (( $+commands[script] )); then
        if [[ $OSTYPE == darwin* ]]; then
            command script -q /dev/null "${editor_invocation[@]}" < /dev/tty > /dev/tty 2> /dev/tty
        else
            invocation_string="${(j: :)${(q)editor_invocation}}"
            command script -q -e -c "$invocation_string" /dev/null < /dev/tty > /dev/tty 2> /dev/tty
        fi
    else
        command "${editor_invocation[@]}" < /dev/tty > /dev/tty 2> /dev/tty
    fi
    local editor_status=$?
    if [[ -n $temporary_file ]]; then
        command rm -f -- "$temporary_file"
        trap - EXIT HUP INT TERM
    fi
    return $editor_status
}

case ${1:-} in
    preview-pager)
        _z4h_fzf_git_preview_pager
        ;;
    edit)
        (( $# == 3 )) || exit 1
        _z4h_fzf_git_edit "$2" "$3"
        ;;
    *) exit 1 ;;
esac
