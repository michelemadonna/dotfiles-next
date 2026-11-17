#!/bin/sh

TEST_HOME=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
# Create isolated directories.
mkdir -p \
    "$TEST_HOME/.cache/run" \
    "$TEST_HOME/.cache/tmp" \
    "$TEST_HOME/.cache/mise" \
    "$TEST_HOME/.config/mise" \
    "$TEST_HOME/.local/share/mise" \
    "$TEST_HOME/.local/state"

# Start Zsh with a clean, isolated environment.
exec env -i \
    MANPATH="${MANPATH-}" \
    GHOSTTY_RESOURCES_DIR="${GHOSTTY_RESOURCES_DIR-}" \
    TERM_PROGRAM="${TERM_PROGRAM-}" \
    GHOSTTY_SURFACE_ID="${GHOSTTY_SURFACE_ID-}" \
    TERM="${TERM-xterm-256color}" \
    SHELL="/bin/zsh" \
    TERM_PROGRAM_VERSION="${TERM_PROGRAM_VERSION-}" \
    USER="${USER-}" \
    COMMAND_MODE="${COMMAND_MODE-}" \
    SSH_AUTH_SOCK="${SSH_AUTH_SOCK-}" \
    __CF_USER_TEXT_ENCODING="${__CF_USER_TEXT_ENCODING-}" \
    GHOSTTY_SHELL_FEATURES="${GHOSTTY_SHELL_FEATURES-}" \
    __CFBundleIdentifier="${__CFBundleIdentifier-}" \
    LANG="${LANG-en_US.UTF-8}" \
    XPC_FLAGS="${XPC_FLAGS-}" \
    XPC_SERVICE_NAME="${XPC_SERVICE_NAME-}" \
    TERMINFO="${TERMINFO-}" \
    LOGNAME="${LOGNAME-}" \
    XDG_DATA_DIRS="${XDG_DATA_DIRS-}" \
    GHOSTTY_BIN_DIR="${GHOSTTY_BIN_DIR-}" \
    OSLogRateLimit="${OSLogRateLimit-}" \
    COLORTERM="${COLORTERM-}" \
    HOME="$TEST_HOME" \
    DOTFILES_FAKE_HOME="$TEST_HOME" \
    ZDOTDIR="$TEST_HOME" \
    XDG_CACHE_HOME="$TEST_HOME/.cache" \
    XDG_CONFIG_HOME="$TEST_HOME/.config" \
    XDG_DATA_HOME="$TEST_HOME/.local/share" \
    XDG_STATE_HOME="$TEST_HOME/.local/state" \
    XDG_RUNTIME_DIR="$TEST_HOME/.cache/run" \
    HISTFILE="$TEST_HOME/.zsh_history" \
    TMPDIR="$TEST_HOME/.cache/tmp" \
    TMPPREFIX="$TEST_HOME/.cache/tmp/zsh" \
    MISE_CACHE_DIR="$TEST_HOME/.cache/mise" \
    MISE_DATA_DIR="$TEST_HOME/.local/share/mise" \
    MISE_GLOBAL_CONFIG_FILE="$TEST_HOME/.config/mise/config.toml" \
    MISE_IGNORED_CONFIG_PATHS="/Users/$USER/.config/mise/config.toml" \
    PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin" \
    /bin/zsh -d -l
