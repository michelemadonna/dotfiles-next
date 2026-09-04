#!/bin/sh

set -eu

ROOT=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-installer-test.XXXXXX")
trap 'rm -rf -- "$TEST_ROOT"' 0 HUP INT TERM

awk '!/^main "\$@"$/' "$ROOT/install.sh" >"$TEST_ROOT/install-lib.sh"

assert_equal() {
  [ "$1" = "$2" ] || {
    printf 'expected: %s\nactual:   %s\n' "$2" "$1" >&2
    exit 1
  }
}

platform_result=$(
  sh -c '
    . "$1"
    uname() { [ "$1" = -s ] && printf "Darwin\n" || printf "x86_64\n"; }
    detect_platform
    printf "%s:%s:%s\n" "$PLATFORM" "$PACKAGE_MANAGER" "$MACOS_ARCH"
  ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$platform_result" 'macos:macports:x86_64'

platform_result=$(
  DOTFILES_INTEL_PACKAGE_MANAGER=homebrew sh -c '
    . "$1"
    uname() { [ "$1" = -s ] && printf "Darwin\n" || printf "x86_64\n"; }
    brew() { :; }
    detect_platform
    printf "%s:%s:%s\n" "$PLATFORM" "$PACKAGE_MANAGER" "$MACOS_ARCH"
  ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$platform_result" 'macos:homebrew:x86_64'

invalid_provider_result=$(
  DOTFILES_INTEL_PACKAGE_MANAGER=invalid sh -c '
    . "$1"
    uname() { [ "$1" = -s ] && printf "Darwin\n" || printf "x86_64\n"; }
    die() { printf "%s\n" "$*"; exit 1; }
    detect_platform
  ' sh "$TEST_ROOT/install-lib.sh" 2>&1 || true
)
case $invalid_provider_result in
  *'Unsupported DOTFILES_INTEL_PACKAGE_MANAGER value: invalid'*) ;;
  *)
    printf 'invalid Intel provider was not rejected:\n%s\n' "$invalid_provider_result" >&2
    exit 1
    ;;
esac

