# Source this file in an interactive shell entered through the root fhome.sh.
# These checks intentionally exercise the real initialized runtime and loaders.
() {
  [[ -o interactive && ${DOTFILES_FAKE_HOME:-} == $HOME && $PWD == $HOME ]] || {
    print -u2 -- 'Enter root fhome.sh and run this test from its fake HOME.'
    return 1
  }
  local option function_name
  for option in always_to_end auto_cd auto_param_slash auto_pushd c_bases \
      extended_glob extended_history hist_expire_dups_first hist_find_no_dups \
      hist_ignore_dups hist_ignore_space hist_verify interactive_comments multios \
      no_bg_nice no_flow_control no_prompt_bang prompt_cr \
      prompt_percent prompt_sp share_history typeset_silent hist_save_no_dups \
      no_auto_remove_slash no_list_types no_beep glob_dots no_auto_menu \
      complete_in_word pushd_ignore_dups aliases hist_fcntl_lock no_global_rcs; do
    [[ -o $option ]] || { print -u2 -- "Missing option: $option"; return 1; }
  done
  # Powerlevel10k enables prompt_subst after the bootstrap option defaults.
  [[ $DOTSH_PROMPT != powerlevel10k || -o prompt_subst ]] || return 1
  [[ $HISTSIZE == 1000000000 && $SAVEHIST == 1000000000 && $KEYTIMEOUT == 20 ]] || return 1
  # No compatibility commands or variables from a retired namespace are needed.
  (( ! $+functions[dotsh] )) || return 1
  [[ -r $DOTFILES_DIR/zsh/dotsh-startup.zsh &&
     -r $DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-fzf.plugin.zsh ]] || return 1
  [[ $(zsh -dfc 'print -r -- "$ZSH_VERSION:$ZSH_PATCHLEVEL"') == "$ZSH_VERSION:$ZSH_PATCHLEVEL" ]] || {
    print -u2 -- 'Child processes use a different Zsh executable.'
    return 1
  }
  for function_name in -dotsh-zle-line-init -dotsh-zle-line-finish \
      -dotsh-zle-line-pre-redraw -dotsh-autosuggest-fetch -dotsh-compinit; do
    (( $+functions[$function_name] )) || { print -u2 -- "Missing runtime function: $function_name"; return 1; }
    autoload +X -- "$function_name" 2>/dev/null || true
    [[ ${functions[$function_name]} != *'builtin autoload -X'* ]] || return 1
  done
  [[ $HISTFILE == $HOME/.local/state/zsh/history && $DOTSH_CACHE == $HOME/.cache/zsh &&
     $DOTSH_STATE == $HOME/.local/state/zsh && $GITSTATUS_AUTO_INSTALL == 0 ]] || return 1
  [[ $SSH_AUTH_SOCK == $HOME/* ]] || return 1

  if [[ $DOTSH_STARTUP_PROFILE == fast ]]; then
    dotsh_fast_load_zle_features || return 1
    dotsh_fast_load_fzf || return 1
    dotsh_fast_load_gencomp || return 1
  fi
  (( $+functions[compdef] && $+_ZSH_AUTOSUGGEST_BIND_COUNTS && $+FAST_HIGHLIGHT_VERSION )) || return 1
  (( $+functions[_fzf_tab_complete_with_dots] && $+functions[_zqs_gencomp_generate] )) || return 1
  [[ ${_comps[md]:-} == _directories ]] || return 1
  [[ $(bindkey '^[[Z') == *(_zqs_gencomp_for_current_command|_dotsh_fast_gencomp_widget)* ]] || return 1
  [[ $DOTSH_FZF_GIT_ADAPTER == $DOTFILES_DIR/zsh/helpers/fzf-git.zsh ]] || {
    print -u2 -- 'Compiled helper lost its original source path.'
    return 1
  }

  # Confirm wordcode preserves source identity and invalidates changed sources.
  local probe="$HOME/.cache/dotsh-loader-test-$$.zsh" stamp
  print -r -- 'typeset -g DOTSH_TEST_VALUE=first DOTSH_TEST_PATH=${(%):-%x}' > "$probe"
  dotsh_source -c "$probe" || return 1
  [[ $DOTSH_TEST_VALUE == first && $DOTSH_TEST_PATH == $probe ]] || return 1
  print -r -- 'typeset -g DOTSH_TEST_VALUE=second DOTSH_TEST_PATH=${(%):-%x}' > "$probe"
  strftime -s stamp '%Y%m%d%H%M.%S' $((EPOCHSECONDS + 2))
  command touch -t "$stamp" "$probe"
  dotsh_source -c "$probe" || return 1
  [[ $DOTSH_TEST_VALUE == second && $DOTSH_TEST_PATH == $probe ]] || return 1
  command rm -f -- "$probe" "$probe.zwc"
  local readonly_directory="$HOME/.cache/dotsh-readonly-test-$$" load_status
  command mkdir -p "$readonly_directory"
  print -r -- 'typeset -g DOTSH_TEST_VALUE=readonly' > "$readonly_directory/probe.zsh"
  command chmod 500 "$readonly_directory"
  dotsh_source -c "$readonly_directory/probe.zsh"
  load_status=$?
  command chmod 700 "$readonly_directory"
  command rm -rf -- "$readonly_directory"
  [[ $load_status == 0 && $DOTSH_TEST_VALUE == readonly ]] || return 1
  unset DOTSH_TEST_VALUE DOTSH_TEST_PATH
  print -r -- 'Standalone runtime: options, isolation, completion, deferred loaders and wordcode PASS'
}
