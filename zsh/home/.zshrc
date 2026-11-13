# Load the extracted startup options and performance runtime first.
source "$DOTFILES_DIR/zsh/dotsh-startup.zsh" || return

path=("$HOME/.local/bin" $path)
typeset -gU path PATH
if [[ ${_DOTSH_PATH_SNAPSHOT-} != "$PATH" ]]; then
  rehash
  typeset -g _DOTSH_PATH_SNAPSHOT="$PATH"
fi
[[ -n ${TMUX:-} ]] || export TERM=xterm-256color
[[ -n ${TERM_PROGRAM:-} ]] || export TERM_PROGRAM=xterm
alias tmux='TERM=screen-256color-bce tmux'
typeset -g TMUX_DEFAULT_SESSION=tmux
alias t='tmux a -d -t ${TMUX_DEFAULT_SESSION} 2>/dev/null || tmux new -s ${TMUX_DEFAULT_SESSION}'

dotsh_configure_keyboard || return
zstyle ':dotsh:' term-shell-integration yes
zstyle ':dotsh:autosuggestions' forward-char accept
zstyle ':dotsh:fzf-complete' recurse-dirs no
zstyle ':dotsh:compinit' dump-path "$XDG_CACHE_HOME/zsh/zcompdump-${EUID}-${ZSH_VERSION}"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false

if [[ $DOTSH_STARTUP_PROFILE == fast ]]; then
  zstyle ':dotsh:fzf' channel none
fi
if [[ $DOTSH_USE_FZF_TAB == true ]]; then
  zstyle ':dotsh:zsh-syntax-highlighting' channel none
  zstyle ':dotsh:zsh-history-substring-search' channel none
fi
[[ $DOTSH_PROMPT != ohmyposh ]] || zstyle ':dotsh:powerlevel10k' channel none

dotsh_source -c "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-pkgmng.plugin.zsh"
if (( $+commands[brew] )) || [[ -x ${HOMEBREW_BREW:-} ]]; then
  typeset _dotsh_brew_prefix=${HOMEBREW_PREFIX:-${commands[brew]:A:h:h}}
  fpath=($_dotsh_brew_prefix/share/zsh/site-functions(N-/) $_dotsh_brew_prefix/completions/zsh(N-/) $fpath)
  unset _dotsh_brew_prefix
fi
# Keep fpath stable while completion initialization and ZLE loading overlap.
fpath=("$DOTSH_PACKAGES/fast-syntax-highlighting" "$DOTSH_PACKAGES/zsh-history-substring-search" $fpath)
typeset -gU fpath
source "$DOTFILES_DIR/zsh/helpers/ssh.zsh"
if [[ -o interactive && -z ${SSH_CLIENT-} && -z ${SSH_CONNECTION-} &&
      ${DOTSH_SSH_LOAD_KEY:-true} != false ]]; then
  [[ ${DOTSH_SSH_ASKPASS_REQUIRE:-false} != true ]] || export SSH_ASKPASS_REQUIRE=force
  load-our-ssh-keys
fi
if [[ $TERM == screen && ${SHOWED_SCREEN_MESSAGE:-} != true ]]; then
  typeset detached_screens=$(screen -list 2>/dev/null | grep Detached)
  if [[ -n $detached_screens ]]; then
    print -r -- '+---------------------------------------+' '| Detached screens are available:       |' "$detached_screens" '+---------------------------------------+'
  fi
  unset detached_screens
fi
source "$DOTFILES_DIR/zsh/helpers/fastfetch.zsh"
dotsh_init || return

# A cached compinit dump can predate Homebrew's addition to fpath. Register
# its native completion explicitly so formula/cask candidates and the
# brew-install fzf-tab context are available without clearing user caches.
if (( $+commands[brew] )) || [[ -x ${HOMEBREW_BREW:-} ]]; then
	autoload -Uz _brew
	typeset -gA _comps
	_comps[brew]=_brew
