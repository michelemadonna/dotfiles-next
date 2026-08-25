#!/bin/sh

set -eu

# Set this after creating the repository, or pass DOTFILES_REPO_URL at runtime.
DEFAULT_REPO_URL="REPLACE_WITH_REPOSITORY_URL"
REPO_URL=${DOTFILES_REPO_URL:-$DEFAULT_REPO_URL}
DOTFILES_DIR=${DOTFILES_DIR:-"$HOME/.dotfiles"}

info() {
  printf '\n==> %s\n' "$*"
}

die() {
  printf '\nError: %s\n' "$*" >&2
  exit 1
}

have() {
  command -v "$1" >/dev/null 2>&1
}

run_as_root() {
  if [ "$(id -u)" -eq 0 ]; then
    "$@"
  else
    sudo "$@"
  fi
}

confirm() {
  prompt=$1

  if [ ! -r /dev/tty ]; then
    info "No terminal available: skipping optional component '$prompt'."
    return 1
  fi

  while :; do
    printf 'Install %s? [y/N] ' "$prompt" >/dev/tty
    IFS= read -r answer </dev/tty || return 1
    case $answer in
      y | Y | yes | YES | Yes) return 0 ;;
      '' | n | N | no | NO | No) return 1 ;;
      *) printf 'Please answer y or n.\n' >/dev/tty ;;
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
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
    run_as_root apt-get update
    run_as_root apt-get install -y git
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
    run_as_root apt-get update
    run_as_root apt-get install -y \
      bat eza chafa mediainfo poppler-utils tree file dnsutils fd-find wget \
      stow grc ripgrep python3-pip command-not-found git-delta tmux htop

    mkdir -p "$HOME/.fonts"
    cp "$DOTFILES_DIR"/fonts/* "$HOME/.fonts/"
    have fc-cache || die 'fc-cache is required to install the bundled fonts.'
    fc-cache -f
  fi
}

install_base_links() {
  info 'Creating configuration links'
  mkdir -p "$HOME/.config" "$HOME/.ssh"
  chmod 700 "$HOME/.ssh"

  link_path "$DOTFILES_DIR/zsh/.zshenv" "$HOME/.zshenv"
  link_path "$DOTFILES_DIR/ssh/config" "$HOME/.ssh/config"
  link_path "$DOTFILES_DIR/tmux" "$HOME/.config/tmux"
  link_path "$DOTFILES_DIR/ripgrep" "$HOME/.config/ripgrep"
}

install_micro() {
  if [ "$PLATFORM" = macos ]; then
    brew install micro
  else
    run_as_root apt-get install -y micro
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
    run_as_root apt-get install -y "$package_file"
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
}

install_fastfetch() {
  if [ "$PLATFORM" = macos ]; then
    brew install fastfetch
  else
    run_as_root apt-get install -y fastfetch
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
  check_prerequisites
  setup_platform
  install_git
  clone_repository
  install_required_packages
  install_base_links

  confirm 'Micro' && install_micro
  confirm 'Fresh editor' && install_fresh
  confirm 'Mise' && install_mise
  confirm 'Fastfetch' && install_fastfetch
  confirm 'Oh My Posh' && install_oh_my_posh

  info 'Installation complete. Start a new Zsh login session to load the configuration.'
}

main "$@"
