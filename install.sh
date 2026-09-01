#!/bin/sh

set -eu

# Set this after creating the repository, or pass DOTFILES_REPO_URL at runtime.
DEFAULT_REPO_URL="https://github.com/michelemadonna/dotfiles-next.git"
REPO_URL=${DOTFILES_REPO_URL:-$DEFAULT_REPO_URL}
DOTFILES_DIR=${DOTFILES_DIR:-"$HOME/.dotfiles"}
MODE=interactive
BASE_PACKAGES_MARKER_VERSION=1

COLOR_CYAN=$(printf '\033[36m')
COLOR_YELLOW=$(printf '\033[33m')
COLOR_GREEN=$(printf '\033[32m')
COLOR_RED=$(printf '\033[31m')
COLOR_BOLD=$(printf '\033[1m')
COLOR_RESET=$(printf '\033[0m')

case ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} in
  *UTF-8* | *utf8*)
    FRAME_TOP_LEFT='╭'
    FRAME_TOP_RIGHT='╮'
    FRAME_BOTTOM_LEFT='╰'
    FRAME_BOTTOM_RIGHT='╯'
    FRAME_HORIZONTAL='─'
    FRAME_VERTICAL='│'
    ICON_WIZARD='◆'
    ICON_INFO='●'
    ICON_SUCCESS='✓'
    ICON_ERROR='✕'
    ICON_OPTION='○'
    ICON_SELECTED='●'
    ICON_CONTINUE='→'
    ICON_RESTART='↻'
    ICON_QUIT='×'
    ICON_SECTION='▸'
    ;;
  *)
    FRAME_TOP_LEFT='+'
    FRAME_TOP_RIGHT='+'
    FRAME_BOTTOM_LEFT='+'
    FRAME_BOTTOM_RIGHT='+'
    FRAME_HORIZONTAL='-'
    FRAME_VERTICAL='|'
    ICON_WIZARD=
    ICON_INFO=
    ICON_SUCCESS=
    ICON_ERROR=
    ICON_OPTION=
    ICON_SELECTED='*'
    ICON_CONTINUE='>'
    ICON_RESTART=
    ICON_QUIT='x'
    ICON_SECTION='>'
    ;;
esac

UI_WIDTH=80
UI_INNER_WIDTH=76
UI_FDS_OPEN=false
UI_TTY_STATE=
TEMP_PACKAGE_FILE=
MENU_VALUE=
UI_ERROR=

usage() {
  log_box "$COLOR_YELLOW" "$(icon_label "$ICON_CONTINUE" 'USAGE')" "$0 [non-interactive|--non-interactive]"
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
  log_box "$COLOR_YELLOW" "$(icon_label "$ICON_INFO" 'INFO')" "$*"
}

success() {
  log_box "$COLOR_GREEN" "$(icon_label "$ICON_SUCCESS" 'DONE')" "$*"
}

die() {
  log_box_error "$COLOR_RED" "$(icon_label "$ICON_ERROR" 'ERROR')" "$*"
  exit 1
}

icon_label() {
  icon=$1
  label=$2
  if [ -n "$icon" ]; then
    printf '%s %s' "$icon" "$label"
  else
    printf '%s' "$label"
  fi
}

set_ui_geometry() {
  columns=${COLUMNS:-}
  case $columns in
    '' | *[!0-9]*) columns=80 ;;
  esac

  if [ "$MODE" = interactive ] && [ "$UI_FDS_OPEN" = true ] && command -v tput >/dev/null 2>&1; then
    detected_columns=$(tput cols <&4 2>/dev/null || true)
    case $detected_columns in
      '' | *[!0-9]*) ;;
      *) columns=$detected_columns ;;
    esac
  fi

  [ "$columns" -lt 48 ] && columns=48
  [ "$columns" -gt 88 ] && columns=88
  UI_WIDTH=$columns
  UI_INNER_WIDTH=$((UI_WIDTH - 4))
}

repeat_character() {
  character=$1
  count=$2
  while [ "$count" -gt 0 ]; do
    printf '%s' "$character"
    count=$((count - 1))
  done
}

print_spaces() {
  repeat_character ' ' "$1"
}

log_border() {
  color=$1
  left=$2
  right=$3
  printf '%s%s' "$color" "$left"
  repeat_character "$FRAME_HORIZONTAL" $((UI_WIDTH - 2))
  printf '%s%s\n' "$right" "$COLOR_RESET"
}

