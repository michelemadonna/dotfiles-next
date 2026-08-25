#!/bin/sh

set -eu

# Set this after creating the repository, or pass DOTFILES_REPO_URL at runtime.
DEFAULT_REPO_URL="https://github.com/michelemadonna/dotfiles-next.git"
REPO_URL=${DOTFILES_REPO_URL:-$DEFAULT_REPO_URL}
DOTFILES_DIR=${DOTFILES_DIR:-"$HOME/.dotfiles"}
MODE=interactive
BASE_PACKAGES_MARKER_VERSION=1

COLOR_YELLOW=
COLOR_GREEN=
COLOR_RED=
COLOR_BOLD=
COLOR_DIM=
COLOR_RESET=

if [ -z "${NO_COLOR:-}" ] && [ "${TERM:-dumb}" != dumb ] && [ -t 1 ]; then
  COLOR_YELLOW=$(printf '\033[33m')
  COLOR_GREEN=$(printf '\033[32m')
  COLOR_RED=$(printf '\033[31m')
  COLOR_BOLD=$(printf '\033[1m')
  COLOR_DIM=$(printf '\033[2m')
  COLOR_RESET=$(printf '\033[0m')
fi

usage() {
  printf '%sUsage:%s %s%s%s [non-interactive|--non-interactive]\n' \
    "$COLOR_BOLD" "$COLOR_RESET" "$COLOR_BOLD" "$0" "$COLOR_RESET"
}

parse_arguments() {
  case $# in
    0) ;;
    1)
      case $1 in
        non-interactive | --non-interactive) MODE=non-interactive ;;
        *) usage >&2; die "Unsupported argument: $1" ;;
      esac
      ;;
    *) usage >&2; die 'Too many arguments.' ;;
  esac
}

is_non_interactive() {
  [ "$MODE" = non-interactive ]
}

info() {
  printf '\n%s==>%s %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*"
}

success() {
  printf '\n%s==>%s %s%s%s\n' \
    "$COLOR_GREEN" "$COLOR_RESET" "$COLOR_BOLD" "$*" "$COLOR_RESET"
}

die() {
  printf '\n%s%sError:%s %s\n' \
    "$COLOR_RED" "$COLOR_BOLD" "$COLOR_RESET" "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  elif is_non_interactive; then
    sudo -n "$@"
  else
    sudo "$@"
  fi
}

run_apt_get() {
  if is_non_interactive; then
    run_as_root env DEBIAN_FRONTEND=noninteractive apt-get "$@"
  else
    run_as_root apt-get "$@"
  fi
}

confirm() {
  prompt=$1

  if [ ! -r /dev/tty ]; then
    info "No terminal available: skipping optional component '$prompt'."
    return 1
  fi

  while :; do
    printf '%s?%s Install %s%s%s? %s[y/N]%s ' \
      "$COLOR_YELLOW" "$COLOR_RESET" "$COLOR_BOLD" "$prompt" \
      "$COLOR_RESET" "$COLOR_GREEN" "$COLOR_RESET" >/dev/tty
    IFS= read -r answer </dev/tty || return 1
    case $answer in
      y | Y | yes | YES | Yes) return 0 ;;
      '' | n | N | no | NO | No) return 1 ;;
      *) printf '%sPlease answer y or n.%s\n' \
        "$COLOR_RED" "$COLOR_RESET" >/dev/tty ;;
    esac
  done
}

ask_choice() {
  prompt=$1
  default=$2
  choices=$3

  if [ ! -r /dev/tty ]; then
    die "A terminal is required to configure $prompt."
  fi

  while :; do
    printf '%s?%s %s%s%s [%s%s%s] %s(%s)%s ' \
      "$COLOR_YELLOW" "$COLOR_RESET" "$COLOR_BOLD" "$prompt" \
      "$COLOR_RESET" "$COLOR_GREEN" "$default" "$COLOR_RESET" \
      "$COLOR_DIM" "$choices" "$COLOR_RESET" >/dev/tty
    IFS= read -r answer </dev/tty || die "Could not read the value for $prompt."
    answer=${answer:-$default}
    case " $choices " in
      *" $answer "*) printf '%s\n' "$answer"; return 0 ;;
      *) printf '%sPlease choose one of:%s %s%s%s.\n' \
        "$COLOR_RED" "$COLOR_RESET" "$COLOR_BOLD" "$choices" \
        "$COLOR_RESET" >/dev/tty ;;
    esac
  done
}