mkdir -p "$TEST_ROOT/persisted-dotfiles/zsh/home"
printf '  export DOTFILES_INTEL_PACKAGE_MANAGER=homebrew\n' >"$TEST_ROOT/persisted-dotfiles/zsh/home/.zshenv"
platform_result=$(
  DOTFILES_DIR="$TEST_ROOT/persisted-dotfiles" sh -c '
    . "$1"
    uname() { [ "$1" = -s ] && printf "Darwin\n" || printf "x86_64\n"; }
    brew() { :; }
    detect_platform
    printf "%s:%s:%s\n" "$PLATFORM" "$PACKAGE_MANAGER" "$MACOS_ARCH"
  ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$platform_result" 'macos:homebrew:x86_64'

platform_result=$(
  DOTFILES_DIR="$TEST_ROOT/persisted-dotfiles" \
    DOTFILES_INTEL_PACKAGE_MANAGER=macports sh -c '
      . "$1"
      uname() { [ "$1" = -s ] && printf "Darwin\n" || printf "x86_64\n"; }
      detect_platform
      printf "%s:%s:%s\n" "$PLATFORM" "$PACKAGE_MANAGER" "$MACOS_ARCH"
    ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$platform_result" 'macos:macports:x86_64'

platform_result=$(
  DOTFILES_INTEL_PACKAGE_MANAGER=macports sh -c '
    . "$1"
    uname() { [ "$1" = -s ] && printf "Darwin\n" || printf "arm64\n"; }
    brew() { :; }
    detect_platform
    printf "%s:%s:%s\n" "$PLATFORM" "$PACKAGE_MANAGER" "$MACOS_ARCH"
  ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$platform_result" 'macos:homebrew:arm64'

platform_result=$(
  sh -c '
    . "$1"
    uname() { printf "Linux\n"; }
    have() {
      case $1 in apt-get | sudo) return 0 ;; esac
      command -v "$1" >/dev/null 2>&1
    }
    detect_platform
    printf "%s:%s\n" "$PLATFORM" "$PACKAGE_MANAGER"
  ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$platform_result" 'linux:apt'

interactive_provider=$(
  sh -c '
    . "$1"
    PLATFORM=macos
    MACOS_ARCH=x86_64
    PACKAGE_MANAGER=macports
    ui_menu() { MENU_VALUE=homebrew; }
    collect_intel_package_manager_choice
    printf "%s:%s\n" "$PACKAGE_MANAGER" "$DOTFILES_INTEL_PACKAGE_MANAGER"
  ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$interactive_provider" 'homebrew:homebrew'

mkdir -p "$TEST_ROOT/generated-dotfiles/zsh/home"
cp "$ROOT/zsh/.zshenv.init" "$TEST_ROOT/generated-dotfiles/zsh/.zshenv.init"
DOTFILES_DIR="$TEST_ROOT/generated-dotfiles" sh -c '
  . "$1"
  MODE=interactive
  PACKAGE_MANAGER=homebrew
  DOTFILES_INTEL_PACKAGE_MANAGER=homebrew
  configure_non_interactive
  info() { :; }
  generate_zshenv
  grep -q "^  export DOTFILES_INTEL_PACKAGE_MANAGER=homebrew$" "$DOTFILES_DIR/zsh/home/.zshenv"
' sh "$TEST_ROOT/install-lib.sh"

privilege_log=$TEST_ROOT/privilege.log
PRIVILEGE_LOG=$privilege_log sh -c '
  . "$1"
  MODE=interactive
  info() { printf "INFO:%s\n" "$*" >>"$PRIVILEGE_LOG"; }
  sudo() { printf "SUDO:%s\n" "$*" >>"$PRIVILEGE_LOG"; }
  run_privileged "install test files into /opt/local" test-command --flag
' sh "$TEST_ROOT/install-lib.sh"

privilege_lines=$(sed -n '1p;2p' "$privilege_log")
case $privilege_lines in
  *'INFO:Administrator privileges are required to install test files into /opt/local.'*'SUDO:test-command --flag'*) ;;
  *)
    printf 'privilege reason was not logged before sudo:\n%s\n' "$privilege_lines" >&2
    exit 1
    ;;
esac

noninteractive_log=$TEST_ROOT/noninteractive.log
PRIVILEGE_LOG=$noninteractive_log sh -c '
  . "$1"
  MODE=non-interactive
  info() { printf "INFO:%s\n" "$*" >>"$PRIVILEGE_LOG"; }
  sudo() { printf "SUDO:%s\n" "$*" >>"$PRIVILEGE_LOG"; }
  run_privileged "refresh the package index" test-command
' sh "$TEST_ROOT/install-lib.sh"
grep -q '^SUDO:-n test-command$' "$noninteractive_log"

homebrew_log=$TEST_ROOT/homebrew.log
HOMEBREW_LOG=$homebrew_log sh -c '
  . "$1"
  MODE=interactive
  PACKAGE_MANAGER=homebrew
  activate_count=0
  activate_homebrew() {
    activate_count=$((activate_count + 1))
    [ "$activate_count" -gt 1 ]
  }
  have() { [ "$1" = bash ]; }
  info() { :; }
  run_privileged() {
    printf "PRIVILEGED:%s:%s\n" "$1" "$2" >>"$HOMEBREW_LOG"
    [ "$2" = /usr/bin/true ]
  }
  curl() {
    printf "%s\n" '\''printf "INSTALLER:NONINTERACTIVE=%s\n" "${NONINTERACTIVE:-}" >>"$HOMEBREW_LOG"'\''
  }
  export HOMEBREW_LOG
  setup_homebrew
' sh "$TEST_ROOT/install-lib.sh"
homebrew_lines=$(sed -n '1p;2p' "$homebrew_log")
case $homebrew_lines in
  'PRIVILEGED:cache sudo authorization for the official Homebrew installer to create and configure its default prefix:/usr/bin/true
INSTALLER:NONINTERACTIVE=1') ;;
  *)
    printf 'Homebrew was not preauthorized before its non-interactive installer:\n%s\n' "$homebrew_lines" >&2
    exit 1
    ;;
esac

homebrew_failure_log=$TEST_ROOT/homebrew-failure.log
homebrew_failure=$(
  HOMEBREW_LOG=$homebrew_failure_log sh -c '
    . "$1"
    MODE=non-interactive
    PACKAGE_MANAGER=homebrew
    activate_homebrew() { return 1; }
    have() { [ "$1" = bash ]; }
    info() { :; }
    sudo() {
      printf "SUDO:%s\n" "$*" >>"$HOMEBREW_LOG"
      return 1
    }
    curl() {
      printf "CURL:%s\n" "$*" >>"$HOMEBREW_LOG"
      exit 99
    }
    die() {
      printf "DIE:%s\n" "$*"
      exit 1
    }
    export HOMEBREW_LOG
    setup_homebrew
  ' sh "$TEST_ROOT/install-lib.sh" 2>&1 || true
)
grep -q '^SUDO:-n /usr/bin/true$' "$homebrew_failure_log"
if grep -q '^CURL:' "$homebrew_failure_log"; then
  printf 'Homebrew download started without non-interactive sudo authorization\n' >&2
  exit 1
fi
case $homebrew_failure in
  *'DIE:The privileged command failed. Non-interactive mode cannot prompt for a sudo password: /usr/bin/true'*) ;;
  *)
    printf 'missing Homebrew sudo authorization did not fail clearly:\n%s\n' "$homebrew_failure" >&2
    exit 1
    ;;