log_line() {
  color=$1
  text=$2
  length=${#text}
  padding=$((UI_INNER_WIDTH - length + 1))
  [ "$padding" -lt 0 ] && padding=0
  printf '%s%s%s %s%s%s' "$color" "$FRAME_VERTICAL" "$COLOR_RESET" "$color" "$text" "$COLOR_RESET"
  print_spaces "$padding"
  printf '%s%s%s\n' "$color" "$FRAME_VERTICAL" "$COLOR_RESET"
}

log_box() {
  log_box_color=$1
  log_box_title=$2
  log_box_message=$3
  set_ui_geometry
  printf '\n'
  log_border "$log_box_color" "$FRAME_TOP_LEFT" "$FRAME_TOP_RIGHT"
  log_line "$log_box_color$COLOR_BOLD" "$log_box_title"
  printf '%s\n' "$log_box_message" | fold -s -w "$UI_INNER_WIDTH" |
    while IFS= read -r line || [ -n "$line" ]; do
      log_line "$log_box_color" "$line"
    done
  log_border "$log_box_color" "$FRAME_BOTTOM_LEFT" "$FRAME_BOTTOM_RIGHT"
}

log_box_error() {
  log_box_color=$1
  log_box_title=$2
  log_box_message=$3
  set_ui_geometry
  {
    printf '\n'
    log_border "$log_box_color" "$FRAME_TOP_LEFT" "$FRAME_TOP_RIGHT"
    log_line "$log_box_color$COLOR_BOLD" "$log_box_title"
    printf '%s\n' "$log_box_message" | fold -s -w "$UI_INNER_WIDTH" |
      while IFS= read -r line || [ -n "$line" ]; do
        log_line "$log_box_color" "$line"
      done
    log_border "$log_box_color" "$FRAME_BOTTOM_LEFT" "$FRAME_BOTTOM_RIGHT"
  } >&2
}

restore_terminal() {
  if [ -n "${UI_TTY_STATE:-}" ]; then
    stty "$UI_TTY_STATE" <&4 2>/dev/null || true
    UI_TTY_STATE=
  fi
}

cleanup() {
  restore_terminal
  if [ -n "${TEMP_PACKAGE_FILE:-}" ]; then
    rm -f -- "$TEMP_PACKAGE_FILE"
    TEMP_PACKAGE_FILE=
  fi
}

handle_signal() {
  cleanup
  exit 130
}

trap cleanup 0
trap handle_signal HUP INT TERM

ui_clear() {
  printf '\033[H\033[2J\033[3J' >&3
}

ui_border() {
  color=$1
  left=$2
  right=$3
  {
    printf '%s%s' "$color" "$left"
    repeat_character "$FRAME_HORIZONTAL" $((UI_WIDTH - 2))
    printf '%s%s\n' "$right" "$COLOR_RESET"
  } >&3
}

ui_line() {
  color=$1
  text=$2
  length=${#text}
  padding=$((UI_INNER_WIDTH - length + 1))
  [ "$padding" -lt 0 ] && padding=0
  {
    printf '%s%s%s %s%s%s' "$COLOR_CYAN" "$FRAME_VERTICAL" "$COLOR_RESET" "$color" "$text" "$COLOR_RESET"
    print_spaces "$padding"
    printf '%s%s%s\n' "$COLOR_CYAN" "$FRAME_VERTICAL" "$COLOR_RESET"
  } >&3
}

ui_text() {
  text=$1
  color=${2:-}
  printf '%s\n' "$text" | fold -s -w "$UI_INNER_WIDTH" |
    while IFS= read -r line || [ -n "$line" ]; do
      ui_line "$color" "$line"
    done
}

ui_begin() {
  title=$1
  set_ui_geometry
  ui_border "$COLOR_CYAN" "$FRAME_TOP_LEFT" "$FRAME_TOP_RIGHT"
  ui_line "$COLOR_BOLD$COLOR_CYAN" "$title"
  ui_line '' ''
}

ui_end() {
  ui_border "$COLOR_CYAN" "$FRAME_BOTTOM_LEFT" "$FRAME_BOTTOM_RIGHT"
}

ui_read_key() {
  UI_TTY_STATE=$(stty -g <&4) || die 'Could not read terminal settings.'
  stty -echo -icanon min 1 time 0 <&4 || {
    restore_terminal
    die 'Could not configure terminal input.'
  }
  UI_KEY=$(dd bs=1 count=1 <&4 2>/dev/null || true)
  restore_terminal
  case $UI_KEY in
    [A-Z]) UI_KEY=$(printf '%s' "$UI_KEY" | tr '[:upper:]' '[:lower:]') ;;
  esac
}

ui_show_error() {
  [ -n "$UI_ERROR" ] || return 0
  ui_line '' ''
  ui_text "$(icon_label "$ICON_ERROR" "$UI_ERROR")" "$COLOR_RED$COLOR_BOLD"
}

ui_intro() {
  UI_ERROR=
  while :; do
    ui_clear
    ui_begin "$(icon_label "$ICON_WIZARD" 'dotfiles-next setup wizard')"
    ui_text 'A polished, batteries-included Zsh environment for macOS and Ubuntu 26.04, built around Zsh for Humans.' "$COLOR_BOLD"
    ui_line '' ''
    ui_text 'The installer can install the required command-line tools and fonts, clone or reuse the repository, back up managed paths, create configuration links, and configure your prompt, editor, completions, SSH helpers, Fastfetch, and Mise.'
    ui_line '' ''
    ui_text "$(icon_label "$ICON_SUCCESS" 'Nothing changes until you review and approve the installation summary.')" "$COLOR_GREEN$COLOR_BOLD"
    ui_line '' ''
    ui_line "$COLOR_BOLD$COLOR_GREEN" "$(icon_label "$ICON_CONTINUE" '[c] Continue (default)')"
    ui_line "$COLOR_RED" "$(icon_label "$ICON_QUIT" '[q] Quit and do nothing')"
    ui_show_error
    ui_end
    ui_read_key
    case $UI_KEY in
      '' | c) return 0 ;;
      q) exit 0 ;;
      *) UI_ERROR="Unknown choice '$UI_KEY'. Press c, Enter, or q." ;;
    esac
  done
}

