#!/bin/sh

TEST_HOME=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd -P)

# Keep the test shell independent from the caller's Zsh/plugin installation.
env -u ZGEN_DIR -u ZGENOM_DIR -u ZGEN_RESET_ON_CHANGE \
  -u ZQS_PROMPT -u ZQS_FASTFETCH_SHOWN -u QUICKSTART_KIT_REFRESH_IN_DAYS \
  -u FZF_BASE -u FZF_PATH -u FZF_DEFAULT_COMMAND -u FZF_CTRL_T_COMMAND \
  -u DEBUG \
  HOME="$TEST_HOME" \
  ZDOTDIR="$TEST_HOME" \
  XDG_CACHE_HOME="$TEST_HOME/.cache" \
  XDG_CONFIG_HOME="$TEST_HOME/.config" \
  XDG_DATA_HOME="$TEST_HOME/.local/share" \
  MISE_IGNORED_CONFIG_PATHS="/Users/$USER/.config/mise/config.toml" \
  PATH="/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin" \
  /bin/zsh -d -l