esac

macports_command=$(
  sh -c '
    . "$1"
    MODE=interactive
    MACPORTS_PORT=/opt/local/bin/port
    run_privileged() {
      shift
      printf "%s\n" "$*"
    }
    run_macports "install requested ports" install bat
  ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$macports_command" '/opt/local/bin/port -N install bat'

required_packages=$(
  sh -c '
    . "$1"
    PACKAGE_MANAGER=macports
    HOME=$2/home
    DOTFILES_DIR=$2/dotfiles
    info() { :; }
    run_macports() { printf "MACPORTS:%s\n" "$*"; }
    install_macports_ports() { printf "PORTS:%s\n" "$*"; }
    mkdir() { :; }
    cp() { :; }
    install_required_packages
  ' sh "$TEST_ROOT/install-lib.sh" "$TEST_ROOT"
)
case $required_packages in
  *coreutils*)
    printf 'Intel MacPorts packages unexpectedly include coreutils:\n%s\n' "$required_packages" >&2
    exit 1
    ;;
esac
case $required_packages in
  *'PORTS:bat eza fd git git-delta '*) ;;
  *)
    printf 'Intel MacPorts packages do not include Git:\n%s\n' "$required_packages" >&2
    exit 1
    ;;
esac

required_packages=$(
  sh -c '
    . "$1"
    HOME=$2/home
    DOTFILES_DIR=$2/dotfiles
    info() { :; }
    brew() { printf "BREW:%s:%s\n" "$MACOS_ARCH" "$*"; }
    for MACOS_ARCH in x86_64 arm64; do
      PACKAGE_MANAGER=homebrew
      install_required_packages
    done
  ' sh "$TEST_ROOT/install-lib.sh" "$TEST_ROOT"
)
case $required_packages in
  *coreutils*)
    printf 'Intel or Apple Silicon Homebrew packages unexpectedly include coreutils:\n%s\n' "$required_packages" >&2
    exit 1
    ;;
esac
case $required_packages in
  *'BREW:x86_64:install -y bat eza fd git git-delta '*'BREW:arm64:install -y bat eza fd git git-delta '*) ;;
  *)
    printf 'Intel or Apple Silicon Homebrew packages do not include Git:\n%s\n' "$required_packages" >&2
    exit 1
    ;;