ui_menu() {
  title=$1
  question=$2
  default_key=$3
  options=$4
  UI_ERROR=

  while :; do
    ui_clear
    ui_begin "$(icon_label "$ICON_WIZARD" "$title")"
    ui_text "$question" "$COLOR_YELLOW$COLOR_BOLD"
    ui_line '' ''
    printf '%s\n' "$options" |
      while IFS='|' read -r key _value label || [ -n "$key" ]; do
        if [ "$key" = "$default_key" ]; then
          ui_line "$COLOR_BOLD$COLOR_GREEN" "$(icon_label "$ICON_SELECTED" "[$key] $label (default)")"
        else
          ui_line '' "$(icon_label "$ICON_OPTION" "[$key] $label")"
        fi
      done
    ui_line '' ''
    ui_line "$COLOR_RED" "$(icon_label "$ICON_QUIT" '[q] Quit and do nothing')"
    ui_show_error
    ui_end
    ui_read_key
    key=$UI_KEY
    [ -n "$key" ] || key=$default_key
    [ "$key" = q ] && exit 0
    MENU_VALUE=$(printf '%s\n' "$options" | awk -F '|' -v wanted="$key" '$1 == wanted { print $2; exit }')
    if [ -n "$MENU_VALUE" ]; then
      return 0
    fi
    UI_ERROR="Unknown choice '$key'. Select one of the displayed options."
  done
}

have() {
  command -v "$1" >/dev/null 2>&1
}

zsh_prerequisite_error() {
  reason=$1

  case $(uname -s) in
    Darwin)
      zsh_install_steps='Install Zsh with Homebrew:
  brew install -y zsh'
      ;;
    Linux)
      zsh_install_steps='Install Zsh with APT:
  sudo apt-get update
  sudo apt-get install -y zsh'
      ;;
    *)
      zsh_install_steps='Install Zsh with your operating system package manager.'
      ;;
  esac

  zsh_activate_steps="Make Zsh your login shell:
  chsh -s \"\$(command -v zsh)\""

  if have zsh; then
    zsh_setup_steps=$zsh_activate_steps
  else
    zsh_setup_steps="$zsh_install_steps

$zsh_activate_steps"
  fi

  log_box_error "$COLOR_RED" "$(icon_label "$ICON_ERROR" 'ZSH SETUP REQUIRED')" "$reason

$zsh_setup_steps

Sign out and sign back in, then rerun this installer."
  exit 1
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
  have zsh || zsh_prerequisite_error 'Zsh was not found.'

  login_shell=${SHELL:-}
  [ "${login_shell##*/}" = zsh ] ||
    zsh_prerequisite_error "Zsh is installed, but it is not the login shell for the current user (current: ${login_shell:-unknown})."

  have curl || die 'curl is required.'

}

check_interactive_terminal() {
  have stty || die 'stty is required for interactive mode.'
  have dd || die 'dd is required for interactive mode.'
  have fold || die 'fold is required for interactive mode.'
  have awk || die 'awk is required for interactive mode.'
  have tr || die 'tr is required for interactive mode.'

  if { exec 4</dev/tty 3>/dev/tty; } 2>/dev/null && stty -g <&4 >/dev/null 2>&1; then
    :
  elif [ -t 0 ] && [ -t 1 ]; then
    exec 4<&0 3>&1
    stty -g <&4 >/dev/null 2>&1 ||
      die 'Interactive mode could not access the terminal.'
  else
    die 'Interactive mode could not access the terminal.'
  fi
  UI_FDS_OPEN=true
}

detect_platform() {
  case $(uname -s) in
    Darwin)
      PLATFORM=macos
      have brew || have bash || die 'bash is required to install Homebrew.'
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

setup_platform() {
  [ "$PLATFORM" = macos ] || return 0

  if ! have brew; then
    info 'Installing Homebrew'
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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
}

