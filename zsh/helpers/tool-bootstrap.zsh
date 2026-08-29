# Install optional tools selected by the generated .zshenv on first interactive startup.

typeset -gr TOOL_BOOTSTRAP_COLOR_CYAN=$'\033[36m'
typeset -gr TOOL_BOOTSTRAP_COLOR_GREEN=$'\033[32m'
typeset -gr TOOL_BOOTSTRAP_COLOR_RED=$'\033[31m'
typeset -gr TOOL_BOOTSTRAP_COLOR_BOLD=$'\033[1m'
typeset -gr TOOL_BOOTSTRAP_COLOR_RESET=$'\033[0m'

tool-bootstrap-info() {
  print -ru2 -- "${TOOL_BOOTSTRAP_COLOR_CYAN}● ${TOOL_BOOTSTRAP_COLOR_BOLD}$*${TOOL_BOOTSTRAP_COLOR_RESET}"
}

tool-bootstrap-success() {
  print -ru2 -- "${TOOL_BOOTSTRAP_COLOR_GREEN}✓ $*${TOOL_BOOTSTRAP_COLOR_RESET}"
}

tool-bootstrap-error() {
  print -ru2 -- "${TOOL_BOOTSTRAP_COLOR_RED}✕ $*${TOOL_BOOTSTRAP_COLOR_RESET}"
}

install-fzf-bootstrap() {
  if [[ ${Z4H_USE_FZF_FROM_Z4H} == false ]]; then
    # Use fzf's official installer independently of Homebrew, APT, and z4h.
    export FZF_LOCAL_REPO="$HOME/.local/share/fzf"
    export FZF_LOCAL_BIN="$HOME/.local/bin/fzf"
    export FZF_PATH="$FZF_LOCAL_REPO"

    if [[ ! -x $FZF_LOCAL_BIN && -n ${commands[git]-} && -n ${commands[bash]-} ]]; then
      tool-bootstrap-info 'Installing the latest fzf release'
      command mkdir -p -- "$HOME/.local/share" "$HOME/.local/bin" 2>/dev/null || true
      if [[ ! -d $FZF_LOCAL_REPO/.git ]]; then
        command git clone --depth=1 https://github.com/junegunn/fzf.git "$FZF_LOCAL_REPO" >/dev/null 2>&1 || true
      fi
      if [[ -d $FZF_LOCAL_REPO/.git ]]; then
        command bash "$FZF_LOCAL_REPO/install" --bin >/dev/null 2>&1 || true
        [[ -x $FZF_LOCAL_REPO/bin/fzf ]] &&
          command cp -- "$FZF_LOCAL_REPO/bin/fzf" "$FZF_LOCAL_BIN" 2>/dev/null || true
      fi
      if [[ -x $FZF_LOCAL_BIN ]]; then
        tool-bootstrap-success 'fzf installed'
      else
        tool-bootstrap-error 'fzf installation failed'
      fi
    fi
  fi
}

install-z4h-tool() {
  local tool=$1
  (( $+commands[$tool] )) && return 0
  tool-bootstrap-info "Installing $tool"
  if [[ $OSTYPE == darwin* && $+commands[brew] -eq 1 ]]; then
    command brew install -y "$tool" >/dev/null 2>&1 || true
  elif [[ $OSTYPE == linux* && $+commands[apt-get] -eq 1 ]]; then
    command sudo -n apt-get install -y "$tool" >/dev/null 2>&1 || true
  fi
  rehash
  if (( $+commands[$tool] )); then
    tool-bootstrap-success "$tool installed"
  else
    tool-bootstrap-error "$tool installation failed"
  fi
}

