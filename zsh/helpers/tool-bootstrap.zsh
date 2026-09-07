# Install selected tools and link their repository configurations on startup.

typeset -gr Z4H_BOOTSTRAP_CYAN=$'\033[36m'
typeset -gr Z4H_BOOTSTRAP_GREEN=$'\033[32m'
typeset -gr Z4H_BOOTSTRAP_RED=$'\033[31m'
typeset -gr Z4H_BOOTSTRAP_BOLD=$'\033[1m'
typeset -gr Z4H_BOOTSTRAP_RESET=$'\033[0m'

z4h_bootstrap_log() {
  local color=$1 icon=$2 title=$3 message=$4
  print -ru2 -- "${color}${Z4H_BOOTSTRAP_BOLD}${icon} ${title}${Z4H_BOOTSTRAP_RESET} ${color}${message}${Z4H_BOOTSTRAP_RESET}"
}

z4h_link_config() {
  local source_path=$1 destination=$2
  [[ -e $source_path ]] || return 0
  command mkdir -p -- "${destination:h}" 2>/dev/null || return 0
  [[ -L $destination && $destination:A == $source_path:A ]] && return 0
  command ln -sfn -- "$source_path" "$destination" 2>/dev/null || true
}

z4h_tool_available() {
  local tool=$1
  (( $+commands[$tool] )) || [[ -x $HOME/.local/bin/$tool ]]
}

z4h_selected_editor_available() {
  local editor=$1 prefix

  if [[ $OSTYPE != darwin* || $editor != (nano|vim) ]]; then
    z4h_tool_available "$editor"
    return
  fi

  if [[ $MACHTYPE == x86_64 && ${DOTFILES_INTEL_PACKAGE_MANAGER:-macports} == macports ]]; then
    prefix=${MACPORTS_PREFIX:-/opt/local}
  elif [[ -n ${HOMEBREW_PREFIX:-} ]]; then
    prefix=$HOMEBREW_PREFIX
  elif [[ $MACHTYPE == x86_64 ]]; then
    prefix=/usr/local
  else
    prefix=/opt/homebrew
  fi

  [[ -x $prefix/bin/$editor ]]
}

z4h_fzf_is_current() {
  local fzf_bin=$HOME/.local/bin/fzf version
  [[ -d $HOME/.local/share/fzf/.git && -x $fzf_bin ]] || return 1
  version=$($fzf_bin --version 2>/dev/null) || return 1
  autoload -Uz is-at-least
  is-at-least 0.66.0 ${version%% *}
}

z4h_bootstrap_tools() {
  local needs_install=false editor_config
  local -a editor_configs

  case $EDITOR in
    micro|fresh|vim|nano)
      editor_config="$DOTFILES_DIR/$EDITOR"
      z4h_selected_editor_available "$EDITOR" || needs_install=true
      [[ -e $editor_config ]] && editor_configs+=("$editor_config:$XDG_CONFIG_HOME/$EDITOR")
      ;;
  esac

  if [[ $Z4H_PROMPT == ohmyposh ]] && ! z4h_tool_available oh-my-posh; then
    needs_install=true
  fi
  if [[ $Z4H_SHOW_FASTFETCH == true || $Z4H_SHOW_FASTFETCH == first ]] &&
    ! z4h_tool_available fastfetch; then
    needs_install=true
  fi
  if [[ $Z4H_USE_MISE == true ]] && ! z4h_tool_available mise; then
    needs_install=true
  fi
  if [[ $Z4H_USE_FZF_FROM_Z4H == false ]] && ! z4h_fzf_is_current; then
    needs_install=true
  fi

  if [[ $needs_install == true && -f $DOTFILES_DIR/install.sh ]]; then
    z4h_bootstrap_log "$Z4H_BOOTSTRAP_CYAN" '●' 'INFO' 'A selected tool is missing; starting non-interactive installation.'
    if command sh "$DOTFILES_DIR/install.sh" non-interactive; then
      z4h_bootstrap_log "$Z4H_BOOTSTRAP_GREEN" '✓' 'DONE' 'Non-interactive installation completed.'
    else
      z4h_bootstrap_log "$Z4H_BOOTSTRAP_RED" '✕' 'ERROR' 'Non-interactive installation failed; continuing Zsh startup.'
    fi
    path=("$HOME/.local/bin" $path)
    typeset -gU path PATH
    rehash
  fi

  z4h_link_config "$DOTFILES_DIR/fastfetch" "$XDG_CONFIG_HOME/fastfetch"
  z4h_link_config "$DOTFILES_DIR/mise" "$XDG_CONFIG_HOME/mise"
  for editor_config in "${editor_configs[@]}"; do
    z4h_link_config "${editor_config%%:*}" "${editor_config#*:}"
  done
}

z4h_bootstrap_tools
unfunction z4h_link_config z4h_tool_available z4h_selected_editor_available \
  z4h_fzf_is_current z4h_bootstrap_tools