install_git() {
  have git && return 0

  info 'Installing Git'
  if [ "$PLATFORM" = macos ]; then
    brew install -y git
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
    brew install -y coreutils bat eza fd git-delta htop ripgrep stow tmux tree wget git chafa mediainfo poppler file bind
    brew install -y --cask font-fira-code-nerd-font
  else
    run_apt_get update
    run_apt_get install -y \
      bat eza chafa mediainfo poppler-utils tree file dnsutils fd-find wget \
      stow grc ripgrep python3-pip command-not-found git-delta tmux htop unzip curl fontconfig

    mkdir -p "$HOME/.local/bin"
    fdfind_path=$(command -v fdfind || true)
    [ -z "$fdfind_path" ] || ln -sfn "$fdfind_path" "$HOME/.local/bin/fd"

    mkdir -p "$HOME/.fonts"
    cp "$DOTFILES_DIR"/fonts/* "$HOME/.fonts/"
    have fc-cache || die 'fc-cache is required to install the bundled fonts.'
    fc-cache -f
  fi
}

set_base_packages_marker() {
  state_home=${XDG_STATE_HOME:-"$HOME/.local/state"}
  marker_dir="$state_home/dotfiles-next"
  base_packages_marker="$marker_dir/base-packages-v${BASE_PACKAGES_MARKER_VERSION}-${PLATFORM}.done"
}

install_required_packages_once() {
  set_base_packages_marker

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
  link_path "$DOTFILES_DIR/git" "$HOME/.config/git"
  link_path "$DOTFILES_DIR/tmux" "$HOME/.config/tmux"
  link_path "$DOTFILES_DIR/ripgrep" "$HOME/.config/ripgrep"
}

set_interactive_defaults() {
  prompt=powerlevel10k
  editor=micro
  show_fastfetch=false
  use_fzf_tab=true
  use_fzf_from_z4h=true
  use_mise=true
  enable_auto_gencomp=true
  enable_oh_my_zsh=true
  load_ssh_key=true
  show_ssh_key=true
  askpass_require=false
}

ask_boolean_menu() {
  menu_title=$1
  menu_question=$2
  menu_default=$3
  ui_menu "$menu_title" "$menu_question" "$menu_default" 'y|true|Yes
n|false|No'
}

collect_interactive_choices() {
  ui_menu 'Prompt' 'Select the prompt renderer.' p 'p|powerlevel10k|Powerlevel10k
o|ohmyposh|Oh My Posh'
  prompt=$MENU_VALUE

  ui_menu 'Default editor' 'Select the editor exported through EDITOR and VISUAL.' m 'm|micro|Micro
f|fresh|Fresh
v|vim|Vim
n|nano|Nano'
  editor=$MENU_VALUE

  ui_menu 'Fastfetch' 'Show the visual system overview when Zsh starts? The first-terminal option counts all active macOS ttys and Linux pts sessions, including SSH, IDEs, and other terminal applications.' n 'n|false|No
y|true|Yes
f|first|Yes, but only at the first terminal prompt'
  show_fastfetch=$MENU_VALUE

  ask_boolean_menu 'fzf-tab' 'Enable fuzzy completion, previews, history search, and suggestions?' y
  use_fzf_tab=$MENU_VALUE

  ui_menu 'fzf binary' 'Select the fzf binary used by the shell.' z 'z|true|Use the z4h-native fzf
l|false|Use the latest release from a local Git checkout'
  use_fzf_from_z4h=$MENU_VALUE

  ask_boolean_menu 'Mise' 'Install Mise and prepare its shell caches?' y
  use_mise=$MENU_VALUE

  ask_boolean_menu 'Completion generator' 'Enable explicit Shift-Tab completion generation and caching?' y
  enable_auto_gencomp=$MENU_VALUE

  ask_boolean_menu 'Oh My Zsh helpers' 'Enable the selected Oh My Zsh libraries and helper plugins?' y
  enable_oh_my_zsh=$MENU_VALUE

  ask_boolean_menu 'SSH keys' 'Load SSH keys automatically when Zsh starts?' y
  load_ssh_key=$MENU_VALUE

  if [ "$load_ssh_key" = true ]; then
    ask_boolean_menu 'SSH key list' 'Show the SSH keys loaded in the agent?' y
    show_ssh_key=$MENU_VALUE
    ask_boolean_menu 'SSH askpass' 'Require the graphical SSH askpass helper?' n
    askpass_require=$MENU_VALUE
  else
    show_ssh_key=true
    askpass_require=false
  fi
}

human_boolean() {
  case $1 in
    true) printf 'Yes' ;;
    false) printf 'No' ;;
    first) printf 'Yes, but only at the first terminal prompt' ;;
    *) printf '%s' "$1" ;;
  esac
}

inspect_installation_state() {
  case $REPO_URL in
    '' | REPLACE_WITH_REPOSITORY_URL)
      die 'Set DEFAULT_REPO_URL in install.sh after creating the repository.'
      ;;
  esac

  if [ -d "$DOTFILES_DIR/.git" ]; then
    repository_action="Reuse existing checkout at $DOTFILES_DIR"
  elif [ -e "$DOTFILES_DIR" ]; then
    die "$DOTFILES_DIR already exists and is not a Git repository."
  else
    repository_action="Clone $REPO_URL into $DOTFILES_DIR"
  fi

  if [ "$PLATFORM" = macos ]; then
    if have brew; then
      package_manager_action='Reuse Homebrew'
    else
      package_manager_action='Install Homebrew non-interactively'
    fi
  else
    package_manager_action='Use APT'
  fi

  if have git; then
    git_action='Reuse installed Git'
  else
    git_action='Install Git'
  fi

  set_base_packages_marker
  if [ -f "$base_packages_marker" ]; then
    base_packages_action="Skip; marker found at $base_packages_marker"
  else
    base_packages_action='Install required packages and fonts'
  fi
}

ui_summary_line() {
  summary_label=$1
  summary_value=$2
  summary_length=$((${#summary_label} + ${#summary_value} + 2))

  if [ "$summary_length" -le "$UI_INNER_WIDTH" ]; then
    summary_padding=$((UI_INNER_WIDTH - summary_length + 1))
    {
      printf '%s%s%s ' "$COLOR_CYAN" "$FRAME_VERTICAL" "$COLOR_RESET"
      printf '%s%s%s: %s' "$COLOR_BOLD$COLOR_CYAN" "$summary_label" "$COLOR_RESET" "$summary_value"
      print_spaces "$summary_padding"
      printf '%s%s%s\n' "$COLOR_CYAN" "$FRAME_VERTICAL" "$COLOR_RESET"
    } >&3
  else
    ui_line "$COLOR_BOLD$COLOR_CYAN" "$summary_label:"
    ui_text "  $summary_value"
  fi
}

ui_section() {
  ui_line "$COLOR_BOLD$COLOR_YELLOW" "$(icon_label "$ICON_SECTION" "$1")"
}

tool_executable_available() {
  case $1 in
    */*) [ -x "$1" ] ;;
    *) have "$1" ;;
  esac
}

