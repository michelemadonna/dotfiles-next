#!/usr/bin/env zsh
#This file is sourced by zshrc to set up fzf integration.
#includes private functions for toggling hidden files, setting default commands, and configuring fzf options.
(( ! $+commands[fzf] )) && return

# ============================================================
# fzf-tab configuration
# ============================================================
#
# Dependencies
# ============================================================
#
# macOS:
#
#   brew install \
#       fzf \
#       bat \
#       eza \
#       chafa \
#       mediainfo \
#       poppler \
#       tree \
#       file \
#       bind
#
# Ubuntu / Debian / Kali:
#
#   sudo apt update
#
#   sudo apt install \
#       fzf \
#       bat \
#       eza \
#       chafa \
#       mediainfo \
#       poppler-utils \
#       tree \
#       file \
#       dnsutils
#
# ------------------------------------------------------------
#
# Load order:
#
#   1. compinit
#   2. fzf-tab
#   3. this configuration
#   4. autosuggestions / syntax highlighting
#
# fzf-tab must already be loaded when this file is sourced.
#
# ============================================================

# ============================================================
# Paths
# ============================================================

typeset -g FZF_TAB_PREVIEW_COMMAND="$DOTFILES_DIR/zsh/fzf-tab-preview-helper"
typeset -g FZF_TAB_STATE_COMMAND="${commands[zsh]:-/bin/zsh}"
typeset -g FZF_TAB_STATE_HELPER="$DOTFILES_DIR/zsh/fzf-tab-state-helper"
typeset -g FZF_TAB_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/fzf-tab"
typeset -gx FZF_TAB_PREVIEW_STATE_FILE="$FZF_TAB_STATE_DIR/preview-position"
typeset -gx FZF_TAB_HEIGHT_STATE_FILE="$FZF_TAB_STATE_DIR/height"
typeset -g FZF_TAB_HIDDEN_STATE_FILE="$FZF_TAB_STATE_DIR/show-hidden"
typeset -g FZF_TAB_HIDDEN_MARKER="${TMPDIR:-/tmp}/fzf-tab-hidden-${$}"

mkdir -p -- "$FZF_TAB_STATE_DIR" 2>/dev/null || return
rm -f -- "$FZF_TAB_HIDDEN_MARKER"

__fzf_default_command() {
    emulate -L zsh

    local hidden_state=''
    local FD_HIDDEN_FLAG=''
    local FIND_HIDDEN_EXPR=''
    [[ -r $FZF_TAB_HIDDEN_STATE_FILE ]] &&
        hidden_state=$(<"$FZF_TAB_HIDDEN_STATE_FILE")

    if [[ $hidden_state == on ]]; then
        setopt globdots
        FD_HIDDEN_FLAG='--hidden'
        FIND_HIDDEN_EXPR="-name '.*' -prune -o"
    else
        unsetopt globdots
    fi

    if (( $+commands[fd] )); then
        print -r -- \
            "fd --type f --follow ${FD_HIDDEN_FLAG} --exclude '.git' --exclude 'node_modules' 2>/dev/null"
    elif [[ -n $FIND_HIDDEN_EXPR ]]; then
        print -r -- \
            "find . \\( -path '*/.git/*' -o -path '*/node_modules/*' \\) -prune -o -type f -print"
    else
        print -r -- \
            "find . -type f ! -path '*/.git/*' ! -path '*/node_modules/*' ! -name '.*'"
    fi
}

export FZF_DEFAULT_COMMAND="$(__fzf_default_command)"

# ============================================================
# Base completion
# ============================================================

zstyle ':completion:*:descriptions' \
    format '[%d]'

zstyle ':completion:*' \
    menu no

# Hidden files are OFF by default and persisted across shells.
typeset -g FZF_TAB_SHOW_HIDDEN=0

