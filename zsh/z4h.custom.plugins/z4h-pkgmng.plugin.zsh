#!/usr/bin/env zsh

# Load the MacPorts/Homebrew coexistence layer only on Intel macOS when both
# package managers are installed.
if [[ $OSTYPE == darwin* && $(uname -m) == x86_64 ]] &&
	[[ -x ${HOMEBREW_BREW:-/usr/local/bin/brew} ]] &&
	[[ -x ${MACPORTS_PREFIX:-/opt/local}/bin/port ]]; then

	source "$DOTFILES_DIR/zsh/helpers/pkgmng"
fi