fi
if (( $+functions[_pkgmgr_setup_completions] )); then
	_pkgmgr_setup_completions
fi

if (( $+commands[git] )); then
	# Homebrew's _git delegates to Bash completion and drops the grouped refs,
	# recent commits and descriptions provided by macOS's native Zsh completion.
	if [[ $OSTYPE == darwin* ]]; then
		typeset _dotsh_native_git_completion=/usr/share/zsh/$ZSH_VERSION/functions/_git
		if [[ -r $_dotsh_native_git_completion ]]; then
			unfunction _git 2>/dev/null
			autoload -Uz -R "$_dotsh_native_git_completion"
			compdef _git git gitk
		fi
		unset _dotsh_native_git_completion
	fi

	# Restore the full Git candidate set after runtime initialization.
	zstyle -d ':completion:*:git-*:argument-rest:heads' ignored-patterns
	zstyle -d ':completion:*:git-*:argument-rest:heads-local' ignored-patterns
	zstyle -d ':completion:*:git-*:argument-rest:heads-remote' ignored-patterns
	zstyle -d ':completion:*:git-*:argument-rest:commits' ignored-patterns
	zstyle -d ':completion:*:git-*:argument-rest:commit-objects' ignored-patterns
	zstyle -d ':completion:*:git-*:argument-rest:recent-branches' ignored-patterns
fi

# Export environment variables.
export GPG_TTY=$TTY

# Source additional local files if they exist.
[[ ! -r $HOME/.env.zsh ]] || dotsh_source "$HOME/.env.zsh"

# Oh My Zsh libraries and plugins, without sourcing oh-my-zsh.sh or running a
# second compinit/keymap setup.
if [[ ${DOTSH_ENABLE_OH_MY_ZSH} = true ]]; then
	dotsh_source -c "$DOTSH_PACKAGES/ohmyzsh/lib/functions.zsh"
	dotsh_source -c "$DOTSH_PACKAGES/ohmyzsh/lib/git.zsh"
	dotsh_load -c "$DOTSH_PACKAGES/ohmyzsh/plugins/sudo"
	dotsh_load -c "$DOTSH_PACKAGES/ohmyzsh/plugins/command-not-found"
	if [[ $OSTYPE == darwin* ]]; then
	dotsh_load -c "$DOTSH_PACKAGES/ohmyzsh/plugins/brew"
	dotsh_load -c "$DOTSH_PACKAGES/ohmyzsh/plugins/macos"
	fi
fi

if [[ ${DOTSH_USE_FZF_TAB} = true && ${DOTSH_STARTUP_PROFILE} != fast ]]; then
	# Use the explicitly prepared independent fzf checkout.
	export FZF_PATH="${FZF_PATH:=$DOTSH_PACKAGES/fzf}"
	dotsh_source -c "$FZF_PATH/shell/key-bindings.zsh"
	# fzf-tab wraps the stock completion widget.
	bindkey '^I' expand-or-complete
	dotsh_load -c "$DOTSH_PACKAGES/fzf-tab"

	if [[ ${DOTSH_FZF_GIT_VENDOR_LOADED:-false} != true ]]; then
		typeset -g DOTSH_FZF_GIT_VENDOR_LOADED=true
		dotsh_source --compile "$DOTFILES_DIR/zsh/vendor/fzf-git.sh"
	fi
	dotsh_source --compile "$DOTFILES_DIR/zsh/helpers/fzf-git.zsh"
	dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-fzf.plugin.zsh"
fi

if [[ ${DOTSH_USE_FZF_TAB} = true && ${DOTSH_STARTUP_PROFILE} == fast ]]; then
	dotsh_source -c "$DOTFILES_DIR/zsh/helpers/fast-startup.zsh"
fi

#