_fzf_tab_apply_hidden_state() {
    local hidden_state=''
    [[ -r $FZF_TAB_HIDDEN_STATE_FILE ]] &&
        hidden_state=$(<"$FZF_TAB_HIDDEN_STATE_FILE")

    if [[ $hidden_state == on ]]; then
        FZF_TAB_SHOW_HIDDEN=1
        setopt globdots
        zstyle ':completion:*' \
            file-patterns '*(D):all-files'
        zstyle ':completion:*:cd:*' \
            file-patterns \
            '*(-/):directories .*(-/):hidden-directories'
    else
        FZF_TAB_SHOW_HIDDEN=0
        unsetopt globdots
        [[ $hidden_state == off ]] ||
            print -r -- off >| "$FZF_TAB_HIDDEN_STATE_FILE"
        zstyle -d ':completion:*' \
            file-patterns
        zstyle -d ':completion:*:cd:*' \
            file-patterns
        # For cd, offer hidden directories only as a fallback. This lets
        # fzf-tab open when the current directory contains no visible
        # directories, while keeping hidden entries out of the normal list.
        zstyle ':completion:*:cd:*' \
            file-patterns \
            '*(-/):directories' \
            '.*(D-/):hidden-directories'
    fi
}

_fzf_tab_apply_hidden_state

# Keep the native _cd completion and supplement its first argument with
# hidden directories discovered by fd. fzf-tab still receives candidates
# through compsys/compadd instead of falling back to plain fzf.
autoload +X -Uz _cd
if (( ! $+functions[_fzf_tab_original_cd] )); then
    functions[_fzf_tab_original_cd]=$functions[_cd]
fi