install-z4h-selected-tools() {
  [[ -o interactive ]] || return 0

  if (( ! $+commands[fd] )); then
    tool-bootstrap-info 'Installing fd'
    if [[ $OSTYPE == darwin* && $+commands[brew] -eq 1 ]]; then
      command brew install -y fd >/dev/null 2>&1 || true
    elif [[ $OSTYPE == linux* ]]; then
      if (( ! $+commands[fdfind] )) && (( $+commands[apt-get] )); then
        command sudo -n apt-get install -y fd-find >/dev/null 2>&1 || true
        rehash
      fi
      if (( $+commands[fdfind] )); then
        command mkdir -p "$HOME/.local/bin"
        command ln -sfn "${commands[fdfind]}" "$HOME/.local/bin/fd"
      fi
    fi
    rehash
    if (( $+commands[fd] )); then
      tool-bootstrap-success 'fd installed'
    else
      tool-bootstrap-error 'fd installation failed'
    fi
  fi

  if [[ ${Z4H_USE_MISE:-true} == true ]] && (( ! $+commands[mise] )); then
    tool-bootstrap-info 'Installing Mise'
    command mkdir -p -- "$HOME/.local/bin" "$XDG_DATA_HOME" 2>/dev/null || true
    if [[ $OSTYPE == darwin* && $+commands[brew] -eq 1 ]]; then
      command brew install -y mise >/dev/null 2>&1 || true
    elif [[ $OSTYPE == linux* && $+commands[curl] -eq 1 ]]; then
      export MISE_INSTALL_PATH="$HOME/.local/bin/mise"
      command curl -fsSL https://mise.run 2>/dev/null |
        command sh >/dev/null 2>&1 || true
    fi
    rehash
    if (( $+commands[mise] )) || [[ -x $HOME/.local/bin/mise ]]; then
      tool-bootstrap-success 'Mise installed'
    else
      tool-bootstrap-error 'Mise installation failed'
    fi
  fi

  case ${EDITOR:-micro} in
    micro|nano|vim) install-z4h-tool "$EDITOR" ;;
    fresh)
      if (( ! $+commands[fresh] )) && [[ ! -x $HOME/.local/bin/fresh ]]; then
        tool-bootstrap-info 'Installing Fresh editor'
        if [[ $OSTYPE == darwin* && $+commands[brew] -eq 1 ]]; then
          command brew install -y fresh-editor >/dev/null 2>&1 || true
        elif [[ $OSTYPE == linux* && $+commands[curl] -eq 1 ]]; then
          command curl -fsSL https://raw.githubusercontent.com/sinelaw/fresh/refs/heads/master/scripts/install.sh 2>/dev/null |
            command sh >/dev/null 2>&1 || true
        fi
        rehash
        if (( $+commands[fresh] )) || [[ -x $HOME/.local/bin/fresh ]]; then
          tool-bootstrap-success 'Fresh editor installed'
        else
          tool-bootstrap-error 'Fresh editor installation failed'
        fi
      fi
      ;;
  esac

  if [[ ${Z4H_SHOW_FASTFETCH:-false} != false ]]; then
    install-z4h-tool fastfetch
  fi

  if [[ ${Z4H_PROMPT:-powerlevel10k} == ohmyposh && ! $+commands[oh-my-posh] ]]; then
    tool-bootstrap-info 'Installing Oh My Posh'
    if [[ $OSTYPE == darwin* && $+commands[brew] -eq 1 ]]; then
      command brew install -y oh-my-posh >/dev/null 2>&1 || true
    elif [[ $OSTYPE == linux* && $+commands[curl] -eq 1 ]]; then
      command mkdir -p "$HOME/.local/bin"
      command curl -fsSL https://ohmyposh.dev/install.sh 2>/dev/null |
        command bash -s -- -d "$HOME/.local/bin" >/dev/null 2>&1 || true
    fi
    rehash
    if (( $+commands[oh-my-posh] )) || [[ -x $HOME/.local/bin/oh-my-posh ]]; then
      tool-bootstrap-success 'Oh My Posh installed'
    else
      tool-bootstrap-error 'Oh My Posh installation failed'
    fi
  fi
}

install-fzf-bootstrap
install-z4h-selected-tools