backup_if_needed() {
  destination=$1
  source=$2

  if [ -L "$destination" ]; then
    current=$(readlink "$destination" 2>/dev/null || true)
    [ "$current" = "$source" ] && return 0
    return 0
  fi

  if [ -e "$destination" ]; then
    backup="${destination}.backup.$(date +%Y%m%d%H%M%S)"
    info "Backing up $destination to $backup"
    mv "$destination" "$backup"
  fi
}

link_path() {
  source=$1
  destination=$2

  [ -e "$source" ] || die "Cannot link missing repository path: $source"
  backup_if_needed "$destination" "$source"
  ln -sfn "$source" "$destination"
}

check_prerequisites() {
  [ -n "${HOME:-}" ] || die 'HOME is not set.'
  have zsh || die 'Zsh must already be installed.'

  login_shell=${SHELL:-}
  [ "${login_shell##*/}" = zsh ] ||
    die "Zsh must be the login shell for the current user (current: ${login_shell:-unknown})."

  have curl || die 'curl is required.'

}

setup_platform() {
  case $(uname -s) in
    Darwin)
      PLATFORM=macos
      if ! have brew; then
        info 'Installing Homebrew'
        have bash || die 'bash is required to install Homebrew.'
        if is_non_interactive; then
          NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        else
          /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
      fi

      if ! have brew; then
        if [ -x /opt/homebrew/bin/brew ]; then
          eval "$(/opt/homebrew/bin/brew shellenv)"
        elif [ -x /usr/local/bin/brew ]; then
          eval "$(/usr/local/bin/brew shellenv)"
        else
          die 'Homebrew was installed but cannot be found.'
        fi
      fi
      ;;
    Linux)
      PLATFORM=linux
      have apt-get || die 'This installer supports only apt-based Linux distributions.'
      if [ "$(id -u)" -ne 0 ]; then
        have sudo || die 'sudo is required for system package installation.'
      fi
      ;;
    *)
      die "Unsupported operating system: $(uname -s)"
      ;;
  esac
}

install_git() {
  have git && return 0

  info 'Installing Git'
  if [ "$PLATFORM" = macos ]; then
    brew install git
  else
    run_apt_get update
    run_apt_get install -y git
  fi
  have git || die 'Git installation failed.'
}

clone_repository() {
  case $REPO_URL in
    '' | REPLACE_WITH_REPOSITORY_URL)
      die 'Set DEFAULT_REPO_URL in install.sh after creating the repository.'
      ;;
  esac

  if [ -d "$DOTFILES_DIR/.git" ]; then
    info "Using existing repository at $DOTFILES_DIR"
    return 0
  fi

  [ ! -e "$DOTFILES_DIR" ] ||
    die "$DOTFILES_DIR already exists and is not a Git repository."

  info "Cloning dotfiles into $DOTFILES_DIR"
  git clone "$REPO_URL" "$DOTFILES_DIR"
}