esac

legacy_marker_root=$TEST_ROOT/legacy-marker-state
mkdir -p "$legacy_marker_root/dotfiles-next"
: >"$legacy_marker_root/dotfiles-next/base-packages-v2-macos-homebrew.done"
marker_log=$TEST_ROOT/marker.log
XDG_STATE_HOME=$legacy_marker_root MARKER_LOG=$marker_log sh -c '
  . "$1"
  PLATFORM=macos
  PACKAGE_MANAGER=homebrew
  info() { :; }
  install_required_packages() { printf "INSTALL\n" >>"$MARKER_LOG"; }
  export MARKER_LOG
  install_required_packages_once
  install_required_packages_once
  [ -f "$XDG_STATE_HOME/dotfiles-next/base-packages-v3-macos-homebrew.done" ]
' sh "$TEST_ROOT/install-lib.sh"
assert_equal "$(cat "$marker_log")" 'INSTALL'

grep -q "report_macports_tool_version 'Git' git 1 --version" "$ROOT/install.sh"
grep -q "report_homebrew_tool_version 'Git' git git 1 --version" "$ROOT/install.sh"

printf '#!/bin/sh\nprintf "git version 2.39.5 (Apple Git-154)\\n"\n' >"$TEST_ROOT/apple-git"
chmod +x "$TEST_ROOT/apple-git"
apple_git_result=$(
  sh -c '
    . "$1"
    PLATFORM=macos
    PACKAGE_MANAGER=homebrew
    SYSTEM_GIT=$2/apple-git
    brew() { exit 99; }
    install_macports_ports() { exit 99; }
    install_git
    printf "apple_git=ok\n"
  ' sh "$TEST_ROOT/install-lib.sh" "$TEST_ROOT"
)
assert_equal "$apple_git_result" 'apple_git=ok'

clt_log=$TEST_ROOT/clt.log
clt_ready=$TEST_ROOT/clt-ready
mkdir -p "$TEST_ROOT/clt-stubs"
cat >"$TEST_ROOT/clt-stubs/xcode-select" <<'EOF'
#!/bin/sh
printf 'XCODE_SELECT:%s\n' "$*" >>"$CLT_LOG"
case $1 in
  -p)
    [ -f "$CLT_READY" ] || exit 1
    printf '%s\n' "$COMMAND_LINE_TOOLS_DIR"
    ;;
  --switch) : >"$CLT_READY" ;;
  --install) exit 99 ;;
esac
EOF
cat >"$TEST_ROOT/clt-stubs/xcrun" <<'EOF'
#!/bin/sh
printf 'XCRUN:%s\n' "$*" >>"$CLT_LOG"
[ "$*" = '--find clang' ] && [ -f "$CLT_READY" ]
EOF
cat >"$TEST_ROOT/clt-stubs/softwareupdate" <<'EOF'
#!/bin/sh
printf 'SOFTWAREUPDATE:%s\n' "$*" >>"$CLT_LOG"
case $1 in
  -l)
    if [ "${CLT_NO_LABEL:-}" = 1 ]; then
      printf '%s\n' 'No new software available.'
      exit 0
    fi
    printf '%s\n' \
      'Software Update Tool' \
      '* Label: Command Line Tools for Xcode-26.0' \
      '    Title: Command Line Tools for Xcode, Version: 26.0'
    ;;
  -i) [ "$2" = 'Command Line Tools for Xcode-26.0' ] ;;
  *) exit 2 ;;
esac
EOF
chmod +x \
  "$TEST_ROOT/clt-stubs/xcode-select" \
  "$TEST_ROOT/clt-stubs/xcrun" \
  "$TEST_ROOT/clt-stubs/softwareupdate"