report_tool_version() {
  tool_label=$1
  tool_executable=$2
  tool_version_line=$3
  shift 3

  if ! tool_executable_available "$tool_executable"; then
    ui_summary_line "$tool_label" 'not found'
    return 0
  fi

  tool_version=$(
    "$tool_executable" "$@" 2>&1 |
      awk -v wanted="$tool_version_line" '
        NF {
          ++seen
          if (seen == wanted) {
            sub(/\r$/, "")
            print
            exit
          }
        }
      '
  ) || tool_version=
  [ -n "$tool_version" ] || tool_version='version unavailable'
  ui_summary_line "$tool_label" "$tool_version"
}

report_homebrew_tool_version() {
  homebrew_tool_label=$1
  homebrew_formula=$2
  homebrew_executable=$3
  homebrew_version_line=$4
  shift 4

  if [ -z "${homebrew_prefix:-}" ]; then
    ui_summary_line "$homebrew_tool_label" 'not found'
    return 0
  fi

  report_tool_version \
    "$homebrew_tool_label" \
    "$homebrew_prefix/opt/$homebrew_formula/bin/$homebrew_executable" \
    "$homebrew_version_line" \
    "$@"
}

report_z4h_versions() {
  z4h_root=${Z4H:-${XDG_CACHE_HOME:-$HOME/.cache}/zsh4humans/v5}
  z4h_revision=

  if [ -r "$z4h_root/zsh4humans/main.zsh" ] && [ -r "$z4h_root/zsh4humans/version" ]; then
    z4h_revision=$(tr -d '\r\n' <"$z4h_root/zsh4humans/version") || z4h_revision=
    case $z4h_revision in
      '' | *[!0-9]*) z4h_revision= ;;
    esac
  fi

  if [ -n "$z4h_revision" ]; then
    ui_summary_line 'Zsh for Humans' "v5 (revision $z4h_revision)"
  else
    ui_summary_line 'Zsh for Humans' 'v5 (pending first Zsh startup)'
  fi

  z4h_fzf="$z4h_root/fzf/bin/fzf"
  if [ -x "$z4h_fzf" ]; then
    report_tool_version 'fzf (z4h)' "$z4h_fzf" 1 --version
  else
    ui_summary_line 'fzf (z4h)' 'pending first Zsh startup'
  fi
}

show_installed_tool_versions() {
  is_non_interactive && return 0

  printf '\n' >&3
  ui_begin "$(icon_label "$ICON_SUCCESS" 'Installed tool versions')"

  ui_section 'Zsh for Humans'
  report_z4h_versions

  if [ "$PLATFORM" = macos ]; then
    homebrew_prefix=$(brew --prefix 2>/dev/null || true)
    ui_line '' ''
    ui_section 'Package manager'
    report_tool_version 'Homebrew' brew 1 --version
  fi

  ui_line '' ''
  ui_section 'Base command-line tools'
  if [ "$PLATFORM" = macos ]; then
    report_homebrew_tool_version 'Git' git git 1 --version
    report_homebrew_tool_version 'GNU coreutils' coreutils gdate 1 --version
    report_homebrew_tool_version 'bat' bat bat 1 --version
    report_homebrew_tool_version 'eza' eza eza 2 --version
    report_homebrew_tool_version 'fd' fd fd 1 --version
    report_homebrew_tool_version 'delta' git-delta delta 1 --version
    report_homebrew_tool_version 'htop' htop htop 1 --version
    report_homebrew_tool_version 'ripgrep' ripgrep rg 1 --version
    report_homebrew_tool_version 'GNU Stow' stow stow 1 --version
    report_homebrew_tool_version 'tmux' tmux tmux 1 -V
    report_homebrew_tool_version 'tree' tree tree 1 --version
    report_homebrew_tool_version 'Wget' wget wget 1 --version
    report_homebrew_tool_version 'Chafa' chafa chafa 1 --version
    report_homebrew_tool_version 'MediaInfo' mediainfo mediainfo 2 --Version
    report_homebrew_tool_version 'Poppler' poppler pdftotext 1 -v
    report_homebrew_tool_version 'file' file file 1 --version
    report_homebrew_tool_version 'DNS tools' bind dig 1 -v
  else
    report_tool_version 'Git' git 1 --version
    report_tool_version 'bat' batcat 1 --version
    report_tool_version 'eza' eza 2 --version
    report_tool_version 'fd' fdfind 1 --version
    report_tool_version 'delta' delta 1 --version
    report_tool_version 'htop' htop 1 --version
    report_tool_version 'ripgrep' rg 1 --version
    report_tool_version 'GNU Stow' stow 1 --version
    report_tool_version 'tmux' tmux 1 -V
    report_tool_version 'tree' tree 1 --version
    report_tool_version 'Wget' wget 1 --version
    report_tool_version 'Chafa' chafa 1 --version
    report_tool_version 'MediaInfo' mediainfo 2 --Version
    report_tool_version 'Poppler' pdftotext 1 -v
    report_tool_version 'file' file 1 --version
    report_tool_version 'DNS tools' dig 1 -v
    report_tool_version 'grc' grc 1 --version
    report_tool_version 'pip' python3 1 -m pip --version
    report_tool_version 'command-not-found package' dpkg-query 1 -W "-f=\${Version}\n" command-not-found
  fi

  ui_line '' ''
  ui_section 'Interactive selections'
  case $editor in
    vim)
      if [ "$PLATFORM" = macos ]; then
        report_homebrew_tool_version 'Vim' vim vim 1 --version
      else
        report_tool_version 'Vim' vim 1 --version
      fi
      ;;
    nano)
      if [ "$PLATFORM" = macos ]; then
        report_homebrew_tool_version 'Nano' nano nano 1 --version
      else
        report_tool_version 'Nano' nano 1 --version
      fi
      ;;
    fresh)
      if [ "$PLATFORM" = macos ]; then
        report_homebrew_tool_version 'Fresh' fresh-editor fresh 1 --version
      else
        report_tool_version 'Fresh' fresh 1 --version
      fi
      ;;
    micro)
      if [ "$PLATFORM" = macos ]; then
        report_homebrew_tool_version 'Micro' micro micro 1 --version
      else
        report_tool_version 'Micro' micro 1 --version
      fi
      ;;
  esac

  if [ "$use_mise" = true ]; then
    if [ "$PLATFORM" = macos ]; then
      report_homebrew_tool_version 'Mise' mise mise 1 --version
    else
      mise_executable="$HOME/.local/bin/mise"
      report_tool_version 'Mise' "$mise_executable" 1 --version
    fi
  fi

  case $show_fastfetch in
    true | first)
      if [ "$PLATFORM" = macos ]; then
        report_homebrew_tool_version 'Fastfetch' fastfetch fastfetch 1 --version
      else
        report_tool_version 'Fastfetch' fastfetch 1 --version
      fi
      ;;
  esac

  if [ "$prompt" = ohmyposh ]; then
    if [ "$PLATFORM" = macos ]; then
      report_homebrew_tool_version 'Oh My Posh' oh-my-posh oh-my-posh 1 --version
    else
      oh_my_posh_executable="$HOME/.local/bin/oh-my-posh"
      report_tool_version 'Oh My Posh' "$oh_my_posh_executable" 1 --version
    fi
  fi

  ui_end
}

