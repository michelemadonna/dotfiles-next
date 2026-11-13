# Legacy config-link helper. Installation is explicit; startup does not source this file.

typeset -gr DOTSH_BOOTSTRAP_CYAN=$'\033[36m'
typeset -gr DOTSH_BOOTSTRAP_GREEN=$'\033[32m'
typeset -gr DOTSH_BOOTSTRAP_RED=$'\033[31m'
typeset -gr DOTSH_BOOTSTRAP_BOLD=$'\033[1m'
typeset -gr DOTSH_BOOTSTRAP_RESET=$'\033[0m'

dotsh_bootstrap_log() {
  local color=$1 icon=$2 title=$3 message=$4
  print -ru2 -- "${color}${DOTSH_BOOTSTRAP_BOLD}${icon} ${title}${DOTSH_BOOTSTRAP_RESET} ${color}${message}${DOTSH_BOOTSTRAP_RESET}"
}

dotsh_link_config() {
  local source_path=$1 destination=$2
  [[ -e $source_path ]] || return 0
  [[ -d ${destination:h} ]] || command mkdir -p -- "${destination:h}" 2>/dev/null || return 0
  [[ -L $destination && $destination:A == $source_path:A ]] && return 0
  command ln -sfn -- "$source_path" "$destination" 2>/dev/null || true
}

dotsh_tool_available() {
  local tool=$1
  (( $+commands[$tool] )) || [[ -x $HOME/.local/bin/$tool ]]
}

dotsh_selected_tool_available() {
  local tool=$1 prefix brew_bin

  if [[ $OSTYPE != darwin* ]]; then
    dotsh_tool_available "$tool"
    return
  fi

  prefix=${MACPORTS_PREFIX:-/opt/local}
  [[ -x $prefix/bin/$tool ]] && return 0
  [[ $prefix == /opt/local || ! -x /opt/local/bin/$tool ]] || return 0

  [[ -z ${HOMEBREW_PREFIX:-} || ! -x $HOMEBREW_PREFIX/bin/$tool ]] || return 0
  [[ ! -x /opt/homebrew/bin/$tool ]] || return 0
  [[ ! -x /usr/local/bin/$tool ]] || return 0

  brew_bin=${commands[brew]:-}
  if [[ -n $brew_bin ]]; then
    prefix=$($brew_bin --prefix 2>/dev/null) || prefix=
    [[ -z $prefix || ! -x $prefix/bin/$tool ]] || return 0
  fi
  return 1
}

dotsh_fzf_is_current() {
  local fzf_bin=$HOME/.local/bin/fzf version marker marker_dir
  [[ -d $HOME/.local/share/fzf/.git && -x $fzf_bin ]] || return 1
  marker="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh}/dotfiles-next/fzf-version"
  if [[ ! -s $marker || $fzf_bin -nt $marker ]]; then
    version=$($fzf_bin --version 2>/dev/null) || return 1
    marker_dir=${marker:h}
    if [[ -d $marker_dir ]] || command mkdir -p -- "$marker_dir" 2>/dev/null; then
      print -r -- "${version%% *}" >| "$marker" 2>/dev/null || true
    fi
  else
    version=$(<"$marker")
  fi
  autoload -Uz is-at-least
  is-at-least 0.66.0 "$version"
}

dotsh_bootstrap_tools() {
  local needs_install=false editor_config
  local -a editor_configs

  case $EDITOR in
    micro|fresh|vim|nano)
      editor_config="$DOTFILES_DIR/$EDITOR"
      dotsh_selected_tool_available "$EDITOR" || needs_install=true
      [[ -e $editor_config ]] && editor_configs+=("$editor_config:$XDG_CONFIG_HOME/$EDITOR")
      ;;
  esac

  if [[ $DOTSH_PROMPT == ohmyposh ]] && ! dotsh_selected_tool_available oh-my-posh; then
    needs_install=true
  fi
  if [[ $DOTSH_SHOW_FASTFETCH == true || $DOTSH_SHOW_FASTFETCH == first ]] &&
    ! dotsh_selected_tool_available fastfetch; then
    needs_install=true
  fi
  if [[ $DOTSH_USE_MISE == true ]] && ! dotsh_tool_available mise; then
    needs_install=true
  fi
  if ! dotsh_fzf_is_current; then
    needs_install=true
  fi

  if [[ $needs_install == true ]]; then
    dotsh_bootstrap_log "$DOTSH_BOOTSTRAP_RED" '!' 'MISSING' 'A selected tool is missing; run install.sh explicitly.'
  fi

  dotsh_link_config "$DOTFILES_DIR/fastfetch" "$XDG_CONFIG_HOME/fastfetch"
  dotsh_link_config "$DOTFILES_DIR/mise" "$XDG_CONFIG_HOME/mise"
  for editor_config in "${editor_configs[@]}"; do
    dotsh_link_config "${editor_config%%:*}" "${editor_config#*:}"
  done
}

dotsh_bootstrap_tools
unfunction dotsh_link_config dotsh_tool_available dotsh_selected_tool_available \
  dotsh_fzf_is_current dotsh_bootstrap_tools