CLT_LOG=$clt_log CLT_READY=$clt_ready sh -c '
  . "$1"
  MODE=interactive
  PLATFORM=macos
  PACKAGE_MANAGER=macports
  XCODE_SELECT=$2/clt-stubs/xcode-select
  XCRUN=$2/clt-stubs/xcrun
  SOFTWAREUPDATE=$2/clt-stubs/softwareupdate
  COMMAND_LINE_TOOLS_DIR=$2/CommandLineTools
  COMMAND_LINE_TOOLS_PLACEHOLDER=$2/clt-placeholder
  MACPORTS_PREFIX=$2/macports-prefix
  MACPORTS_PORT=$2/missing-port
  export CLT_LOG CLT_READY COMMAND_LINE_TOOLS_DIR
  info() { printf "INFO:%s\n" "$*" >>"$CLT_LOG"; }
  run_privileged() {
    printf "PRIVILEGED:%s\n" "$1" >>"$CLT_LOG"
    shift
    "$@"
  }
  install_macports() {
    apple_developer_tools_ready
    printf "MACPORTS_INSTALL\n" >>"$CLT_LOG"
  }
  setup_platform
  [ ! -e "$COMMAND_LINE_TOOLS_PLACEHOLDER" ]
' sh "$TEST_ROOT/install-lib.sh" "$TEST_ROOT"
grep -q '^SOFTWAREUPDATE:-i Command Line Tools for Xcode-26.0$' "$clt_log"
grep -q '^XCODE_SELECT:--switch ' "$clt_log"
grep -q '^MACPORTS_INSTALL$' "$clt_log"
if grep -q -- '--install' "$clt_log"; then
  printf 'headless CLT installation invoked the graphical xcode-select path:\n%s\n' "$(cat "$clt_log")" >&2
  exit 1
fi

rm -f "$clt_ready" "$clt_log"
clt_failure=$(
  CLT_LOG=$clt_log CLT_READY=$clt_ready CLT_NO_LABEL=1 sh -c '
    . "$1"
    MODE=interactive
    XCODE_SELECT=$2/clt-stubs/xcode-select
    XCRUN=$2/clt-stubs/xcrun
    SOFTWAREUPDATE=$2/clt-stubs/softwareupdate
    COMMAND_LINE_TOOLS_DIR=$2/CommandLineTools
    COMMAND_LINE_TOOLS_PLACEHOLDER=$2/clt-placeholder
    export CLT_LOG CLT_READY CLT_NO_LABEL COMMAND_LINE_TOOLS_DIR
    info() { :; }
    run_privileged() {
      shift
      "$@"
    }
    die() {
      printf "DIE:%s\n" "$*"
      exit 1
    }
    install_apple_command_line_tools
  ' sh "$TEST_ROOT/install-lib.sh" "$TEST_ROOT" 2>&1 || true
)
case $clt_failure in
  *'DIE:No compatible Apple Command Line Tools package is available through Software Update.'*) ;;
  *)
    printf 'missing CLT update did not fail closed:\n%s\n' "$clt_failure" >&2
    exit 1
    ;;
esac
[ ! -e "$TEST_ROOT/clt-placeholder" ]
if grep -q -- '--install' "$clt_log"; then
  printf 'missing CLT update invoked the graphical xcode-select path:\n%s\n' "$(cat "$clt_log")" >&2
  exit 1
fi

mkdir -p "$TEST_ROOT/root-bin" "$TEST_ROOT/root-home"
printf '#!/bin/sh\nprintf "0\\n"\n' >"$TEST_ROOT/root-bin/id"
chmod +x "$TEST_ROOT/root-bin/id"
if HOME="$TEST_ROOT/root-home" PATH="$TEST_ROOT/root-bin:/usr/bin:/bin" \
    sh "$ROOT/install.sh" non-interactive >"$TEST_ROOT/root.out" 2>&1; then
  printf 'root invocation unexpectedly succeeded\n' >&2
  exit 1
fi
grep -q 'Do not run this installer with sudo or as root' "$TEST_ROOT/root.out"
grep -q 'non-interactive' "$TEST_ROOT/root.out"