ui_summary() {
  UI_ERROR=
  while :; do
    ui_clear
    ui_begin "$(icon_label "$ICON_WIZARD" 'Review installation plan')"
    ui_section 'System and operations'
    ui_summary_line 'Platform' "$PLATFORM"
    ui_summary_line 'Package manager' "$package_manager_action"
    ui_summary_line 'Git' "$git_action"
    ui_summary_line 'Repository' "$repository_action"
    ui_summary_line 'Base packages' "$base_packages_action"
    ui_summary_line 'Mise' "$(human_boolean "$use_mise")"
    ui_line '' ''
    ui_section 'Zsh preferences'
    ui_summary_line 'Prompt' "$prompt"
    ui_summary_line 'Editor' "$editor"
    ui_summary_line 'Fastfetch' "$(human_boolean "$show_fastfetch")"
    ui_summary_line 'fzf-tab' "$(human_boolean "$use_fzf_tab")"
    ui_summary_line 'fzf binary' "$(if [ "$use_fzf_from_z4h" = true ]; then printf 'z4h native'; else printf 'latest release from a local Git checkout'; fi)"
    ui_summary_line 'Completion generator' "$(human_boolean "$enable_auto_gencomp")"
    ui_summary_line 'Oh My Zsh helpers' "$(human_boolean "$enable_oh_my_zsh")"
    ui_summary_line 'Load SSH keys' "$(human_boolean "$load_ssh_key")"
    if [ "$load_ssh_key" = true ]; then
      ui_summary_line 'Show SSH keys' "$(human_boolean "$show_ssh_key")"
      ui_summary_line 'Require SSH askpass' "$(human_boolean "$askpass_require")"
    else
      ui_summary_line 'Show SSH keys' 'Not applicable'
      ui_summary_line 'Require SSH askpass' 'Not applicable'
    fi
    ui_line '' ''
    ui_text "$(icon_label "$ICON_SUCCESS" 'No installation operation has been performed yet.')" "$COLOR_GREEN$COLOR_BOLD"
    ui_line '' ''
    ui_line "$COLOR_BOLD$COLOR_GREEN" "$(icon_label "$ICON_CONTINUE" '[a] Apply this plan (default)')"
    ui_line "$COLOR_YELLOW" "$(icon_label "$ICON_RESTART" '[r] Restart the wizard')"
    ui_line "$COLOR_RED" "$(icon_label "$ICON_QUIT" '[q] Quit and do nothing')"
    ui_show_error
    ui_end
    ui_read_key
    case $UI_KEY in
      '' | a) return 0 ;;
      r) return 1 ;;
      q) exit 0 ;;
      *) UI_ERROR="Unknown choice '$UI_KEY'. Press a, Enter, r, or q." ;;
    esac
  done
}

