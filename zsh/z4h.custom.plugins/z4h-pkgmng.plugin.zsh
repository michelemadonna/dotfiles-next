#!/usr/bin/env zsh

# Load the MacPorts-primary coexistence layer only on Intel macOS when
# MacPorts is selected and both package managers are installed.
if [[ ${DOTFILES_INTEL_PACKAGE_MANAGER:-macports} == macports ]] &&
	[[ $OSTYPE == darwin* && $(uname -m) == x86_64 ]] &&
	[[ -x ${HOMEBREW_BREW:-/usr/local/bin/brew} ]] &&
	[[ -x ${MACPORTS_PREFIX:-/opt/local}/bin/port ]]; then

	source "$DOTFILES_DIR/zsh/helpers/pkgmng"
fi