root_message=$(
  sh -c '
    . "$1"
    MODE=non-interactive
    id() { printf "0\n"; }
    die() { printf "%s\n" "$*"; exit 1; }
    check_unprivileged_invocation
  ' "$ROOT/install.sh" "$TEST_ROOT/install-lib.sh" || true
)
case $root_message in
  *"sh $ROOT/install.sh non-interactive"*) ;;
  *)
    printf 'root error did not show the correct invocation:\n%s\n' "$root_message" >&2
    exit 1
    ;;
esac

macports_log=$TEST_ROOT/macports.log
mkdir -p "$TEST_ROOT/macports/bin" "$TEST_ROOT/macports-stubs"
printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/macports/bin/port"
# shellcheck disable=SC2016
printf '#!/bin/sh\nprintf "INSTALLER:%%s\\n" "$*" >>"$MACPORTS_LOG"\n' >"$TEST_ROOT/system-installer"
printf '#!/bin/sh\nexit 0\n' >"$TEST_ROOT/macports-stubs/xcode-select"
printf '#!/bin/sh\nprintf "26.0\\n"\n' >"$TEST_ROOT/macports-stubs/sw_vers"
# shellcheck disable=SC2016
printf '#!/bin/sh\nprintf "PKGUTIL:%%s\\n" "$*" >>"$MACPORTS_LOG"\n' >"$TEST_ROOT/macports-stubs/pkgutil"
# shellcheck disable=SC2016
printf '#!/bin/sh\nprintf "SPCTL:%%s\\n" "$*" >>"$MACPORTS_LOG"\n' >"$TEST_ROOT/macports-stubs/spctl"
chmod +x \
  "$TEST_ROOT/macports/bin/port" \
  "$TEST_ROOT/system-installer" \
  "$TEST_ROOT/macports-stubs/xcode-select" \
  "$TEST_ROOT/macports-stubs/sw_vers" \
  "$TEST_ROOT/macports-stubs/pkgutil" \
  "$TEST_ROOT/macports-stubs/spctl"
MACPORTS_LOG=$macports_log sh -c '
  . "$1"
  MODE=interactive
  MACOS_ARCH=x86_64
  MACPORTS_PREFIX=$2/macports
  MACPORTS_PORT=$MACPORTS_PREFIX/bin/port
  SYSTEM_INSTALLER=$2/system-installer
  TMPDIR=$2
  PATH=$2/macports-stubs:$PATH
  export MACPORTS_LOG TMPDIR PATH
  info() { printf "INFO:%s\n" "$*" >>"$MACPORTS_LOG"; }
  curl() {
    case "$*" in
      *releases/latest*)
        printf "%s\n" "{\"browser_download_url\":\"https://github.com/macports/macports-base/releases/download/v2.12.6/MacPorts-2.12.6-26-Tahoe.pkg\"}"
        ;;
      *)
        printf "CURL:%s\n" "$*" >>"$MACPORTS_LOG"
        while [ "$#" -gt 0 ]; do
          if [ "$1" = -o ]; then
            : >"$2"
            break
          fi
          shift
        done
        ;;
    esac
  }
  run_privileged() {
    printf "PRIVILEGED:%s\n" "$1" >>"$MACPORTS_LOG"
    shift
    "$@"
  }
  apple_developer_tools_ready() { return 0; }
  install_macports
' sh "$TEST_ROOT/install-lib.sh" "$TEST_ROOT"
grep -q '^PKGUTIL:--check-signature ' "$macports_log"
grep -q '^SPCTL:--assess --type install --verbose ' "$macports_log"
grep -q '^CURL:-fL -o .*/MacPorts\.[0-9][0-9]*\.pkg -- https://github.com/' "$macports_log"
grep -q 'INSTALLER:.*-pkginfo' "$macports_log"
grep -q '^PRIVILEGED:install the verified MacPorts package into ' "$macports_log"

printf 'installer_platform_tests=ok\n'