generate_zshenv() {
  info 'Configuring Zsh preferences'

  source_file="$DOTFILES_DIR/zsh/.zshenv.init"
  generated_file="$DOTFILES_DIR/zsh/home/.zshenv"
  if is_non_interactive && [ -f "$generated_file" ]; then
    source_file="$generated_file"
  fi
  [ -f "$source_file" ] || die "Missing Zsh template: $source_file"

  mkdir -p "$(dirname "$generated_file")"

  if is_non_interactive; then
    [ "$source_file" = "$generated_file" ] || cp "$source_file" "$generated_file"
    return 0
  fi

  awk \
    -v prompt="$prompt" \
    -v editor="$editor" \
    -v show_fastfetch="$show_fastfetch" \
    -v use_fzf_tab="$use_fzf_tab" \
    -v use_fzf_from_z4h="$use_fzf_from_z4h" \
    -v use_mise="$use_mise" \
    -v enable_auto_gencomp="$enable_auto_gencomp" \
    -v enable_oh_my_zsh="$enable_oh_my_zsh" \
    -v load_ssh_key="$load_ssh_key" \
    -v show_ssh_key="$show_ssh_key" \
    -v askpass_require="$askpass_require" '
      /^  export Z4H_PROMPT=/ { $0 = "  export Z4H_PROMPT=\"" prompt "\""; }
      /^  export Z4H_SHOW_FASTFETCH=/ { $0 = "  export Z4H_SHOW_FASTFETCH=" show_fastfetch; }
      /^  export Z4H_USE_FZF_TAB=/ { $0 = "  export Z4H_USE_FZF_TAB=" use_fzf_tab; }
      /^  export Z4H_USE_FZF_FROM_Z4H=/ { $0 = "  export Z4H_USE_FZF_FROM_Z4H=" use_fzf_from_z4h; }
      /^  export Z4H_USE_MISE=/ { $0 = "  export Z4H_USE_MISE=" use_mise; }
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
  # Keep package selection aligned with the defaults in zsh/.zshenv.init.
  prompt=powerlevel10k
  editor=micro
  show_fastfetch=first
  use_fzf_tab=true
  use_fzf_from_z4h=false
  use_mise=true
  enable_auto_gencomp=true
  enable_oh_my_zsh=true
  load_ssh_key=true
  show_ssh_key=true
  askpass_require=false
}

load_non_interactive_choices() {
  choices_file="$DOTFILES_DIR/zsh/home/.zshenv"
  [ -f "$choices_file" ] || return 0

  value_from_choices() {
    awk -v variable="$1" '
      $0 ~ "^  export " variable "=" {
        sub("^  export " variable "=", "")
        sub(/[[:space:]]+#.*/, "")
        gsub(/^"|"$/, "")
        print
        exit
      }
    ' "$choices_file"
  }

  for choice in \
    'prompt Z4H_PROMPT' 'editor EDITOR' 'show_fastfetch Z4H_SHOW_FASTFETCH' \
    'use_fzf_tab Z4H_USE_FZF_TAB' 'use_fzf_from_z4h Z4H_USE_FZF_FROM_Z4H' \
    'use_mise Z4H_USE_MISE' 'enable_auto_gencomp Z4H_ENABLE_AUTO_GENCOMP' \
    'enable_oh_my_zsh Z4H_ENABLE_OH_MY_ZSH' 'load_ssh_key Z4H_SSH_LOAD_KEY' \
    'show_ssh_key Z4H_SSH_SHOW_KEY' 'askpass_require Z4H_SSH_ASKPASS_REQUIRE'; do
    choice_name=${choice%% *}
    choice_variable=${choice#* }
    choice_value=$(value_from_choices "$choice_variable")
    [ -n "$choice_value" ] && eval "$choice_name=\$choice_value"
  done
}

install_editor() {
  if [ "$editor" = vim ] && [ "$PLATFORM" = macos ]; then
    info 'Using the Vim provided by macOS; skipping installation'
    link_editor_config
    return 0
  fi

  if command -v "$editor" >/dev/null 2>&1 || [ -x "$HOME/.local/bin/$editor" ]; then
    info "$editor already installed; skipping installation"
    link_editor_config
    return 0
  fi
  case $editor in
    vim)
      if [ "$PLATFORM" = macos ]; then
        brew install -y vim
      else
        run_apt_get install -y vim
      fi
      ;;
    nano)
      if [ "$PLATFORM" = macos ]; then
        brew install -y nano
      else
        run_apt_get install -y nano
      fi
      ;;
    fresh) install_fresh ;;
    micro) install_micro ;;
  esac
  link_editor_config
}

link_editor_config() {
  editor_config="$DOTFILES_DIR/$editor"
  case $editor in
    nano)
      mkdir -p "$HOME/.cache/nano/backups"
      [ -e "$editor_config" ] && link_path "$editor_config" "$HOME/.config/nano"
      ;;
    vim)
      [ -e "$editor_config" ] && link_path "$editor_config" "$HOME/.config/vim"
      ;;
    *)
      [ -e "$editor_config" ] && link_path "$editor_config" "$HOME/.config/$editor"
      ;;
  esac
}

install_micro() {
  if [ "$PLATFORM" = macos ]; then
    brew install -y micro
  else
    run_apt_get install -y micro
  fi
  link_editor_config
}

install_fresh() {
  if [ "$PLATFORM" = macos ]; then
    brew install -y fresh-editor
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
    TEMP_PACKAGE_FILE=$package_file
    curl -fsSL "$download_url" -o "$package_file"
    run_apt_get install -y "$package_file"
    rm -f "$package_file"
    TEMP_PACKAGE_FILE=
  fi
  link_editor_config
}