_fzf_tab_cd() {
    emulate -L zsh

    _fzf_tab_original_cd "$@"
    local completion_status=$?
    local hidden_state=''
    local -a hidden_directories=()

    [[ -r $FZF_TAB_HIDDEN_STATE_FILE ]] &&
        hidden_state=$(<"$FZF_TAB_HIDDEN_STATE_FILE")

    if [[ $hidden_state == on && CURRENT -eq 2 && $PREFIX != */* ]] &&
        (( $+commands[fd] )); then
        hidden_directories=(
            "${(@f)$(command fd \
                --type d \
                --follow \
                --hidden \
                --max-depth 1 \
                --strip-cwd-prefix \
                --exclude '.git' \
                --exclude 'node_modules' \
                . 2>/dev/null)}"
        )
        hidden_directories=("${(@M)hidden_directories:#.*}")
        if (( $#hidden_directories )); then
            _wanted hidden-directories expl 'hidden directory' \
                compadd -Qf -W "$PWD" -a hidden_directories
            completion_status=0
        fi
    fi

    return completion_status
}

compdef _fzf_tab_cd cd

if [[ -n "${LS_COLORS:-}" ]]; then

    zstyle ':completion:*' \
        list-colors ${(s.:.)LS_COLORS}

fi

# ============================================================
# fzf-tab UI
# ============================================================

zstyle ':fzf-tab:*' \
    switch-group '<' '>'

zstyle ':fzf-tab:*' \
    use-fzf-default-opts no

# fzf exports FZF_PREVIEW_COLUMNS and FZF_PREVIEW_LINES with
# the actual dimensions of the preview window. This is used
# by fzf-tab-preview for image sizing.
#
# See:
# https://github.com/junegunn/fzf
#
# ============================================================

_fzf_preview_layout() {
    emulate -L zsh

    local preview_position=''
    [[ -r $FZF_TAB_PREVIEW_STATE_FILE ]] &&
        preview_position=$(<"$FZF_TAB_PREVIEW_STATE_FILE")

    case $preview_position in
        right)
            reply=('right:60%:wrap:nohidden' 'down:50%:wrap:nohidden|hidden|right:60%:wrap:nohidden')
            ;;
        down)
            reply=('down:50%:wrap:nohidden' 'hidden|right:60%:wrap:nohidden|down:50%:wrap:nohidden')
            ;;
        hidden)
            reply=('hidden' 'right:60%:wrap:nohidden|down:50%:wrap:nohidden|hidden')
            ;;
        *)
            reply=('right:60%:wrap:nohidden' 'down:50%:wrap:nohidden|hidden|right:60%:wrap:nohidden')
            print -r -- right >| "$FZF_TAB_PREVIEW_STATE_FILE"
            ;;
    esac
}

_fzf_height() {
    emulate -L zsh
    local height=''
    [[ -r $FZF_TAB_HEIGHT_STATE_FILE ]] && height=$(<"$FZF_TAB_HEIGHT_STATE_FILE")
    case $height in
        33%|50%|66%|99%) reply=($height) ;;
        *) reply=(33%) ; print -r -- 33% >| "$FZF_TAB_HEIGHT_STATE_FILE" ;;
    esac
}

_fzf_tab_refresh_flags() {
    emulate -L zsh

    _fzf_preview_layout
    local preview_window=$reply[1]
    local preview_cycle=$reply[2]
    _fzf_height
    local fzf_height=$reply[1]
    local hidden_marker_q="${(q)FZF_TAB_HIDDEN_MARKER}"
    local hidden_state_q="${(q)FZF_TAB_HIDDEN_STATE_FILE}"
    local preview_state_q="${(q)FZF_TAB_PREVIEW_STATE_FILE}"
    local state_command_q="${(q)FZF_TAB_STATE_COMMAND}"
    local state_helper_q="${(q)FZF_TAB_STATE_HELPER}"

    zstyle ':fzf-tab:*' \
        fzf-flags \
            "--height=${fzf_height}" \
            --layout=reverse \
            --border \
            --info=inline \
            "--header=TAB/SHIFT-TAB move  ·  </> group  ·  CTRL-A mark all  ·  CTRL-J/K preview scroll  ·  CTRL-P preview  ·  CTRL-H hidden  ·  ENTER select  ·  ESC close" \
            "--preview-window=${preview_window}" \
            --bind=ctrl-a:toggle-all,ctrl-j:preview-down,ctrl-k:preview-up \
            "--bind=ctrl-p:execute-silent(${state_command_q} ${state_helper_q} cycle-preview ${preview_state_q})+change-preview-window(${preview_cycle})" \
            "--bind=ctrl-h:execute-silent(${state_command_q} ${state_helper_q} toggle-hidden ${hidden_state_q} ${hidden_marker_q})+abort"
}

_fzf_tab_refresh_flags

typeset _fzf_state_command_q="${(q)FZF_TAB_STATE_COMMAND}"
typeset _fzf_state_helper_q="${(q)FZF_TAB_STATE_HELPER}"
typeset _fzf_hidden_state_file_q="${(q)FZF_TAB_HIDDEN_STATE_FILE}"
typeset _fzf_toggle_hidden_command="${_fzf_state_command_q} ${_fzf_state_helper_q} toggle-hidden ${_fzf_hidden_state_file_q}"
typeset _fzf_list_files_command="${_fzf_state_command_q} ${_fzf_state_helper_q} list-files ${_fzf_hidden_state_file_q}"
typeset _fzf_list_directories_command="${_fzf_state_command_q} ${_fzf_state_helper_q} list-directories ${_fzf_hidden_state_file_q}"

export FZF_CTRL_T_COMMAND="$_fzf_list_files_command"
export FZF_ALT_C_COMMAND="$_fzf_list_directories_command"

_fzf_widget_refresh_flags() {
    emulate -L zsh

    _fzf_preview_layout
    local preview_window=$reply[1]
    local preview_cycle=$reply[2]
    local preview_state_q="${(q)FZF_TAB_PREVIEW_STATE_FILE}"
    local hidden_state_q="${(q)FZF_TAB_HIDDEN_STATE_FILE}"
    local state_command_q="${(q)FZF_TAB_STATE_COMMAND}"
    local state_helper_q="${(q)FZF_TAB_STATE_HELPER}"
    local toggle_hidden_command="${state_command_q} ${state_helper_q} toggle-hidden ${hidden_state_q}"
    local list_files_command="${state_command_q} ${state_helper_q} list-files ${hidden_state_q}"
    local list_directories_command="${state_command_q} ${state_helper_q} list-directories ${hidden_state_q}"
    _fzf_height
    local fzf_height=$reply[1]

    export FZF_CTRL_T_OPTS="--height=${fzf_height} --header='TAB/SHIFT-TAB move  ·  CTRL-SPACE select  ·  CTRL-A mark all  ·  CTRL-J/K preview scroll  ·  CTRL-P preview  ·  CTRL-H hidden  ·  ENTER insert  ·  ESC close' --preview '$FZF_TAB_PREVIEW_COMMAND {}' --preview-window=${preview_window} --bind='ctrl-a:toggle-all,ctrl-j:preview-down,ctrl-k:preview-up,ctrl-p:execute-silent(${state_command_q} ${state_helper_q} cycle-preview ${preview_state_q})+change-preview-window(${preview_cycle}),ctrl-h:execute-silent(${toggle_hidden_command})+reload(${list_files_command})'"
    export FZF_ALT_C_OPTS="--height=${fzf_height} --header='TAB/SHIFT-TAB move  ·  CTRL-J/K preview scroll  ·  CTRL-P preview  ·  CTRL-H hidden  ·  ENTER cd  ·  ESC close' --preview '$FZF_TAB_PREVIEW_COMMAND {}' --preview-window=${preview_window} --bind='ctrl-j:preview-down,ctrl-k:preview-up,ctrl-p:execute-silent(${state_command_q} ${state_helper_q} cycle-preview ${preview_cycle})+change-preview-window(${preview_cycle}),ctrl-h:execute-silent(${toggle_hidden_command})+reload(${list_directories_command})'"
}

_z4h_fzf_file_widget() {
    _fzf_widget_refresh_flags
    fzf-file-widget
    local widget_status=$?
    _fzf_widget_refresh_flags
    return widget_status
}

_z4h_fzf_cd_widget() {
    _fzf_widget_refresh_flags
    fzf-cd-widget
    local widget_status=$?
    _fzf_widget_refresh_flags
    return widget_status
}

_fzf_cycle_height() {
    emulate -L zsh
    _fzf_height
    case $reply[1] in
        33%) reply=(50%) ;;
        50%) reply=(66%) ;;
        66%) reply=(99%) ;;
        *) reply=(33%) ;;
    esac
    print -r -- "$reply[1]" >| "$FZF_TAB_HEIGHT_STATE_FILE"
    _fzf_tab_refresh_flags
    _fzf_widget_refresh_flags
    zle -M "🔎 fzf  ·  Height ${reply[1]}"
}

_fzf_widget_refresh_flags
zle -N _z4h_fzf_file_widget
zle -N _z4h_fzf_cd_widget
zle -N _fzf_cycle_height
bindkey -M emacs '^T' _z4h_fzf_file_widget
bindkey -M viins '^T' _z4h_fzf_file_widget
bindkey -M emacs '^[c' _z4h_fzf_cd_widget
bindkey -M viins '^[c' _z4h_fzf_cd_widget
bindkey -M emacs '^F' _fzf_cycle_height
bindkey -M viins '^F' _fzf_cycle_height

unset _fzf_state_command_q _fzf_state_helper_q _fzf_hidden_state_file_q
unset _fzf_toggle_hidden_command _fzf_list_files_command _fzf_list_directories_command

# ============================================================
# Ctrl-H hidden file toggle outside fzf
# ============================================================
#
# Ctrl-H:
#
#   hidden OFF -> hidden ON
#   hidden ON  -> hidden OFF
#
# The next TAB completion is generated with the updated state.
#
# ============================================================

_fzf_tab_complete_with_dots() {

    emulate -L zsh

    rm -f -- "$FZF_TAB_HIDDEN_MARKER"
    _fzf_tab_apply_hidden_state
    _fzf_tab_refresh_flags

    # Give immediate feedback while compsys is producing candidates.
    # Keep this inside the final fzf-tab widget so TAB doesn't bypass it.
    print -nP -- '%F{red}..%f'
    zle fzf-tab-complete
    zle redisplay
    _fzf_widget_refresh_flags

    [[ -e $FZF_TAB_HIDDEN_MARKER ]] || return

    rm -f -- "$FZF_TAB_HIDDEN_MARKER"
    _fzf_tab_apply_hidden_state
    export FZF_DEFAULT_COMMAND="$(__fzf_default_command)"

    # Re-enter completion on the next ZLE event so compsys and fd generate
    # a fresh candidate list instead of reusing the aborted menu.
    zle -U $'\t'
}

_fzf_tab_toggle_hidden() {
    emulate -L zsh
    "$FZF_TAB_STATE_COMMAND" \
        "$FZF_TAB_STATE_HELPER" \
        toggle-hidden \
        "$FZF_TAB_HIDDEN_STATE_FILE" || return
    _fzf_tab_apply_hidden_state
    export FZF_DEFAULT_COMMAND="$(__fzf_default_command)"
    if (( FZF_TAB_SHOW_HIDDEN )); then
        zle -M '🙉 Hidden files visible'
    else
        zle -M '🙈 Hidden files hidden'
    fi
}

zle -N \
    _fzf_tab_complete_with_dots

zle -N \
    _fzf_tab_toggle_hidden

bindkey -M emacs \
    '^I' \
    _fzf_tab_complete_with_dots

bindkey -M viins \
    '^I' \
    _fzf_tab_complete_with_dots

bindkey -M emacs \
    '^H' \
    _fzf_tab_toggle_hidden

bindkey -M viins \
    '^H' \
    _fzf_tab_toggle_hidden

bindkey -M emacs \
    '^H' \
    _fzf_tab_toggle_hidden

bindkey -M viins \
    '^H' \
    _fzf_tab_toggle_hidden

# ============================================================
# Generic filesystem preview
# ============================================================

zstyle ':fzf-tab:complete:*:*' \
    fzf-preview \
    "$FZF_TAB_PREVIEW_COMMAND \"\$realpath\""

# Never attempt a filesystem preview for options.
zstyle ':fzf-tab:complete:*:options' \
    fzf-preview ''

# Docker completions select commands, options, containers and images rather
# than filesystem paths. Keep the fzf list but never open a preview pane.
zstyle ':fzf-tab:complete:docker:*' \
    fzf-preview ''

zstyle ':fzf-tab:complete:docker(|-container)-(attach|commit|cp|diff|exec|export|inspect|kill|logs|pause|port|rename|restart|rm|start|stats|stop|top|unpause|update|wait):*' \
    fzf-preview '
        docker container inspect \
            --format "Name:       {{.Name}}
Status:     {{.State.Status}}
Image:      {{.Config.Image}}
Command:    {{json .Config.Cmd}}
Created:    {{.Created}}
Started:    {{.State.StartedAt}}
Network:    {{.HostConfig.NetworkMode}}
{{range \$name, \$net := .NetworkSettings.Networks}}IP ({{\$name}}): {{if \$net.IPAddress}}{{\$net.IPAddress}}{{else}}-{{end}}
{{end}}Ports:      {{json .NetworkSettings.Ports}}
Mounts:{{if .Mounts}}{{range .Mounts}}
  {{.Source}} -> {{.Destination}} ({{.Mode}}){{end}}{{else}} none{{end}}" \
            -- "$word" \
            2>/dev/null
    '

# ============================================================
# cd / pushd
# ============================================================

zstyle ':fzf-tab:complete:(cd|pushd):*' \
    fzf-preview \
    "$FZF_TAB_PREVIEW_COMMAND \"\$realpath\""

# ============================================================
# Homebrew
# ============================================================

if (( $+commands[brew] )); then

    # Do not open a preview while selecting a brew command or option.
    zstyle ':fzf-tab:complete:brew:*' \
        fzf-preview ''

    # Preview only arguments of actions that select formulae or casks.
    zstyle ':fzf-tab:complete:brew-(audit|bottle|bump-cask-pr|bump-formula-pr|bump-revision|cache|cat|cleanup|deps|desc|edit|extract|fetch|formula|gist-logs|home|info|install|link|linkage|livecheck|log|migrate|missing|options|pin|postinstall|reinstall|remove|rm|source|style|tab|test|uninstall|unlink|unpack|unpin|upgrade|uses|version-install|vulns):*' \
        fzf-preview '
            case "$group" in

                *[Cc]ask*)

                    brew info \
                        --cask \
                        -- "$word" \
                        2>/dev/null
                    ;;

                *[Ff]ormula*)

                    brew info \
                        --formula \
                        -- "$word" \
                        2>/dev/null
                    ;;

                *)
                    ;;

            esac
        '

fi

# ============================================================
# APT
# ============================================================
#
# apt install <TAB>
#   -> repository metadata + policy
#
# apt remove / purge <TAB>
#   -> installed package metadata + candidate versions
#
# ============================================================

if (( $+commands[apt] )); then

    zstyle ':fzf-tab:complete:apt:*' \
        fzf-preview '
            case "${words[2]:-}" in

                install)

                    print -P "%BPackage%b: $word"
                    print

                    apt-cache \
                        policy \
                        -- "$word" \
                        2>/dev/null

                    print
                    print -P "%BInformation%b"
                    print

                    apt-cache \
                        show \
                        --no-all-versions \
                        -- "$word" \
                        2>/dev/null
                    ;;

                remove|purge)

                    print -P "%BInstalled package%b"
                    print

                    dpkg-query \
                        -W \
                        -f="Package: \${Package}\nVersion: \${Version}\nArchitecture: \${Architecture}\nStatus: \${Status}\n\n\${Description}\n" \
                        "$word" \
                        2>/dev/null

                    print
                    print -P "%BAPT policy%b"
                    print

                    apt-cache \
                        policy \
                        -- "$word" \
                        2>/dev/null
                    ;;

                reinstall)

                    apt-cache \
                        policy \
                        -- "$word" \
                        2>/dev/null

                    print

                    apt-cache \
                        show \
                        --no-all-versions \
                        -- "$word" \
                        2>/dev/null
                    ;;

                show)

                    apt-cache \
                        show \
                        -- "$word" \
                        2>/dev/null
                    ;;

                *)

                    apt-cache \
                        show \
                        --no-all-versions \
                        -- "$word" \
                        2>/dev/null
                    ;;

            esac
        '

fi

# ============================================================
# Git
# ============================================================

if (( $+commands[git] )); then

    # Do not open a preview while selecting a git command or option.
    zstyle ':fzf-tab:complete:git:*' \
        fzf-preview ''

    # Git completion passes changed paths through _multi_parts. Expand the
    # suffix so fzf receives complete file paths instead of parent folders.
    zstyle ':completion:*:git-*:*' \
        expand suffix

    zstyle ':completion:*:git-checkout:*' \
        sort false

    zstyle ':completion:*:git-switch:*' \
        sort false

    # --------------------------------------------------------
    # checkout / switch / merge / rebase
    # --------------------------------------------------------

    zstyle ':fzf-tab:complete:git-(checkout|switch|merge|rebase):*' \
        fzf-preview '
            git log \
                --color=always \
                --graph \
                --decorate \
                --date=short \
                --max-count=30 \
                --pretty=format:"%C(auto)%h%C(reset) %C(blue)%ad%C(reset) %C(auto)%d%C(reset) %s %C(dim white)- %an%C(reset)" \
                -- "$word" \
                2>/dev/null
        '

    # --------------------------------------------------------
    # git add
    # --------------------------------------------------------

    zstyle ':fzf-tab:complete:git-add:*' \
        fzf-preview '
            preview_path="$realpath"

            [[ -n "$preview_path" ]] ||
                preview_path="$word"

            if git ls-files \
                --error-unmatch \
                -- "$preview_path" \
                &>/dev/null
            then

                diff_output="$(
                    git diff \
                        --color=always \
                        -- "$preview_path" \
                        2>/dev/null
                )"

                if [[ -z "$diff_output" ]]; then

                    diff_output="$(
                        git diff \
                            --cached \
                            --color=always \
                            -- "$preview_path" \
                            2>/dev/null
                    )"

                fi

                if [[ -r "$FZF_TAB_PREVIEW_STATE_FILE" ]] &&
                    [[ "$(<"$FZF_TAB_PREVIEW_STATE_FILE")" == down ]] &&
                    (( $+commands[delta] )); then
                    print -r -- "$diff_output" |
                        delta \
                            --side-by-side \
                            --paging=never \
                            --width="${FZF_PREVIEW_COLUMNS:-120}"
                else
                    print -r -- "$diff_output"
                fi

            else

                '"${(q)FZF_TAB_PREVIEW_COMMAND}"' \
                    "$preview_path"

            fi
        '

    # --------------------------------------------------------
    # git diff / restore
    # --------------------------------------------------------

    zstyle ':fzf-tab:complete:git-(diff|restore):*' \
        fzf-preview '
            if [[ -r "$FZF_TAB_PREVIEW_STATE_FILE" ]] &&
                [[ "$(<"$FZF_TAB_PREVIEW_STATE_FILE")" == down ]] &&
                (( $+commands[delta] )); then
                git diff \
                    --color=always \
                    -- "$word" \
                    2>/dev/null |
                    delta \
                        --side-by-side \
                        --paging=never \
                        --width="${FZF_PREVIEW_COLUMNS:-120}"
            else
                git diff \
                    --color=always \
                    -- "$word" \
                    2>/dev/null
            fi
        '

    # --------------------------------------------------------
    # git show / log
    # --------------------------------------------------------

    zstyle ':fzf-tab:complete:git-(show|log):*' \
        fzf-preview '
            git show \
                --color=always \
                --decorate \
                --stat \
                "$word" \
                2>/dev/null
        '

    # --------------------------------------------------------
    # git remote
    # --------------------------------------------------------

    zstyle ':fzf-tab:complete:git-(fetch|pull|push):*' \
        fzf-preview '
            git remote \
                get-url \
                "$word" \
                2>/dev/null

            print

            git remote \
                show \
                "$word" \
                2>/dev/null
        '

fi

# ============================================================
# Processes
# ============================================================

zstyle ':completion:*:*:*:*:processes' \
    command \
    'ps -u $USER -o pid,user,%cpu,%mem,etime,command -ww'

zstyle ':fzf-tab:complete:(kill|ps):argument-rest' \
    fzf-preview '
        if [[ "$word" == <-> ]]; then

            ps \
                -p "$word" \
                -o pid,ppid,user,%cpu,%mem,etime,lstart,command \
                -ww \
                2>/dev/null

        fi
    '

zstyle ':fzf-tab:complete:(pkill|killall):*' \
    fzf-preview '
        pgrep \
            -fl \
            -- "$word" \
            2>/dev/null
    '

# ============================================================
# SSH / SCP / SFTP
# ============================================================

zstyle ':fzf-tab:complete:(ssh|scp|sftp):*' \
    fzf-preview '
        host="${word%%:*}"
        host="${host##*@}"

        print -P "%BHost%b: $host"
        print

        if [[ -r ~/.ssh/config ]]; then

            awk \
                -v host="$host" '\''
                    BEGIN {
                        IGNORECASE = 1
                        found = 0
                    }

                    /^[[:space:]]*Host[[:space:]]+/ {

                        if (found)
                            exit

                        for (i = 2; i <= NF; i++) {

                            if ($i == host) {
                                found = 1
                                print
                                break
                            }

                        }

                        next
                    }

                    found {
                        print
                    }
                '\'' \
                ~/.ssh/config

        fi

        if (( $+commands[dig] )); then

            print
            print "DNS:"

            dig \
                +short \
                "$host" \
                2>/dev/null

        fi
    '

# ============================================================
# man
# ============================================================

zstyle ':fzf-tab:complete:man:*' \
    fzf-preview '
        MANWIDTH="${FZF_PREVIEW_COLUMNS:-90}" \
            man "$word" \
            2>/dev/null |
            col -bx |
            head -n 300
    '

# ============================================================
# Environment variables
# ============================================================

zstyle ':fzf-tab:complete:*:parameters' \
    fzf-preview '
        name="${word#\$}"

        printf \
            "%s=%s\n" \
            "$name" \
            "${(P)name}"
    '

# ============================================================
# Commands
# ============================================================

zstyle ':fzf-tab:complete:*:commands' \
    fzf-preview ''

# ============================================================
# systemd
# ============================================================

if [[ "$OSTYPE" == linux* ]] &&
   (( $+commands[systemctl] ))
then

    zstyle ':fzf-tab:complete:systemctl-*:*' \
        fzf-preview '
            SYSTEMD_COLORS=1 \
                systemctl \
                    status \
                    "$word" \
                    --no-pager \
                    --full \
                    2>/dev/null
        '

    zstyle ':fzf-tab:complete:journalctl:*' \
        fzf-preview '
            SYSTEMD_COLORS=1 \
                journalctl \
                    -u "$word" \
                    --no-pager \
                    -n 100 \
                    2>/dev/null
        '

fi

#fzf_tab_no_space_after_at() {
#  if (( CURSOR == ${#BUFFER} )) && [[ $BUFFER == *'@'*' ' ]]; then
#    zle backward-delete-char
#  fi
#  fzf-tab-complete
#}
#
#fzf-git-update() {
#  mkdir -p "$HOME/.fzf"
#  command curl -fsSL https://raw.githubusercontent.com/junegunn/fzf-git.sh/master/fzf-git.sh \
#    -o "$HOME/.fzf/fzf-git.sh"
#}
#[[ -r "$DOTF/.fzf/fzf-git.sh" ]] && source "$HOME/.fzf/fzf-git.sh"