install_required_packages() {
  info 'Installing required packages'
  if [ "$PLATFORM" = macos ]; then
    brew install coreutils bat eza fd git-delta htop ripgrep stow tmux tree wget git chafa mediainfo poppler file bind
    brew install --cask font-fira-code-nerd-font
  else
    run_apt_get update
    run_apt_get install -y \
      bat eza chafa mediainfo poppler-utils tree file dnsutils fd-find wget \
      stow grc ripgrep python3-pip command-not-found git-delta tmux htop

    mkdir -p "$HOME/.fonts"
    cp "$DOTFILES_DIR"/fonts/* "$HOME/.fonts/"
    have fc-cache || die 'fc-cache is required to install the bundled fonts.'
    fc-cache -f
  fi
}

install_required_packages_once() {
  state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
  marker_dir="$state_home/dotfiles-next"
  base_packages_marker="$marker_dir/base-packages-v${BASE_PACKAGES_MARKER_VERSION}-${PLATFORM}.done"

  if [ -f "$base_packages_marker" ]; then
    info "Required packages already installed; found $base_packages_marker"
    return 0
  fi

  install_required_packages || return 1
  mkdir -p "$marker_dir"
  : >"$base_packages_marker"
  info "Recorded required package installation in $base_packages_marker"
}

install_base_links() {
  zshenv_source=$1

  info 'Creating configuration links'
  mkdir -p "$HOME/.config" "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  link_path "$zshenv_source" "$HOME/.zshenv"
  link_path "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
  link_path "$DOTFILES_DIR/tmux" "$HOME/.config/tmux"
  link_path "$DOTFILES_DIR/ripgrep" "$HOME/.config/ripgrep"
}

configure_zshenv() {
  info 'Configuring Zsh preferences'
  prompt=$(ask_choice 'Prompt' 'powerlevel10k' 'powerlevel10k ohmyposh')
  editor=$(ask_choice 'Default editor' 'micro' 'vim nano fresh micro')
  show_fastfetch=$(ask_choice 'Show Fastfetch' 'false' 'false true')
  use_fzf_tab=$(ask_choice 'Use fzf-tab' 'true' 'true false')
  enable_auto_gencomp=$(ask_choice 'Enable automatic completions' 'true' 'true false')
  enable_oh_my_zsh=$(ask_choice 'Enable Oh My Zsh' 'true' 'true false')
  load_ssh_key=$(ask_choice 'Load SSH keys' 'true' 'true false')

  if [ "$load_ssh_key" = true ]; then
    show_ssh_key=$(ask_choice 'Show SSH keys' 'true' 'true false')
    askpass_require=$(ask_choice 'Require SSH askpass' 'false' 'false true')
  else
    show_ssh_key=true
    askpass_require=false
  fi

  source_file="$DOTFILES_DIR/zsh/.zshenv.init"
  generated_file="$DOTFILES_DIR/zsh/.zshenv"
  [ -f "$source_file" ] || die "Missing Zsh template: $source_file"

  awk \
    -v prompt="$prompt" \
    -v editor="$editor" \
    -v show_fastfetch="$show_fastfetch" \
    -v use_fzf_tab="$use_fzf_tab" \
    -v enable_auto_gencomp="$enable_auto_gencomp" \
    -v enable_oh_my_zsh="$enable_oh_my_zsh" \
    -v load_ssh_key="$load_ssh_key" \
    -v show_ssh_key="$show_ssh_key" \
    -v askpass_require="$askpass_require" '
      /^  export Z4H_PROMPT=/ { $0 = "  export Z4H_PROMPT=\"" prompt "\""; }
      /^  export Z4H_SHOW_FASTFETCH=/ { $0 = "  export Z4H_SHOW_FASTFETCH=" show_fastfetch; }
      /^  export Z4H_USE_FZF_TAB=/ { $0 = "  export Z4H_USE_FZF_TAB=" use_fzf_tab; }
      /^  export Z4H_ENABLE_AUTO_GENCOMP=/ { $0 = "  export Z4H_ENABLE_AUTO_GENCOMP=" enable_auto_gencomp; }
      /^  export Z4H_ENABLE_OH_MY_ZSH=/ { $0 = "  export Z4H_ENABLE_OH_MY_ZSH=" enable_oh_my_zsh; }
      /^  export Z4H_SSH_LOAD_KEY=/ { $0 = "  export Z4H_SSH_LOAD_KEY=" load_ssh_key; }
      /^  export Z4H_SSH_SHOW_KEY=/ { $0 = "  export Z4H_SSH_SHOW_KEY=" show_ssh_key; }
      /^  export Z4H_SSH_ASKPASS_REQUIRE=/ { $0 = "  export Z4H_SSH_ASKPASS_REQUIRE=" askpass_require; }
      /^  export EDITOR=/ { $0 = "  export EDITOR=\"" editor "\""; }
      { print }
    ' "$source_file" >| "$generated_file"
}

configure_non_interactive() {
  prompt=${Z4H_PROMPT:-powerlevel10k}
  show_fastfetch=${Z4H_SHOW_FASTFETCH:-false}
  editor=${EDITOR:-micro}

  case $prompt in
    powerlevel10k | ohmyposh) ;;
    *) die "Unsupported Z4H_PROMPT value: $prompt" ;;
  esac

  case $show_fastfetch in
    true | false) ;;
    *) die "Unsupported Z4H_SHOW_FASTFETCH value: $show_fastfetch" ;;
  esac

  case $editor in
    vim | nano | fresh | micro) ;;
    *)
      info "Unsupported EDITOR value '$editor'; using micro."
      editor=micro
      ;;
  esac
}

install_editor() {
  case $editor in
    vim)
      if [ "$PLATFORM" = macos ]; then
        brew install vim
      else
        run_apt_get install -y vim
      fi
      ;;
    nano)
      if [ "$PLATFORM" = macos ]; then
        brew install nano
      else
        run_apt_get install -y nano
      fi
      ;;
    fresh) install_fresh ;;
    micro) install_micro ;;
  esac
}

install_micro() {
  if [ "$PLATFORM" = macos ]; then
    brew install micro
  else
    run_apt_get install -y micro
  fi
  link_path "$DOTFILES_DIR/micro" "$HOME/.config/micro"
}

install_fresh() {
  if [ "$PLATFORM" = macos ]; then
    brew install fresh-editor
  else
    architecture=$(dpkg --print-architecture)
    download_url=$(
      curl -fsSL https://api.github.com/repos/sinelaw/fresh/releases/latest |
        grep 'browser_download_url' |
        grep "_${architecture}\.deb" |
        head -n 1 |
        cut -d '"' -f 4
    ) || true
    [ -n "$download_url" ] || die "No Fresh package found for $architecture."
    package_file="${TMPDIR:-/tmp}/fresh-editor.$$.deb"
    trap 'rm -f "${package_file:-}"' EXIT HUP INT TERM
    curl -fsSL "$download_url" -o "$package_file"
    run_apt_get install -y "$package_file"
    rm -f "$package_file"
    trap - EXIT HUP INT TERM
  fi
  link_path "$DOTFILES_DIR/fresh" "$HOME/.config/fresh"
}

install_mise() {
  if [ "$PLATFORM" = macos ]; then
    brew install mise
  else
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://mise.run | sh
  fi
  link_path "$DOTFILES_DIR/mise" "$HOME/.config/mise"
  info 'Preparing Mise shell caches'
  sh "$DOTFILES_DIR/zsh/prepare-mise-cache.sh"
}

install_fastfetch() {
  if [ "$PLATFORM" = macos ]; then
    brew install fastfetch
  else
    run_apt_get install -y fastfetch
  fi
  link_path "$DOTFILES_DIR/fastfetch" "$HOME/.config/fastfetch"
}

install_oh_my_posh() {
  if [ "$PLATFORM" = macos ]; then
    brew install oh-my-posh
  else
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
  fi
  link_path "$DOTFILES_DIR/oh-my-posh" "$HOME/.config/oh-my-posh"
}

main() {
  parse_arguments "$@"
  check_prerequisites
  setup_platform
  install_git
  clone_repository
  install_required_packages_once

  if is_non_interactive; then
    configure_non_interactive
    zshenv_source="$DOTFILES_DIR/zsh/.zshenv.init"
  else
    configure_zshenv
    zshenv_source="$DOTFILES_DIR/zsh/.zshenv"
  fi

  install_base_links "$zshenv_source"
  install_editor

  if ! is_non_interactive && confirm 'Mise'; then
    install_mise
  fi
  [ "$show_fastfetch" = true ] && install_fastfetch
  [ "$prompt" = ohmyposh ] && install_oh_my_posh

  success 'Installation complete. Start a new Zsh login session to load the configuration.'
}

main "$@"