install_mise() {
  if command -v mise >/dev/null 2>&1 || [ -x "$HOME/.local/bin/mise" ]; then
    info 'Mise already installed; skipping installation'
  elif [ "$PLATFORM" = macos ]; then
    brew install -y mise
  else
    mkdir -p "$HOME/.local/bin"
    MISE_INSTALL_PATH="$HOME/.local/bin/mise"
    export MISE_INSTALL_PATH
    curl -fsSL https://mise.run | sh
  fi
  command -v mise >/dev/null 2>&1 || [ -x "$HOME/.local/bin/mise" ] || return 1
  link_path "$DOTFILES_DIR/mise" "$HOME/.config/mise"
  info 'Preparing Mise shell caches'
  sh "$DOTFILES_DIR/zsh/helpers/prepare-mise-cache.sh"
}

install_fastfetch() {
  if command -v fastfetch >/dev/null 2>&1 || [ -x "$HOME/.local/bin/fastfetch" ]; then
    info 'Fastfetch already installed; skipping installation'
    link_path "$DOTFILES_DIR/fastfetch" "$HOME/.config/fastfetch"
    return 0
  fi
  if [ "$PLATFORM" = macos ]; then
    brew install -y fastfetch
  else
    run_apt_get install -y fastfetch
  fi
  link_path "$DOTFILES_DIR/fastfetch" "$HOME/.config/fastfetch"
}

install_oh_my_posh() {
  if command -v oh-my-posh >/dev/null 2>&1 || [ -x "$HOME/.local/bin/oh-my-posh" ]; then
    info 'Oh My Posh already installed; skipping installation'
    link_path "$DOTFILES_DIR/oh-my-posh" "$HOME/.config/oh-my-posh"
    return 0
  fi
  if [ "$PLATFORM" = macos ]; then
    brew install oh-my-posh
  else
    mkdir -p "$HOME/.local/bin"
    curl -fsSL https://ohmyposh.dev/install.sh | bash -s -- -d "$HOME/.local/bin"
  fi
  link_path "$DOTFILES_DIR/oh-my-posh" "$HOME/.config/oh-my-posh"
}

install_fzf_local() {
  fzf_repo="$HOME/.local/share/fzf"
  fzf_bin="$HOME/.local/bin/fzf"
  mkdir -p "$HOME/.local/share" "$HOME/.local/bin"
  if [ -d "$fzf_repo/.git" ]; then
    info 'Updating local fzf checkout'
    git -C "$fzf_repo" pull --ff-only
  else
    rm -rf "$fzf_repo"
    git clone --depth=1 https://github.com/junegunn/fzf.git "$fzf_repo"
  fi
  bash "$fzf_repo/install" --bin
  [ -x "$fzf_repo/bin/fzf" ] || die 'Local fzf installation failed.'
  cp "$fzf_repo/bin/fzf" "$fzf_bin"
  fzf_version=$($fzf_bin --version 2>/dev/null) || die 'Cannot determine the local fzf version.'
  if ! awk -v version="${fzf_version%% *}" 'BEGIN {
    split(version, have, ".")
    split("0.66.0", want, ".")
    for (i = 1; i <= 3; i++) {
      if ((have[i] + 0) > (want[i] + 0)) exit 0
      if ((have[i] + 0) < (want[i] + 0)) exit 1
    }
    exit 0
  }'; then
    die "Local fzf 0.66.0 or newer is required; found ${fzf_version%% *}."
  fi
}

apply_installation() {
  info 'Starting installation'
  setup_platform
  info "Detected platform: $PLATFORM"
  install_git
  clone_repository
  install_required_packages_once

  if is_non_interactive; then
    load_non_interactive_choices
  fi

  generate_zshenv
  zshenv_source="$DOTFILES_DIR/zsh/home/.zshenv"
  success 'Generated Zsh preferences'

  install_base_links "$zshenv_source"
  success 'Created base configuration links'
  info "Installing selected editor: $editor"
  install_editor
  success "Editor ready: $editor"

  if [ "$use_fzf_from_z4h" = false ]; then
    info 'Installing local fzf from the latest Git checkout'
    install_fzf_local
    success 'Local fzf ready'
  fi

  if [ "$use_mise" = true ]; then
    info 'Installing and preparing Mise'
    install_mise
    success 'Mise, shell cache, and asdf compatibility layer ready'
  fi
  case $show_fastfetch in
    true | first)
      info 'Installing Fastfetch'
      install_fastfetch
      success 'Fastfetch ready'
      ;;
  esac
  if [ "$prompt" = ohmyposh ]; then
    info 'Installing Oh My Posh'
    install_oh_my_posh
    success 'Oh My Posh ready'
  fi
  success 'Selected tools and configurations are ready'
  return 0
}

main() {
  parse_arguments "$@"

  if is_non_interactive; then
    info 'Starting non-interactive mode'
    check_prerequisites
    detect_platform
    info "Detected platform: $PLATFORM"
    configure_non_interactive
  else
    check_interactive_terminal
    ui_intro
    check_prerequisites
    detect_platform
    inspect_installation_state

    while :; do
      set_interactive_defaults
      collect_interactive_choices
      ui_summary && break
    done

    ui_clear
    info 'Applying the approved installation plan'
  fi

  apply_installation

  if ! is_non_interactive; then
    show_installed_tool_versions
  fi

  success 'Installation complete. Start a new Zsh login session to load the configuration.'
}

main "$@"
