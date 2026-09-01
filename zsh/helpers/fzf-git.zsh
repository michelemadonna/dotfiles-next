#!/usr/bin/env zsh

# fzf-git integration for dotfiles-next. The upstream script is vendored at a
# fixed revision; this adapter owns command-aware TAB completion and the
# compatibility path for the older fzf bundled with z4h.

emulate -L zsh
setopt extended_glob no_aliases

if [[ ${Z4H_FZF_GIT_LOADED:-false} == true ]]; then
    return 0 2>/dev/null || exit 0
fi
typeset -g Z4H_FZF_GIT_LOADED=true

typeset -gr Z4H_FZF_GIT_ADAPTER="${${(%):-%x}:A}"
typeset -gr Z4H_FZF_GIT_ACTION="${Z4H_FZF_GIT_ADAPTER:h}/fzf-git-action.zsh"
typeset -gx Z4H_FZF_GIT_SHELL="${commands[zsh]:-/bin/zsh}"
typeset -gx Z4H_FZF_GIT_ADAPTER_Q="${(q)Z4H_FZF_GIT_ADAPTER}"
typeset -gx Z4H_FZF_GIT_ACTION_Q="${(q)Z4H_FZF_GIT_ACTION}"
typeset -gx Z4H_FZF_GIT_SHELL_Q="${(q)Z4H_FZF_GIT_SHELL}"
typeset -g Z4H_FZF_GIT_FZF=${Z4H_FZF_GIT_FZF:-}
if [[ -n $Z4H_FZF_GIT_FZF && -x $Z4H_FZF_GIT_FZF ]]; then
    :
elif [[ ${Z4H_USE_FZF_FROM_Z4H:-true} == false && -x ${FZF_LOCAL_BIN:-$HOME/.local/bin/fzf} ]]; then
    Z4H_FZF_GIT_FZF=${FZF_LOCAL_BIN:-$HOME/.local/bin/fzf}
elif [[ -x ${FZF_PATH:-}/bin/fzf ]]; then
    Z4H_FZF_GIT_FZF=$FZF_PATH/bin/fzf
else
    Z4H_FZF_GIT_FZF=${commands[fzf]:-}
fi
typeset -g Z4H_FZF_GIT_MODERN=false
typeset -g Z4H_FZF_GIT_UPSTREAM=false
typeset -g Z4H_FZF_GIT_QUERY=${Z4H_FZF_GIT_QUERY:-}

_z4h_fzf_git_version_at_least() {
    emulate -L zsh
    local wanted=$1 version=${2%% *}
    local -a want_parts=(${(s:.:)wanted}) have_parts=(${(s:.:)version})
    local -i index want have

    for index in 1 2 3; do
        want=${want_parts[index]:-0}
        have=${have_parts[index]:-0}
        (( have > want )) && return 0
        (( have < want )) && return 1
    done
    return 0
}

if [[ -n $Z4H_FZF_GIT_FZF ]]; then
    typeset _z4h_fzf_git_version
    _z4h_fzf_git_version=$($Z4H_FZF_GIT_FZF --version 2>/dev/null)
    _z4h_fzf_git_version_at_least 0.38.0 "$_z4h_fzf_git_version" &&
        Z4H_FZF_GIT_MODERN=true
    _z4h_fzf_git_version_at_least 0.66.0 "$_z4h_fzf_git_version" &&
        Z4H_FZF_GIT_UPSTREAM=true
    unset _z4h_fzf_git_version
fi

# Keep the vendored UI intact while making it use the fzf binary selected by
# the installer. This function is deliberately valid in both Zsh and Bash:
# fzf-git.sh exports it to a Bash subprocess for the branch picker.
if [[ $Z4H_FZF_GIT_UPSTREAM == true ]]; then
    if [[ -z ${Z4H_FZF_GIT_TRANSFER_DIR:-} ]]; then
        typeset -gx Z4H_FZF_GIT_TRANSFER_DIR
        Z4H_FZF_GIT_TRANSFER_DIR=$(mktemp -d "${TMPDIR:-/tmp}/z4h-fzf-git-transfer.XXXXXX") || {
            return 1 2>/dev/null || exit 1
        }
        command chmod 700 "$Z4H_FZF_GIT_TRANSFER_DIR"
        typeset -gx Z4H_FZF_GIT_TRANSFER_OWNER=$$
    fi
    export Z4H_FZF_GIT_FZF
    _fzf_git_fzf() {
        local height preview_position preview_window preview_cycle
        local state_command state_helper preview_state_file
        local state_command_q state_helper_q preview_state_file_q ctrl_p_bind

        Z4H_FZF_GIT_EDITOR=${Z4H_FZF_GIT_EDITOR:-${VISUAL:-${EDITOR:-vi}}}
        export Z4H_FZF_GIT_EDITOR

        height=33%
        if [ -r "${FZF_TAB_HEIGHT_STATE_FILE:-}" ]; then
            height=$(cat "$FZF_TAB_HEIGHT_STATE_FILE")
        fi
        case $height in
            33%|50%|66%|99%) ;;
            *) height=33% ;;
        esac

        preview_position=right
        if [ -r "${FZF_TAB_PREVIEW_STATE_FILE:-}" ]; then
            preview_position=$(cat "$FZF_TAB_PREVIEW_STATE_FILE")
        fi
        case $preview_position in
            right)
                preview_window='right:50%:wrap:nohidden'
                preview_cycle='down:50%:wrap:nohidden|down:90%:wrap:nohidden|hidden|right:50%:wrap:nohidden'
                ;;
            down)
                preview_window='down:50%:wrap:nohidden'
                preview_cycle='down:90%:wrap:nohidden|hidden|right:50%:wrap:nohidden|down:50%:wrap:nohidden'
                ;;
            down90)
                preview_window='down:90%:wrap:nohidden'
                preview_cycle='hidden|right:50%:wrap:nohidden|down:50%:wrap:nohidden|down:90%:wrap:nohidden'
                ;;
            hidden)
                preview_window=hidden
                preview_cycle='right:50%:wrap:nohidden|down:50%:wrap:nohidden|down:90%:wrap:nohidden|hidden'
                ;;
            *)
                preview_window='right:50%:wrap:nohidden'
                preview_cycle='down:50%:wrap:nohidden|down:90%:wrap:nohidden|hidden|right:50%:wrap:nohidden'
                ;;
        esac

        state_command=${FZF_TAB_STATE_COMMAND:-zsh}
        state_helper=${FZF_TAB_STATE_HELPER:-${DOTFILES_DIR:-$HOME/.dotfiles}/zsh/helpers/fzf-tab-state-helper}
        preview_state_file=${FZF_TAB_PREVIEW_STATE_FILE:-${XDG_STATE_HOME:-$HOME/.local/state}/zsh/fzf-tab/preview-position}
        printf -v state_command_q %q "$state_command"
        printf -v state_helper_q %q "$state_helper"
        printf -v preview_state_file_q %q "$preview_state_file"
        ctrl_p_bind="ctrl-p:execute-silent(${state_command_q} ${state_helper_q} cycle-preview ${preview_state_file_q})+change-preview-window(${preview_cycle})+refresh-preview"

        command "${Z4H_FZF_GIT_FZF:-fzf}" \
            --layout reverse --multi --min-height 20+ \
            --no-separator --header-border horizontal \
            --border-label-pos 2 \
            --color 'label:blue' \
            --preview-border line \
            --bind 'ctrl-/:change-preview-window(down,50%|hidden|)' \
            "$@" \
            --height "$height" --tmux "90%,${height}" \
            --preview-window "$preview_window" \
            --bind "$ctrl_p_bind"
    }
    typeset -gx __fzf_git_fzf="$(typeset -f _fzf_git_fzf)"
