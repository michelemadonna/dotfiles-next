#!/usr/bin/env zsh
# Generate getopt-style completions explicitly with Shift-TAB.

[[ -n ${GENCOMPL_FPATH:-} ]] || typeset -g GENCOMPL_FPATH="$ZSH_CACHE_DIR/gencomp-on-demand"
fpath+=("$GENCOMPL_FPATH")
typeset -gU fpath

typeset -gA _ZQS_GENCOMP_FAILED

# Completions created by the former automatic mode may still live in z4h's
# standard completion cache and get registered by compinit. Keep the files,
# but detach only RobSis-generated definitions so TAB retains its normal
# fallback and Shift-TAB remains the explicit activation path.
typeset _zqs_gencomp_legacy_file _zqs_gencomp_legacy_program
for _zqs_gencomp_legacy_file in "$ZSH_CACHE_DIR/completions"/_*(N-.); do
  command grep -q \
    'automatically generated with http://github.com/RobSis/zsh-completion-generator' \
    "$_zqs_gencomp_legacy_file" 2>/dev/null || continue
  _zqs_gencomp_legacy_program=${${_zqs_gencomp_legacy_file:t}#_}
  compdef -d "$_zqs_gencomp_legacy_program"
done
unset _zqs_gencomp_legacy_file _zqs_gencomp_legacy_program

_zqs_gencomp_generate() {
  emulate -L zsh
  setopt pipe_fail

  local program=$1
  local help_arg=${2:---help}
  local parser="${Z4H:?}/RobSis/zsh-completion-generator/help2comp.py"
  local python_bin=${commands[python3]:-${commands[python]:-}}
  local output_file="$GENCOMPL_FPATH/_$program"
  local temporary_file="$output_file.tmp.$$"
  local -a pipeline_status

  [[ -n ${commands[$program]:-} ]] || return 127
  [[ -r $parser && -n $python_bin ]] || return 1
  mkdir -p "$GENCOMPL_FPATH" || return

  "$program" "$help_arg" 2>&1 | "$python_bin" "$parser" "$program" >! "$temporary_file" 2>/dev/null
  pipeline_status=("${pipestatus[@]}")
  if (( pipeline_status[2] != 0 )) || [[ ! -s $temporary_file ]]; then
    rm -f "$temporary_file"
    return 1
  fi

  mv -f "$temporary_file" "$output_file" || return
}

gencomp() {
  emulate -L zsh

  if (( $# == 0 )) || [[ $1 == -h || $1 == --help ]]; then
    print -r -- 'Usage: gencomp program [argument-for-help-text]'
    return 1
  fi

  local program=$1
  local help_arg=${2:---help}
  _zqs_gencomp_generate "$program" "$help_arg" || {
    print -u2 -r -- "gencomp: no options found in '$program $help_arg'"
    return 1
  }

  unfunction "_$program" 2>/dev/null
  autoload -Uz "_$program"
  compdef "_$program" "$program"
  print -r -- "Generated completion: $GENCOMPL_FPATH/_$program"
}

_zqs_gencomp_for_current_command() {
  emulate -L zsh
  setopt extended_glob

  local -a command_line=("${(@z)LBUFFER}")
  local program=${command_line[1]:-}
  local completion="_$program"

  if [[ $program == [[:alnum:]_.+-]## &&
        -n ${commands[$program]:-} &&
        -z ${_ZQS_GENCOMP_FAILED[$program]:-} ]]; then
    if [[ -s $GENCOMPL_FPATH/$completion ]] || _zqs_gencomp_generate "$program"; then
      unfunction "$completion" 2>/dev/null
      autoload -Uz "$completion"
      compdef "$completion" "$program"

      # Shift-TAB immediately after the command is an explicit request for
      # generated options, not for the command's positional file argument.
      if (( $#command_line == 1 )); then
        if [[ $LBUFFER == *[[:space:]] ]]; then
          LBUFFER+='--'
        else
          LBUFFER+=' --'
        fi
      fi

      if (( $+widgets[_fzf_tab_complete_with_dots] )); then
        zle _fzf_tab_complete_with_dots
      else
        zle expand-or-complete
      fi
      return 0
    fi
    _ZQS_GENCOMP_FAILED[$program]=1
  fi

  if (( $+widgets[_fzf_tab_complete_with_dots] )); then
    zle _fzf_tab_complete_with_dots
  else
    zle expand-or-complete
  fi
}

zle -N _zqs_gencomp_for_current_command
z4h bindkey _zqs_gencomp_for_current_command Shift+Tab
