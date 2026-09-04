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

macports_command=$(
  sh -c '
    . "$1"
    MODE=interactive
    MACPORTS_PORT=/opt/local/bin/port
    run_privileged() {
      shift
      printf "%s\n" "$*"
    }
    run_macports "install requested ports" install git
  ' sh "$TEST_ROOT/install-lib.sh"
)
assert_equal "$macports_command" '/opt/local/bin/port -N install git'

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
  install_macports
' sh "$TEST_ROOT/install-lib.sh" "$TEST_ROOT"
grep -q '^PKGUTIL:--check-signature ' "$macports_log"
grep -q '^SPCTL:--assess --type install --verbose ' "$macports_log"
grep -q '^CURL:-fL -o .*/MacPorts\.[0-9][0-9]*\.pkg -- https://github.com/' "$macports_log"
grep -q 'INSTALLER:.*-pkginfo' "$macports_log"
grep -q '^PRIVILEGED:install the verified MacPorts package into ' "$macports_log"

printf 'installer_platform_tests=ok\n'
