# Eza icons shared by file/directory pickers and fzf-tab's display adapter.

# Return absolute-path/icon pairs in reply. Missing or unrenderable paths are
# omitted so callers can retain the original candidate without decoration.
dotsh_fzf_icon_map() {
    emulate -L zsh
    reply=()
    [[ ${DOTSH_USE_FZF:-true} == true ]] && (( $+commands[eza] )) || return 0
    (( $# )) || return 0

    local filename rendered rendered_path icon output
    local -aU filenames=()
    local -A requested=()
    for filename in "$@"; do
        filenames+=("${filename:a}")
        requested[${filename:a}]=1
    done
    # -X agrees with the pickers' --follow behavior and suppresses link arrows.
    # Consume whatever eza could render if a candidate disappeared meanwhile.
    output=$(print -rl -- "${filenames[@]}" |
        EZA_ICON_SPACING=1 command eza --stdin -1d -X --icons=always \
            --color=never --hyperlink=never --no-quotes --sort=none 2>/dev/null)
    for rendered in "${(@f)output}"; do
        [[ $rendered == *' /'* ]] || continue
        rendered_path=/${rendered#*' /'}
        [[ -n ${requested[$rendered_path]-} ]] || continue
        icon=${rendered%%' /'*}
        [[ -n $icon ]] || continue
        reply+=("$rendered_path" "$icon ")
    done
    return 0
}

# Input stays line-oriented, matching the existing fd/find picker interface.
# NUL separates the raw path from its icon, so tabs/spaces remain path data.
dotsh_fzf_icon_records() {
    emulate -L zsh
    local filename
    local -a filenames=() reply
    while IFS= read -r filename || [[ -n $filename ]]; do
        filenames+=("$filename")
    done
    dotsh_fzf_icon_map "${filenames[@]}"
    local -A icons=("${reply[@]}")
    for filename in "${filenames[@]}"; do
        # Keep a terminator on each field when fzf reorders them for display.
        print -r -- "$filename"$'\0'"${icons[${filename:a}]-}"$'\0'
    done
}

dotsh_fzf_decorate_completions() {
    emulate -L zsh
    [[ ${DOTSH_USE_FZF:-true} == true ]] && (( $+commands[eza] )) || return 0
    local captured description filename row remainder icon
    local -i index
    local -A metadata=() candidate_paths=()
    for captured in "${_ftb_compcap[@]}"; do
        description=${captured%%$'\2'*}
        metadata=("${(@0)${captured#*$'\2'}}")
        [[ -n ${metadata[realdir]+present} ]] || continue
        [[ -n ${candidate_paths[$description]-} ]] && continue
        filename=${metadata[realdir]}${(Q)metadata[word]}
        candidate_paths[$description]=${filename:a}
    done
    local -a reply
    dotsh_fzf_icon_map "${(@v)candidate_paths}"
    local -A icons=("${reply[@]}")
    for (( index = 1; index <= $#_ftb_complist; index++ )); do
        row=$_ftb_complist[index]
        remainder=${row#*$'\0'}
        description=${remainder%%$'\0'*}
        filename=${candidate_paths[$description]-}
        [[ -n $filename ]] || continue
        icon=${icons[$filename]-}
        [[ -n $icon ]] || continue
        # Append inside the first field, retaining the leading group SGR and
        # both original completion fields for preview and acceptance parsing.
        _ftb_complist[index]=${row%%$'\0'*}$icon$'\0'$remainder
    done
    return 0
}

dotsh_fzf_setup_icons() {
    emulate -L zsh
    [[ ${DOTSH_USE_FZF:-true} == true ]] || return 0
    (( $+functions[-dotsh-ftb-generate-complist] )) && return 0
    if (( ! $+functions[-ftb-generate-complist] )) ||
        [[ $functions[-ftb-generate-complist] == *'builtin autoload -X'* ]]; then
        autoload +X -Uz -- -ftb-generate-complist || return
    fi
    functions[-dotsh-ftb-generate-complist]=$functions[-ftb-generate-complist]
    function -ftb-generate-complist() {
        -dotsh-ftb-generate-complist "$@"
        local generator_status=$?
        dotsh_fzf_decorate_completions
        return $generator_status
    }
}