fi

_z4h_fzf_git_cleanup_transfer_dir() {
    local temporary_root=${${TMPDIR:-/tmp}:A}
    local transfer_dir=${${Z4H_FZF_GIT_TRANSFER_DIR:-}:A}
    [[ ${Z4H_FZF_GIT_TRANSFER_OWNER:-} == $$ ]] || return 0
    [[ -n $transfer_dir && -d $transfer_dir ]] || return 0
    [[ $transfer_dir == ${temporary_root%/}/z4h-fzf-git-transfer.* ]] || return 1
    command rm -rf -- "$transfer_dir"
}

if [[ $Z4H_FZF_GIT_UPSTREAM == true && ${Z4H_FZF_GIT_TRANSFER_OWNER:-} == $$ && -o interactive ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook zshexit _z4h_fzf_git_cleanup_transfer_dir
fi

_z4h_fzf_git_check() {
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

_z4h_fzf_git_emit() {
    local type=$1 value=$2 description=${3:-}
    printf '%s\t%s\t%s\0' "$type" "$value" "$description"
}

_z4h_fzf_git_files() {
    local file
    while IFS= read -r -d '' file; do
        _z4h_fzf_git_emit file "$file"
    done < <(command git -c core.quotePath=false ls-files -co --exclude-standard -z)
}

_z4h_fzf_git_branches() {
    local line value description type
    while IFS=$'\t' read -r value description; do
        [[ -n $value ]] || continue
        type=branch
        [[ $value == */* ]] && type=remote-branch
        _z4h_fzf_git_emit "$type" "$value" "$description"
    done < <(command git for-each-ref \
        --sort=-committerdate \
        --format=$'%(refname:short)\t%(subject)' \
        refs/heads refs/remotes 2>/dev/null)
}

_z4h_fzf_git_tags() {
    local line value description
    while IFS=$'\t' read -r value description; do
        [[ -n $value ]] && _z4h_fzf_git_emit tag "$value" "$description"
    done < <(command git for-each-ref \
        --sort=-creatordate \
        --format=$'%(refname:short)\t%(subject)' refs/tags 2>/dev/null)
}

_z4h_fzf_git_remotes() {
    local remote url
    while IFS= read -r remote; do
        [[ -n $remote ]] || continue
        url=$(command git remote get-url "$remote" 2>/dev/null)
        _z4h_fzf_git_emit remote "$remote" "$url"
    done < <(command git remote 2>/dev/null)
}

_z4h_fzf_git_hashes() {
    local line hash description
    while IFS=$'\t' read -r hash description; do
        [[ -n $hash ]] && _z4h_fzf_git_emit commit "$hash" "$description"
    done < <(command git log --all -200 --format=$'%h\t%s' 2>/dev/null)
}

_z4h_fzf_git_stashes() {
    local line value description
    while IFS=$'\t' read -r value description; do
        [[ -n $value ]] && _z4h_fzf_git_emit stash "$value" "$description"
    done < <(command git stash list --format=$'%gd\t%gs' 2>/dev/null)
}

_z4h_fzf_git_reflogs() {
    local line value description
    while IFS=$'\t' read -r value description; do
        [[ -n $value ]] && _z4h_fzf_git_emit reflog "$value" "$description"
    done < <(command git reflog --all --format=$'%gD\t%gs' 2>/dev/null)
}

_z4h_fzf_git_worktrees() {
    local line worktree_path= head= branch=
    while IFS= read -r line; do
        case $line in
            'worktree '*)
                [[ -z $worktree_path ]] || _z4h_fzf_git_emit worktree "$worktree_path" "${branch:-$head}"
                worktree_path=${line#worktree }
                head=
                branch=
                ;;
            'HEAD '*) head=${line#HEAD } ;;
            'branch '*) branch=${${line#branch }#refs/heads/} ;;
            '')
                [[ -z $worktree_path ]] || _z4h_fzf_git_emit worktree "$worktree_path" "${branch:-$head}"
                worktree_path=
                head=
                branch=
                ;;
        esac
    done < <(command git worktree list --porcelain 2>/dev/null)
    [[ -z $worktree_path ]] || _z4h_fzf_git_emit worktree "$worktree_path" "${branch:-$head}"
}

_z4h_fzf_git_refs() {
    local line type value description
    while IFS=$'\t' read -r type value description; do
        [[ -n $value ]] || continue
        case $type in
            refs/heads) type=branch ;;
            refs/remotes) type=remote-branch ;;
            refs/tags) type=tag ;;
            refs/stash) type=stash ;;
            *) type=ref ;;
        esac
        _z4h_fzf_git_emit "$type" "$value" "$description"
    done < <(command git for-each-ref \
        --sort=-creatordate \
        --format=$'%(refname:rstrip=-2)\t%(refname:short)\t%(subject)' 2>/dev/null)
}

_z4h_fzf_git_records() {
    emulate -L zsh
    local mode=$1 allowed=${Z4H_FZF_GIT_ALLOWED:-}
    case $mode in
        files) _z4h_fzf_git_files ;;
        branches) _z4h_fzf_git_branches ;;
        tags) _z4h_fzf_git_tags ;;
        remotes) _z4h_fzf_git_remotes ;;
        hashes) _z4h_fzf_git_hashes ;;
        stashes) _z4h_fzf_git_stashes ;;
        reflogs) _z4h_fzf_git_reflogs ;;
        worktrees) _z4h_fzf_git_worktrees ;;
        refs) _z4h_fzf_git_refs ;;
        all)
            [[ $allowed == *files* ]] && _z4h_fzf_git_files
            if [[ $allowed == *refs* ]]; then
                _z4h_fzf_git_refs
            else
                [[ $allowed == *branches* ]] && _z4h_fzf_git_branches
                [[ $allowed == *tags* ]] && _z4h_fzf_git_tags
                [[ $allowed == *stashes* ]] && _z4h_fzf_git_stashes
            fi
            [[ $allowed == *remotes* ]] && _z4h_fzf_git_remotes
            [[ $allowed == *hashes* ]] && _z4h_fzf_git_hashes
            [[ $allowed == *reflogs* ]] && _z4h_fzf_git_reflogs
            [[ $allowed == *worktrees* ]] && _z4h_fzf_git_worktrees
            ;;
        *) return 1 ;;
    esac
}

_z4h_fzf_git_mode_allowed() {
    [[ ",${Z4H_FZF_GIT_ALLOWED}," == *",$1,"* ]]
}

_z4h_fzf_git_bindings() {
    emulate -L zsh
    [[ $Z4H_FZF_GIT_MODERN == true ]] || return
    local shell=${commands[zsh]:-/bin/zsh}
    local quoted_shell=${(q)shell} quoted_adapter=${(q)Z4H_FZF_GIT_ADAPTER}
    local mode key
    local -a bindings=()
    for mode key in \
        branches alt-b \
        tags alt-t \
        hashes alt-h \
        files alt-f \
        remotes alt-r \
        stashes alt-s \
        reflogs alt-l \
        worktrees alt-w \
        refs alt-e \
        all alt-a; do
        _z4h_fzf_git_mode_allowed "$mode" || continue
        bindings+=("${key}:become($quoted_shell $quoted_adapter --run $mode)")
    done
    (( $#bindings )) && print -rl -- --bind "${(j:,:)bindings}"
}

_z4h_fzf_git_preview() {
    print -r -- '
        type={1}
        value={2}
        case "$type" in
          file)
            git -c core.quotePath=false diff --no-ext-diff --color=always -- "$value"
            if command -v bat >/dev/null 2>&1; then bat --color=always --style=numbers -- "$value"; elif command -v batcat >/dev/null 2>&1; then batcat --color=always --style=numbers -- "$value"; fi
            ;;
          branch|remote-branch|tag|commit|ref|stash|reflog)
            git log --oneline --graph --decorate --color=always -30 "$value" -- 2>/dev/null || git show --color=always --stat "$value" 2>/dev/null
            ;;
          remote)
            git remote show "$value" 2>/dev/null
            ;;
          worktree)
            git -C "$value" -c color.status=always status --short --branch 2>/dev/null
            ;;
        esac
    '
}

_z4h_fzf_git_pick() {
    emulate -L zsh
    setopt pipe_fail
    local mode=${1:-all}
    local label=${mode:u}
    local preview=$(_z4h_fzf_git_preview)
    local -a options=(
        --read0 --print0 --ansi
        --height=70% --layout=reverse --border
        --delimiter=$'\t' --with-nth=1,2,3
        --preview-window=right:55%:wrap
        --preview "$preview"
        --prompt="$label > "
        --header='Alt-B branch · Alt-T tag · Alt-H commit · Alt-F file · Alt-A all · Alt-R remote · Alt-S stash · Alt-L reflog · Alt-W worktree · Alt-E refs'
    )
    [[ ${Z4H_FZF_GIT_MULTI:-false} == true ]] && options+=(--multi)
    if [[ -n ${Z4H_FZF_GIT_FILTER:-} ]]; then
        options+=(--filter="$Z4H_FZF_GIT_FILTER")
    elif [[ -n ${Z4H_FZF_GIT_QUERY:-} ]]; then
        options+=(--query="$Z4H_FZF_GIT_QUERY")
    fi
    if [[ $Z4H_FZF_GIT_MODERN == true ]]; then
        options+=("${(@f)$(_z4h_fzf_git_bindings)}")
    fi
    _z4h_fzf_git_records "$mode" | FZF_DEFAULT_OPTS= command "$Z4H_FZF_GIT_FZF" "${options[@]}"
}

_z4h_fzf_git_pick_to_file() {
    emulate -L zsh
    local mode=$1
    if [[ $Z4H_FZF_GIT_UPSTREAM == true ]]; then
        _z4h_fzf_git_upstream_pick_to_file "$mode"
        return $?
    fi
    REPLY=$(mktemp "${TMPDIR:-/tmp}/z4h-fzf-git.XXXXXX") || return 1
    _z4h_fzf_git_pick "$mode" >| "$REPLY"
    return 0
}

_z4h_fzf_git_upstream_target() {
    emulate -L zsh
    local mode=$1
    if [[ $mode == all ]]; then
        case ${Z4H_FZF_GIT_COMMAND:-} in
            add) mode=files ;;
            checkout|switch|restore|merge|rebase|worktree|fetch|pull|push) mode=refs ;;
            diff) mode=files ;;
            show|log|reset|cherry-pick|revert) mode=hashes ;;
            *) mode=refs ;;
        esac
    fi
    case $mode in
        files) reply=(files file) ;;
        tree_files) reply=(tree_files file) ;;
        branches) reply=(branches branch) ;;
        tags) reply=(tags tag) ;;
        remotes) reply=(remotes remote) ;;
        hashes) reply=(hashes commit) ;;
        stashes) reply=(stashes stash) ;;
        reflogs) reply=(lreflogs reflog) ;;
        worktrees) reply=(worktrees worktree) ;;
        refs) reply=(each_ref ref) ;;
        *) return 1 ;;
    esac
}

_z4h_fzf_git_upstream_type() {
    emulate -L zsh
    local default_type=$1 value=$2
    REPLY=$default_type
    [[ $default_type == branch || $default_type == ref ]] || return 0
    if command git show-ref --verify --quiet "refs/heads/$value"; then
        REPLY=branch
    elif command git show-ref --verify --quiet "refs/tags/$value"; then
        REPLY=tag
    elif command git show-ref --verify --quiet "refs/remotes/$value"; then
        REPLY=remote-branch
    elif [[ $value == [[:xdigit:]]## ]] && command git cat-file -e "$value^{commit}" 2>/dev/null; then
        REPLY=commit
    fi
}

_z4h_fzf_git_type_allowed() {
    emulate -L zsh
    local type=$1 mode
    case $type in
        file) mode=files ;;
        branch|remote-branch) mode=branches ;;
        tag) mode=tags ;;
        commit) mode=hashes ;;
        remote) mode=remotes ;;
        stash)
            [[ -z ${Z4H_FZF_GIT_ALLOWED:-} ||
                ",${Z4H_FZF_GIT_ALLOWED}," == *",stashes,"* ||
                ",${Z4H_FZF_GIT_ALLOWED}," == *",refs,"* ]]
            return
            ;;
        reflog) mode=reflogs ;;
        worktree) mode=worktrees ;;
        ref) mode=refs ;;
        *) return 1 ;;
    esac
    [[ -z ${Z4H_FZF_GIT_ALLOWED:-} || ",${Z4H_FZF_GIT_ALLOWED}," == *",${mode},"* ]]
}

_z4h_fzf_git_extract_token() {
    emulate -L zsh
    local value=$1 token
    [[ $value =~ "([0-9a-f]{40})" ]] || return 1
    token=$match[1]
    [[ -f ${Z4H_FZF_GIT_TRANSFER_DIR:-}/$token ]] || return 1
    REPLY=$token
}

_z4h_fzf_git_forward_token() {
    emulate -L zsh
    local line token
    while IFS= read -r line || [[ -n $line ]]; do
        _z4h_fzf_git_extract_token "$line" || continue
        token=$REPLY
        print -r -- "   $token"
        return 0
    done < "$1"
    return 1
}

_z4h_fzf_git_new_token() {
    emulate -L zsh
    local token
    repeat 10; do
        token=$(command od -An -N20 -tx1 /dev/urandom 2>/dev/null)
        token=${token//[[:space:]]/}
        [[ ${#token} == 40 && ! -e $Z4H_FZF_GIT_TRANSFER_DIR/$token ]] || continue
        REPLY=$token
        return 0
    done
    return 1
}

_z4h_fzf_git_write_transfer() {
    emulate -L zsh
    setopt extended_glob
    local mode=$1 source_file=$2 default_type=$3
    local line type value token transfer_file temporary_file
    local -i records=0

    _z4h_fzf_git_new_token || return 1
    token=$REPLY
    transfer_file=$Z4H_FZF_GIT_TRANSFER_DIR/$token
    temporary_file=$transfer_file.tmp.$$
    : >| "$temporary_file" || return 1
    command chmod 600 "$temporary_file"

    while IFS= read -r line || [[ -n $line ]]; do
        [[ -n $line ]] || continue
        if [[ $mode == each_ref ]]; then
            type=${line%%[[:space:]]*}
            value=${line#$type}
            value=${value##[[:space:]]##}
            value=${value%%[[:space:]]*}
            case $type in
                branch|remote-branch|tag|stash) ;;
                *) type=ref ;;
            esac
        else
            value=${(Q)line}
            type=$default_type
            _z4h_fzf_git_upstream_type "$type" "$value"
            type=$REPLY
        fi
        [[ -n $value ]] || continue
        _z4h_fzf_git_type_allowed "$type" || {
            command rm -f -- "$temporary_file"
            return 2
        }
        printf '%s\t%s\0' "$type" "$value" >> "$temporary_file"
        (( ++records ))
    done < "$source_file"

    (( records )) || {
        command rm -f -- "$temporary_file"
        return 1
    }
    command mv -f -- "$temporary_file" "$transfer_file" || return 1
    print -r -- "   $token"
}

_z4h_fzf_git_treeishes_from_selection() {
    emulate -L zsh
    local line hash
    reply=()
    [[ -r $1 ]] || return 1
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line =~ '([0-9a-f]{7,40})' ]] || continue
        hash=$match[1]
        reply+=("$hash")
    done < "$1"
    (( $#reply ))
}

_z4h_fzf_git_bridge() {
    emulate -L zsh
    local requested_mode=$1 transition=${2:-} selection_file=${3:-}
    local vendor_mode default_type plain_file picker_status=0
    local -a picker_options=() treeishes=()

    _z4h_fzf_git_upstream_target "$requested_mode" || return 1
    vendor_mode=$reply[1]
    default_type=$reply[2]
    [[ $requested_mode != tree_files ]] || {
        _z4h_fzf_git_treeishes_from_selection "$selection_file" || return 1
        treeishes=("${reply[@]}")
    }
    [[ $transition != --transition ]] || Z4H_FZF_GIT_QUERY=
    [[ ${Z4H_FZF_GIT_MULTI:-false} == true ]] || picker_options+=(--no-multi)
    [[ -z ${Z4H_FZF_GIT_QUERY:-} ]] || picker_options+=(--query "$Z4H_FZF_GIT_QUERY")

    plain_file=$(mktemp "${TMPDIR:-/tmp}/z4h-fzf-git-bridge.XXXXXX") || return 1
    if [[ $requested_mode == tree_files ]]; then
        Z4H_FZF_GIT_BRIDGE_CAPTURE=$vendor_mode \
            "$Z4H_FZF_GIT_SHELL" "$DOTFILES_DIR/zsh/vendor/fzf-git.sh" \
            --run "$vendor_mode" "${treeishes[@]}" >| "$plain_file" || picker_status=$?
    else
        Z4H_FZF_GIT_BRIDGE_CAPTURE=$vendor_mode \
            "$Z4H_FZF_GIT_SHELL" "$DOTFILES_DIR/zsh/vendor/fzf-git.sh" \
            --run "$vendor_mode" "${picker_options[@]}" >| "$plain_file" || picker_status=$?
    fi
    if (( picker_status != 0 && picker_status != 1 && picker_status != 130 )); then
        command rm -f -- "$plain_file"
        return $picker_status
    fi
    if _z4h_fzf_git_forward_token "$plain_file"; then
        command rm -f -- "$plain_file"
        return 0
    fi
    _z4h_fzf_git_write_transfer "$vendor_mode" "$plain_file" "$default_type"
    picker_status=$?
    command rm -f -- "$plain_file"
    return $picker_status
}

_z4h_fzf_git_resolve_transfer() {
    emulate -L zsh
    local token=$1 destination=$2 record type
    local transfer_file=$Z4H_FZF_GIT_TRANSFER_DIR/$token
    [[ -f $transfer_file ]] || return 1
    while IFS= read -r -d '' record; do
        type=${record%%$'\t'*}
        _z4h_fzf_git_type_allowed "$type" || {
            command rm -f -- "$transfer_file"
            return 2
        }
        print -rn -- "$record"$'\0' >> "$destination"
    done < "$transfer_file"
    command rm -f -- "$transfer_file"
}

if [[ $Z4H_FZF_GIT_UPSTREAM == true ]]; then
    __fzf_git_join() {
        emulate -L zsh
        local item token transfer_file record value
        while IFS= read -r item; do
            if _z4h_fzf_git_extract_token "$item"; then
                token=$REPLY
                transfer_file=$Z4H_FZF_GIT_TRANSFER_DIR/$token
                while IFS= read -r -d '' record; do
                    value=${record#*$'\t'}
                    value=${value%%$'\t'*}
                    print -rn -- "${(q)value} "
                done < "$transfer_file"
                command rm -f -- "$transfer_file"
            else
                print -rn -- "${(q)${(Q)item}} "
            fi
        done
    }
fi

_z4h_fzf_git_upstream_pick_to_file() {
    emulate -L zsh
    local mode=$1 bridge_mode line token picker_status=0
    local plain_file result_file

    _z4h_fzf_git_upstream_target "$mode" || return 1
    bridge_mode=${reply[1]}
    [[ $bridge_mode != each_ref ]] || bridge_mode=refs

    plain_file=$(mktemp "${TMPDIR:-/tmp}/z4h-fzf-git-upstream.XXXXXX") || return 1
    result_file=$(mktemp "${TMPDIR:-/tmp}/z4h-fzf-git.XXXXXX") || {
        command rm -f -- "$plain_file"
        return 1
    }
    _z4h_fzf_git_bridge "$bridge_mode" >| "$plain_file" || picker_status=$?
    if (( picker_status != 0 && picker_status != 1 && picker_status != 130 )); then
        command rm -f -- "$plain_file" "$result_file"
        return $picker_status
    fi
    while IFS= read -r line || [[ -n $line ]]; do
        _z4h_fzf_git_extract_token "$line" || continue
        token=$REPLY
        _z4h_fzf_git_resolve_transfer "$token" "$result_file" || {
            : >| "$result_file"
            break
        }
    done < "$plain_file"
    command rm -f -- "$plain_file"
    REPLY=$result_file
    return 0
}

_z4h_fzf_git_widget_pick() {
    emulate -L zsh
    local mode=$1
    export Z4H_FZF_GIT_ALLOWED=files,branches,tags,remotes,hashes,stashes,reflogs,worktrees,refs,all
    export Z4H_FZF_GIT_MULTI=false
    export Z4H_FZF_GIT_QUERY=
    local -a selected=()
    local record selection_file
    _z4h_fzf_git_pick_to_file "$mode" || return 0
    selection_file=$REPLY
    while IFS= read -r -d '' record; do
        selected+=("$record")
        break
    done < "$selection_file"
    command rm -f -- "$selection_file"
    zle reset-prompt
    (( $#selected )) || return 0
    local value=${${(ps:\t:)selected[1]}[2]}
    LBUFFER+="${(q)value} "
}

_z4h_fzf_git_register_fallback_widgets() {
    emulate -L zsh
    local mode letter widget keymap
    for mode letter in \
        files f branches b tags t remotes r hashes h stashes s \
        reflogs l worktrees w refs e; do
        widget="_z4h_fzf_git_${mode}_widget"
        zle -N "$widget" _z4h_fzf_git_widget_dispatch
        for keymap in emacs viins vicmd; do
            bindkey -M "$keymap" "^g^${letter}" "$widget"
            bindkey -M "$keymap" "^g${letter}" "$widget"
        done
    done
    zle -N _z4h_fzf_git_help_widget
    for keymap in emacs viins vicmd; do
        bindkey -M "$keymap" '^g?' _z4h_fzf_git_help_widget
    done
}

_z4h_fzf_git_widget_dispatch() {
    local mode=${WIDGET#_z4h_fzf_git_}
    mode=${mode%_widget}
    _z4h_fzf_git_widget_pick "$mode"
}

_z4h_fzf_git_help_widget() {
    zle -M 'Ctrl-G: F files · B branches · T tags · R remotes · H commits · S stashes · L reflogs · W worktrees · E refs'
}

_z4h_fzf_git_prefix_widget() {
    emulate -L zsh
    local key mode widget
    local -x Z4H_FZF_GIT_ALLOWED=files,branches,tags,remotes,hashes,stashes,reflogs,worktrees,refs
    local -x Z4H_FZF_GIT_MULTI=false
    local -x Z4H_FZF_GIT_QUERY=

    zle -M 'Ctrl-G: F files · B branches · T tags · R remotes · H commits · S stashes · L reflogs · W worktrees · E refs'
    zle -R
    IFS= read -rk 1 key || return 0
    case $key in
        f|F|$'\x06') mode=files ;;
        b|B|$'\x02') mode=branches ;;
        t|T|$'\x14') mode=tags ;;
        r|R|$'\x12') mode=remotes ;;
        h|H|$'\x08') mode=hashes ;;
        s|S|$'\x13') mode=stashes ;;
        l|L|$'\x0c') mode=reflogs ;;
        w|W|$'\x17') mode=worktrees ;;
        e|E|$'\x05') mode=refs ;;
        \?|g|G)
            zle -M 'Ctrl-G: F files · B branches · T tags · R remotes · H commits · S stashes · L reflogs · W worktrees · E refs'
            return 0
            ;;
        $'\e') return 0 ;;
        *)
            zle -M "Unknown fzf-git key: ${(q)key}"
            return 0
            ;;
    esac

    if [[ $Z4H_FZF_GIT_UPSTREAM == true ]]; then
        case $mode in
            reflogs) widget=fzf-git-lreflogs-widget ;;
            refs) widget=fzf-git-each_ref-widget ;;
            *) widget="fzf-git-${mode}-widget" ;;
        esac
    else
        widget="_z4h_fzf_git_${mode}_widget"
    fi
    (( $+widgets[$widget] )) || return 0
    zle "$widget"
}

_z4h_fzf_git_register_prefix_widget() {
    emulate -L zsh
    local keymap
    zle -N _z4h_fzf_git_prefix_widget
    for keymap in emacs viins vicmd; do
        bindkey -M "$keymap" '^G' _z4h_fzf_git_prefix_widget
    done
}

_z4h_fzf_git_option_takes_value() {
    local subcommand=$1 option=${2%%=*}
    case "$subcommand:$option" in
        checkout:-b|checkout:-B|checkout:--orphan|checkout:--conflict|checkout:--pathspec-from-file|\
        switch:-c|switch:-C|switch:--create|switch:--force-create|switch:--orphan|\
        restore:-s|restore:--source|restore:--conflict|restore:--pathspec-from-file|\
        add:--pathspec-from-file|diff:--output|diff:--diff-filter|diff:--find-renames|diff:--find-copies|\
        show:--format|show:--pretty|log:--format|log:--pretty|log:--author|log:--committer|log:--grep|\
        merge:-m|merge:--message|merge:--strategy|merge:-X|merge:--strategy-option|\
        rebase:--onto|rebase:--exec|rebase:-X|rebase:--strategy-option|\
        reset:--pathspec-from-file|stash:--pathspec-from-file|\
        branch:-u|branch:--set-upstream-to|branch:--contains|branch:--no-contains|\
        branch:--merged|branch:--no-merged|branch:--points-at|branch:--sort|branch:--format|\
        worktree:-b|worktree:-B|worktree:--reason|worktree:--expire|\
        remote:-t|remote:--track|remote:-m|remote:--master|\
        fetch:--depth|fetch:--deepen|fetch:--shallow-since|fetch:--shallow-exclude|fetch:--upload-pack|\
        pull:--depth|pull:--deepen|pull:--shallow-since|pull:--shallow-exclude|pull:--upload-pack|\
        push:--repo|push:--receive-pack|push:--force-with-lease)
            return 0
            ;;
    esac
    return 1
}

_z4h_fzf_git_set_context() {
    Z4H_FZF_GIT_MODE=$1
    Z4H_FZF_GIT_ALLOWED=$2
    Z4H_FZF_GIT_MULTI=$3
    Z4H_FZF_GIT_POLICY=$4
}

_z4h_fzf_git_context() {
    emulate -L zsh
    setopt extended_glob

    local -a raw_words=(${(z)LBUFFER}) words=() positionals=() command_options=()
    local item current_raw= right_token= raw_query= attached_option=
    for item in "${raw_words[@]}"; do
        words+=("${(Q)item}")
    done

    Z4H_FZF_GIT_BASE_LBUFFER=$LBUFFER
    Z4H_FZF_GIT_RIGHT_REMAINDER=$RBUFFER
    if [[ $LBUFFER != *[[:space:]] ]]; then
        (( $#raw_words )) || return 1
        current_raw=$raw_words[-1]
        raw_words[-1]=()
        words[-1]=()
        local -i base_length=$(( ${#LBUFFER} - ${#current_raw} ))
        if (( base_length )); then
            Z4H_FZF_GIT_BASE_LBUFFER=${LBUFFER[1,base_length]}
        else
            Z4H_FZF_GIT_BASE_LBUFFER=
        fi
        if [[ -n $RBUFFER && $RBUFFER != [[:space:]]* ]]; then
            local -a right_words=(${(z)RBUFFER})
            (( $#right_words )) || return 1
            right_token=$right_words[1]
            current_raw+=$right_token
            local -i right_length=${#right_token}
            if (( right_length < ${#RBUFFER} )); then
                Z4H_FZF_GIT_RIGHT_REMAINDER=${RBUFFER[$(( right_length + 1 )),-1]}
            else
                Z4H_FZF_GIT_RIGHT_REMAINDER=
            fi
        fi
        raw_query=${(Q)current_raw}
    fi
    [[ $current_raw != \'* || $current_raw == *\' ]] || return 1
    [[ $current_raw != \"* || $current_raw == *\" ]] || return 1
    Z4H_FZF_GIT_QUERY=$raw_query

    (( $#words >= 2 )) || return 1
    [[ $words[1] == git ]] || return 1

    local -i index=2 subcommand_index=0
    local arg subcommand=
    while (( index <= $#words )); do
        arg=$words[index]
        case $arg in
            --) (( ++index )) ;;
            -C|-c|--git-dir|--work-tree|--namespace|--config-env) (( index += 2 )) ;;
            -C?*|-c?*|--git-dir=*|--work-tree=*|--namespace=*|--config-env=*|\
            --no-pager|--paginate|--no-replace-objects|--literal-pathspecs|--glob-pathspecs|--noglob-pathspecs|--icase-pathspecs)
                (( ++index ))
                ;;
            -*) (( ++index )) ;;
            *)
                subcommand=$arg
                subcommand_index=$index
                break
                ;;
        esac
    done
    [[ -n $subcommand ]] || return 1
    Z4H_FZF_GIT_COMMAND=$subcommand

    case "$subcommand:$current_raw" in
        branch:--set-upstream-to=*|branch:--contains=*|branch:--no-contains=*|\
        branch:--merged=*|branch:--no-merged=*|branch:--points-at=*)
            attached_option=${current_raw%%=*}
            raw_query=${(Q)${current_raw#*=}}
            Z4H_FZF_GIT_QUERY=$raw_query
            Z4H_FZF_GIT_BASE_LBUFFER+="${current_raw%%=*}="
            current_raw=
            ;;
    esac

    local after_separator=false pending_option=$attached_option source_set=false create_set=false
    for (( index = subcommand_index + 1; index <= $#words; ++index )); do
        arg=$words[index]
        if [[ -n $pending_option ]]; then
            case "$subcommand:${pending_option%%=*}" in
                restore:-s|restore:--source) source_set=true ;;
            esac
            pending_option=
            continue
        fi
        if [[ $after_separator == false && $arg == -- ]]; then
            after_separator=true
            continue
        fi
        if [[ $after_separator == false && $arg == -* ]]; then
            command_options+=("$arg")
            case "$subcommand:${arg%%=*}" in
                restore:-s|restore:--source) [[ $arg == *=* ]] && source_set=true ;;
                checkout:-b|checkout:-B|checkout:--orphan|switch:-c|switch:-C|switch:--create|switch:--force-create|switch:--orphan)
                    create_set=true
                    ;;
            esac
            if [[ $arg != *=* ]] && _z4h_fzf_git_option_takes_value "$subcommand" "$arg"; then
                pending_option=$arg
            fi
            continue
        fi
        positionals+=("$arg")
    done

    if [[ -n $current_raw && $raw_query == -* && $after_separator == false ]]; then
        return 1
    fi
    local joined_options=" ${command_options[*]} "
    case $joined_options in
        *' --continue '*|*' --abort '*|*' --skip '*|*' --quit '*|*' --show-current '*) return 1 ;;
    esac

    local action=${positionals[1]:-}
    case $subcommand in
        branch)
            [[ $after_separator == false ]] || return 1
            case ${pending_option%%=*} in
                -u|--set-upstream-to)
                    _z4h_fzf_git_set_context branches branches false plain
                    return 0
                    ;;
                --contains|--no-contains|--merged|--no-merged|--points-at)
                    _z4h_fzf_git_set_context hashes branches,tags,hashes,refs false plain
                    return 0
                    ;;
                '') ;;
                *) return 1 ;;
            esac
            if [[ $joined_options == *' -d '* || $joined_options == *' -D '* ||
                $joined_options == *' --delete '* ]]; then
                [[ $joined_options != *' -r '* &&
                    $joined_options != *' --remotes '* ]] || return 1
                (( $#positionals == 0 )) || return 1
                _z4h_fzf_git_set_context branches branches true local-branch
            elif [[ $joined_options == *' --edit-description '* ||
                $joined_options == *' --unset-upstream '* ]]; then
                (( $#positionals == 0 )) || return 1
                _z4h_fzf_git_set_context branches branches false local-branch
            elif [[ $joined_options == *' -u '* ||
                $joined_options == *' --set-upstream-to '* ||
                $joined_options == *' --set-upstream-to='* ]]; then
                (( $#positionals == 0 )) || return 1
                _z4h_fzf_git_set_context branches branches false local-branch
            elif [[ $joined_options == *' -m '* || $joined_options == *' -M '* ||
                $joined_options == *' --move '* || $joined_options == *' -c '* ||
                $joined_options == *' -C '* || $joined_options == *' --copy '* ||
                $joined_options == *' -l '* || $joined_options == *' --list '* ]]; then
                return 1
            elif (( $#positionals == 1 )); then
                _z4h_fzf_git_set_context all branches,tags,hashes,refs false plain
            else
                return 1
            fi
            ;;
        checkout)
            [[ -z $pending_option ]] || return 1
            if [[ $after_separator == true ]]; then
                _z4h_fzf_git_set_context files files true path-after
            elif [[ $create_set == true ]]; then
                _z4h_fzf_git_set_context all branches,tags,hashes,refs false plain
            elif (( $#positionals )); then
                _z4h_fzf_git_set_context files files true path
            else
                _z4h_fzf_git_set_context all files,branches,tags,hashes,refs false mixed
            fi
            ;;
        switch)
            [[ -z $pending_option ]] || return 1
            _z4h_fzf_git_set_context all branches,tags,hashes,refs false switch
            ;;
        restore)
            if [[ ${pending_option%%=*} == -s || ${pending_option%%=*} == --source ]]; then
                _z4h_fzf_git_set_context all branches,tags,hashes,refs false plain
            elif [[ -n $pending_option ]]; then
                return 1
            elif [[ $after_separator == true ]]; then
                _z4h_fzf_git_set_context files files true path-after
            elif [[ $source_set == true ]]; then
                _z4h_fzf_git_set_context files files true path
            else
                _z4h_fzf_git_set_context all files,branches,tags,hashes,refs false restore
            fi
            ;;
        add)
            [[ -z $pending_option ]] || return 1
            if [[ $after_separator == true ]]; then
                _z4h_fzf_git_set_context files files true path-after
            else
                _z4h_fzf_git_set_context files files true path
            fi
            ;;
        diff)
            [[ -z $pending_option ]] || return 1
            if [[ $after_separator == true ]]; then
                _z4h_fzf_git_set_context files files true path-after
            else
                _z4h_fzf_git_set_context all files,branches,tags,hashes,refs false mixed
            fi
            ;;
        show|log)
            [[ -z $pending_option ]] || return 1
            if [[ $after_separator == true ]]; then
                _z4h_fzf_git_set_context files files true path-after
            else
                _z4h_fzf_git_set_context all branches,tags,hashes,refs false plain
            fi
            ;;
        reset)
            [[ -z $pending_option ]] || return 1
            if [[ $after_separator == true ]]; then
                _z4h_fzf_git_set_context files files true path-after
            elif (( $#positionals )); then
                _z4h_fzf_git_set_context files files true path
            else
                _z4h_fzf_git_set_context all files,branches,tags,hashes,refs false mixed
            fi
            ;;
        merge|rebase|cherry-pick|revert)
            [[ -z $pending_option ]] || return 1
            _z4h_fzf_git_set_context all branches,tags,hashes,refs false plain
            ;;
        stash)
            [[ -z $pending_option ]] || return 1
            case $action in
                apply|pop|drop|show)
                    (( $#positionals == 1 )) || return 1
                    _z4h_fzf_git_set_context stashes stashes false plain
                    ;;
                branch)
                    (( $#positionals == 2 )) || return 1
                    _z4h_fzf_git_set_context stashes stashes false plain
                    ;;
                push|save)
                    if [[ $after_separator == true ]]; then
                        _z4h_fzf_git_set_context files files true path-after
                    else
                        _z4h_fzf_git_set_context files files true path
                    fi
                    ;;
                *) return 1 ;;
            esac
            ;;
        worktree)
            [[ -z $pending_option ]] || return 1
            case $action in
                add)
                    (( $#positionals == 2 )) || return 1
                    [[ $joined_options != *' --orphan '* ]] || return 1
                    _z4h_fzf_git_set_context all branches,tags,hashes,refs false plain
                    ;;
                remove|lock|unlock|move)
                    (( $#positionals == 1 )) || return 1
                    _z4h_fzf_git_set_context worktrees worktrees false plain
                    ;;
                *) return 1 ;;
            esac
            ;;
        remote)
            [[ -z $pending_option ]] || return 1
            case $action in
                get-url|remove|rm|prune|show|set-head|set-branches|set-url|rename)
                    (( $#positionals == 1 )) || return 1
                    _z4h_fzf_git_set_context remotes remotes false plain
                    ;;
                update)
                    _z4h_fzf_git_set_context remotes remotes true plain
                    ;;
                *) return 1 ;;
            esac
            ;;
        fetch|pull|push)
            [[ -z $pending_option ]] || return 1
            if [[ $joined_options == *' --multiple '* ]]; then
                _z4h_fzf_git_set_context remotes remotes true plain
            elif (( $#positionals == 0 )); then
                _z4h_fzf_git_set_context remotes remotes false plain
            elif [[ $joined_options == *' --all '* || $joined_options == *' --mirror '* ]]; then
                return 1
            else
                _z4h_fzf_git_set_context all branches,tags,refs false plain
            fi
            ;;
        *) return 1 ;;
    esac
}

_z4h_fzf_git_complete() {
    emulate -L zsh
    setopt extended_glob
    _z4h_fzf_git_context || return 1
    _z4h_fzf_git_check || return 1
    [[ -n $Z4H_FZF_GIT_FZF ]] || return 1

    local original_lbuffer=$LBUFFER
    local original_rbuffer=$RBUFFER
    local base_lbuffer=$Z4H_FZF_GIT_BASE_LBUFFER
    local context_allowed=$Z4H_FZF_GIT_ALLOWED
    local context_multi=$Z4H_FZF_GIT_MULTI
    local context_query=$Z4H_FZF_GIT_QUERY
    local -x Z4H_FZF_GIT_ALLOWED=$context_allowed
    local -x Z4H_FZF_GIT_MULTI=$context_multi
    local -x Z4H_FZF_GIT_QUERY=$context_query

    local -a selected=()
    local record selection_file
    _z4h_fzf_git_pick_to_file "$Z4H_FZF_GIT_MODE" || return 1
    selection_file=$REPLY
    while IFS= read -r -d '' record; do
        selected+=("$record")
        [[ $Z4H_FZF_GIT_MULTI == true ]] || break
    done < "$selection_file"
    command rm -f -- "$selection_file"
    zle reset-prompt
    (( $#selected )) || {
        LBUFFER=$original_lbuffer
        RBUFFER=$original_rbuffer
        return 0
    }

    local -a insertions=()
    local type value
    for record in "${selected[@]}"; do
        local -a fields=(${(ps:\t:)record})
        type=$fields[1]
        value=$fields[2]
        [[ -n $value ]] || continue
        if [[ $Z4H_FZF_GIT_POLICY == restore && $type != file ]]; then
            insertions+=("--source=${(q)value}")
            export Z4H_FZF_GIT_ALLOWED=files
            export Z4H_FZF_GIT_MULTI=true
            export Z4H_FZF_GIT_QUERY=
            local -a restore_files=()
            local file_record restore_selection_file
            _z4h_fzf_git_pick_to_file files || {
                LBUFFER=$original_lbuffer
                RBUFFER=$original_rbuffer
                return 0
            }
            restore_selection_file=$REPLY
            while IFS= read -r -d '' file_record; do
                local -a file_fields=(${(ps:\t:)file_record})
                [[ -n $file_fields[2] ]] && restore_files+=("${(q)file_fields[2]}")
            done < "$restore_selection_file"
            command rm -f -- "$restore_selection_file"
            (( $#restore_files )) || {
                LBUFFER=$original_lbuffer
                RBUFFER=$original_rbuffer
                return 0
            }
            insertions+=(-- "${restore_files[@]}")
            break
        elif [[ $type == file ]]; then
            insertions+=("${(q)value}")
        elif [[ $Z4H_FZF_GIT_POLICY == local-branch && $type != branch ]]; then
            LBUFFER=$original_lbuffer
            RBUFFER=$original_rbuffer
            return 0
        elif [[ $Z4H_FZF_GIT_POLICY == switch && $type != branch ]]; then
            insertions+=(--detach "${(q)value}")
        else
            insertions+=("${(q)value}")
        fi
    done
    (( $#insertions )) || {
        LBUFFER=$original_lbuffer
        RBUFFER=$original_rbuffer
        return 0
    }

    if [[ $type == file && ( $Z4H_FZF_GIT_POLICY == path || $Z4H_FZF_GIT_POLICY == mixed || $Z4H_FZF_GIT_POLICY == restore ) ]]; then
        insertions=(-- "${insertions[@]}")
    fi
    LBUFFER="${base_lbuffer}${(j: :)insertions}"
    RBUFFER=$Z4H_FZF_GIT_RIGHT_REMAINDER
    zle redisplay
    return 0
}

if [[ $Z4H_FZF_GIT_UPSTREAM != true ]]; then
    _z4h_fzf_git_register_fallback_widgets
fi
_z4h_fzf_git_register_prefix_widget

if [[ ${ZSH_EVAL_CONTEXT:-} == toplevel ]]; then
    case ${1:-} in
        --bridge)
            shift
            _z4h_fzf_git_bridge "${1:-refs}" "${2:-}" "${3:-}"
            exit $?
            ;;
        --run)
            shift
            _z4h_fzf_git_pick "${1:-all}"
            exit $?
            ;;
        --records)
            shift
            _z4h_fzf_git_records "${1:-all}"
            exit $?
            ;;
    esac
fi