# Local plugins. The last file applies final widget and environment settings.
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-eza.plugin.zsh"
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-misc.plugin.zsh"
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-containers.plugin.zsh"
if [[ ${DOTSH_USE_MISE} = true ]]; then
	dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-mise.plugin.zsh"
fi

if [[ ${DOTSH_ENABLE_AUTO_GENCOMP} = true && ${DOTSH_STARTUP_PROFILE} != fast ]]; then
	dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-gencomp-lazy.plugin.zsh"
fi

if [[ "${DOTSH_PROMPT}" == "ohmyposh" ]]; then
	export DOTSH_OH_MY_POSH_CONFIG=${DOTSH_OH_MY_POSH_CONFIG:="$HOME/.config/oh-my-posh/custom.omp.json"}
	dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-oh-my-posh.plugin.zsh"
	dotsh-init-oh-my-posh
fi

if [[ ${DOTSH_USE_FZF_TAB} = true && ${DOTSH_STARTUP_PROFILE} != fast ]]; then
	# Plugins that wrap ZLE widgets are deliberately loaded last.
	dotsh_load_highlighting
	dotsh_load -c "$DOTSH_PACKAGES/zsh-history-substring-search"

	#bindkey '^I' fzf_tab_no_space_after_at
fi

# Define key bindings.
dotsh_bindkey undo Ctrl+/               # undo the last command line change
dotsh_bindkey redo Option+/            # redo the last undone command line change

dotsh_bindkey dotsh-cd-back    Shift+Left   # cd into the previous directory
dotsh_bindkey dotsh-cd-forward Shift+Right  # cd into the next directory
dotsh_bindkey dotsh-cd-up      Shift+Up     # cd into the parent directory
dotsh_bindkey dotsh-cd-down    Shift+Down   # cd into a child directory

dotsh_bindkey up-history Up
dotsh_bindkey down-history Down

# Make an interrupted command line visibly distinct from an executed command.
TRAPINT() {
	print -n -u2 '^C'
	return $((128 + $1))
}

# Autoload functions.
autoload -Uz zmv

# Define functions and completions.
function md() {
	[[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" 
}
compdef _directories md

# Define named directories: ~w <=> Windows home directory on WSL.
[[ -z $dotsh_win_home ]] || hash -d w=$dotsh_win_home

# Define aliases.
alias tree='tree -a -I .git'

# Add flags to existing aliases.
alias ls="${aliases[ls]:-ls} -A"

# Set shell options: http://zsh.sourceforge.net/Doc/Release/Options.html.
setopt glob_dots     		# no special treatment for file names with a leading dot
setopt no_auto_menu  		# require an extra TAB press to open the completion menu

setopt AUTO_CD  			# If a command is issued that can’t be executed as a normal command,
							# and the command is the name of a directory, perform the cd command
							# to that directory.
setopt AUTO_PARAM_SLASH		# If completed parameter is a directory, add a trailing slash.
setopt COMPLETE_IN_WORD		# Complete from both ends of a word.
setopt pushd_ignore_dups
setopt interactive_comments

## Long running processes should return time after they complete. Specified
## in seconds.
REPORTTIME=${REPORTTIME:-2}

TIMEFMT="%U user %S system %P cpu %*Es total"

# Fix bracketed paste issue
# Closes #73
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste)

print -n $'\e[9999;1H'
run-fastfetch

if [[ ${DOTSH_SSH_SHOW_KEY:-false} == true ]]; then
	print
	print 'Current SSH Keys:'
	if (( ${_ZQS_SSH_KEYS_VALID:-0} )) && (( ${_ZQS_SSH_KEYS_STATUS:-2} == 0 )); then
		print -r -- "$_ZQS_SSH_KEYS"
	else
		ssh-add -l
	fi
	print
fi
unset _ZQS_SSH_KEYS _ZQS_SSH_KEYS_STATUS _ZQS_SSH_KEYS_VALID


if [[ -f ${HOME}/.dotsh-zprof-enabled ]]; then
  zprof
fi
