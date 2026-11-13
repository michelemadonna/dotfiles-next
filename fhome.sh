#!/bin/sh

TEST_HOME=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)
mkdir -p "$TEST_HOME/.cache/tmp"
mkdir -p "$TEST_HOME/.cache/run"
chmod 700 "$TEST_HOME/.cache/run"

# Keep the test shell independent from the caller's Zsh/plugin installation.
exec env -u ZGEN_DIR -u ZGENOM_DIR -u ZGEN_RESET_ON_CHANGE \
  -u ZQS_PROMPT -u ZQS_FASTFETCH_SHOWN -u QUICKSTART_KIT_REFRESH_IN_DAYS \
  -u FZF_BASE -u FZF_PATH -u FZF_DEFAULT_COMMAND -u FZF_CTRL_T_COMMAND \
  -u DEBUG \
  -u SSH_AUTH_SOCK -u SSH_AGENT_PID -u ZSH_CACHE_DIR \
  -u GITSTATUS_DAEMON -u GITSTATUS_CACHE_DIR -u ASDF_DATA_DIR \
  -u FAST_WORK_DIR -u FAST_BASE_DIR -u GENCOMPL_FPATH -u ZSH_COMPDUMP \
  -u GIT_CONFIG_GLOBAL \
  -u FZF_LOCAL_REPO -u FZF_LOCAL_BIN -u DOTSH_FZF_GIT_TRANSFER_DIR \
  -u DOTSH_FZF_GIT_TRANSFER_OWNER -u DOTSH_FZF_GIT_FZF \
  -u ITERM_SHELL_INTEGRATION_INSTALLED -u KITTY_SHELL_INTEGRATION \
  -u ITERM_INJECT_SHELL_INTEGRATION \
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
