# Personal Zsh configuration file. It is strongly recommended to keep all
# shell customization and configuration (including exported environment
# variables such as PATH) in this file or in files sourced from it.
#
# Documentation: https://github.com/romkatv/zsh4humans/blob/v5/README.md.

## Yes, these are a pain to customize. Fortunately, Geoff Greer made an online
## tool that makes it easy to customize your color scheme and keep them in sync
## across Linux and OS X/*BSD at http://geoff.greer.fm/lscolors/
#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
if [[ -z ${LSCOLORS-} ]]; then
	export LSCOLORS='Exfxcxdxbxegedabagacad'
fi
if [[ -z ${LS_COLORS-} ]]; then
	export LS_COLORS='di=1;34;40:ln=35;40:so=32;40:pi=33;40:ex=31;40:bd=34;46:cd=34;43:su=0;41:sg=0;46:tw=0;42:ow=0;43:'
fi

# Fix weirdness with intellij
if [[ -z "${INTELLIJ_ENVIRONMENT_READER}" ]]; then
	export POWERLEVEL9K_INSTANT_PROMPT='quiet'
fi

## JAVA setup - needed for iam-* tools
if [ -d /Library/Java/Home ];then
	export JAVA_HOME=/Library/Java/Home
fi

if (( $+commands[rg] )); then
  export RIPGREP_CONFIG_PATH="${XDG_CONFIG_HOME}/ripgrep/ripgreprc"
fi

if (( $+commands[bat] )); then
  # Export theme for http://github.com/sharkdp/bat.
  export BAT_THEME="Solarized (dark)"
fi

if [[ -z ${TMUX:-} ]]; then
  export TERM=xterm-256color
fi
[[ -n ${TERM_PROGRAM:-} ]] || export TERM_PROGRAM=xterm

alias tmux='TERM=screen-256color-bce tmux'
typeset -g TMUX_DEFAULT_SESSION=tmux
alias t='tmux a -d -t ${TMUX_DEFAULT_SESSION} 2>/dev/null || tmux new -s ${TMUX_DEFAULT_SESSION}'

HISTORY_IGNORE="(cd ..|l[s]#( *)#|pwd *|exit *|date *|* --help)"
export FZF_COMPLETION_TRIGGER='**' # change ** to whatever you like 
#################################################################

# Periodic auto-update on Zsh startup: 'ask' or 'no'.
# You can manually run `z4h update` to update everything.
zstyle ':z4h:' auto-update      'no'
# Ask whether to auto-update this often; has no effect if auto-update is 'no'.
zstyle ':z4h:' auto-update-days '28'

# Keyboard type: 'mac' or 'pc'.
zstyle ':z4h:bindkey' keyboard  'mac'

# Don't start tmux.
zstyle ':z4h:' start-tmux       no

# Mark up shell's output with semantic information.
zstyle ':z4h:' term-shell-integration 'yes'

# Right-arrow key accepts one character ('partial-accept') from
# command autosuggestions or the whole thing ('accept')?
zstyle ':z4h:autosuggestions' forward-char 'accept'

# Recursively traverse directories when TAB-completing files.
zstyle ':z4h:fzf-complete' recurse-dirs 'no'

# Enable direnv to automatically source .envrc files.
zstyle ':z4h:direnv'         enable 'no'
# Show "loading" and "unloading" notifications from direnv.
zstyle ':z4h:direnv:success' notify 'yes'

# Enable ('yes') or disable ('no') automatic teleportation of z4h over
# SSH when connecting to these hosts.
#zstyle ':z4h:ssh:example-hostname1'   enable 'yes'
#zstyle ':z4h:ssh:*.example-hostname2' enable 'no'
# The default value if none of the overrides above match the hostname.
#zstyle ':z4h:ssh:*'                   enable 'no'

# Send these files over to the remote host when connecting over SSH to the
# enabled hosts.
#zstyle ':z4h:ssh:*' send-extra-files '~/.nanorc' '~/.env.zsh'

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:git-checkout:*' sort false
## Restore the complete Git candidate set exposed by Quickstart. z4h normally
## hides symbolic heads, recent branches and commit objects.
#zstyle -d ':completion:*:git-*:argument-rest:heads' ignored-patterns
#zstyle -d ':completion:*:git-*:argument-rest:heads-local' ignored-patterns
#zstyle -d ':completion:*:git-*:argument-rest:heads-remote' ignored-patterns
#zstyle -d ':completion:*:git-*:argument-rest:commits' ignored-patterns
#zstyle -d ':completion:*:git-*:argument-rest:commit-objects' ignored-patterns
#zstyle -d ':completion:*:git-*:argument-rest:recent-branches' ignored-patterns


if [[ ${Z4H_USE_FZF_TAB} = true ]]; then
	# These z4h components are replaced below so that their ZLE load order matches
	# the former Quickstart configuration. z4h still supplies fzf and completions.
	zstyle ':z4h:zsh-syntax-highlighting' channel none
	zstyle ':z4h:zsh-history-substring-search' channel none
	zstyle ':z4h:zsh-autosuggestions' channel none
fi


if [[ ${Z4H_PROMPT} == "ohmyposh" ]]; then
	zstyle ':z4h:powerlevel10k' channel none
else
	typeset -g POWERLEVEL9K_CONFIG_FILE="$DOTFILES_DIR/powerlevel10k/.p10k.zsh"  
fi
#################################################################




# Clone additional Git repositories from GitHub.
#
# This doesn't do anything apart from cloning the repository and keeping it
# up-to-date. Cloned files can be used after `z4h init`. This is just an
# example. If you don't plan to use Oh My Zsh, delete this line.

if [[ ${Z4H_ENABLE_OH_MY_ZSH} = true ]]; then
	z4h install ohmyzsh/ohmyzsh || return
fi

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#z4h install unixorn/jpb.zshplugin@main || return
#z4h install unixorn/warhol.plugin.zsh@main || return
#z4h install unixorn/tumult.plugin.zsh@main || return
#z4h install eventi/noreallyjustfuckingstopalready || return
#z4h install djui/alias-tips || return
#z4h install unixorn/git-extra-commands@main || return
#z4h install skx/sysadmin-util || return
#z4h install peterhurford/git-it-on.zsh || return
#z4h install StackExchange/blackbox || return
#z4h install sharat87/pip-app || return
if [[ ${Z4H_ENABLE_AUTO_GENCOMP} = true ]]; then
	z4h install RobSis/zsh-completion-generator || return #only install
fi


if [[ ${Z4H_USE_FZF_TAB} = true ]]; then
	z4h install zdharma-continuum/fast-syntax-highlighting || return
	z4h install zsh-users/zsh-history-substring-search || return
	z4h install zsh-users/zsh-autosuggestions || return
	z4h install unixorn/fzf-zsh-plugin@main || return
	z4h install Aloxaf/fzf-tab || return
fi
#################################################################

# Homebrew's native completion must be visible when z4h runs compinit. It
# provides the formula and cask candidates for `brew install`, unlike a
# completion generated from `brew --help`.
if (( $+commands[brew] )); then
	typeset _z4h_brew_prefix=${HOMEBREW_PREFIX:-${commands[brew]:A:h:h}}
	fpath=(
		$_z4h_brew_prefix/share/zsh/site-functions(N-/)
		$_z4h_brew_prefix/completions/zsh(N-/)
		$fpath
	)
	typeset -gU fpath
	unset _z4h_brew_prefix
fi

# Install or update core components (fzf, zsh-autosuggestions, etc.) and
# initialize Zsh. After this point console I/O is unavailable until Zsh
# is fully initialized. Everything that requires user interaction or can
# perform network I/O must be done above. Everything else is best done below.
z4h init || return

# Extend PATH.
path=(~/local/bin $path)

# Export environment variables.
export GPG_TTY=$TTY

# Start or reuse an SSH agent and load local private keys. Homebrew keychain is
# optional; when it isn't installed, keep the agent environment in ~/.ssh.
function load-our-ssh-keys() {
	emulate -L zsh
	setopt local_options no_unset

	local agent_file=$HOME/.ssh/ssh-agent
	local agent_status key fingerprint fingerprint_line
	local -a keys

	if (( $+commands[keychain] )); then
		eval "$(keychain -q --eval)" || return
	else
		mkdir -p -- "$HOME/.ssh" || return
		chmod 700 -- "$HOME/.ssh" 2>/dev/null

		ssh-add -l >/dev/null 2>&1
		agent_status=$?
		if (( agent_status == 2 )) && [[ -r $agent_file ]]; then
			source "$agent_file"
			ssh-add -l >/dev/null 2>&1
			agent_status=$?
		fi

		if (( agent_status == 2 )); then
			eval "$(ssh-agent -s)" >/dev/null || return
			{
				print -r -- "export SSH_AUTH_SOCK=${(q)SSH_AUTH_SOCK}"
				print -r -- "export SSH_AGENT_PID=${(q)SSH_AGENT_PID}"
			} >| "$agent_file"
			chmod 600 -- "$agent_file" 2>/dev/null
		fi
	fi

	ssh-add -l >/dev/null 2>&1
	agent_status=$?
	(( agent_status == 2 )) && return 1

	if (( agent_status == 1 )); then
		if [[ $OSTYPE == darwin* ]]; then
			if (( $+commands[sw_vers] )) && (( ${$(sw_vers -productVersion)%%.*} >= 12 )); then
				ssh-add --apple-load-keychain >/dev/null 2>&1
			else
				ssh-add -qA >/dev/null 2>&1
			fi
		fi

		keys=(~/.ssh/**/*id_(rsa|dsa|ecdsa|ed25519)(N.))
		for key in $keys; do
			fingerprint_line=$(ssh-keygen -l -f "$key" 2>/dev/null) || continue
			fingerprint=${${(z)fingerprint_line}[2]}
			[[ -n $fingerprint ]] || continue
			ssh-add -l 2>/dev/null | command grep -Fq -- "$fingerprint" ||
				ssh-add -q -- "$key"
		done
	fi
}

if [[ -o interactive && -z ${SSH_CLIENT-} && -z ${SSH_CONNECTION-} &&
      ${Z4H_SSH_LOAD_KEY:-true} != false ]]; then
	if [[ ${Z4H_SSH_ASKPASS_REQUIRE:-false} == true ]]; then
		export SSH_ASKPASS_REQUIRE=force
	fi
	load-our-ssh-keys
fi

if [[ ${Z4H_SSH_SHOW_KEY:-false} == true ]]; then
	print
	print 'Current SSH Keys:'
	ssh-add -l
	print
fi

# Source additional local files if they exist.
z4h source ~/.env.zsh

# Use additional Git repositories pulled in with `z4h install`.
#
# This is just an example that you should delete. It does nothing useful.
#z4h source ohmyzsh/ohmyzsh/lib/diagnostics.zsh  # source an individual file
#z4h load   ohmyzsh/ohmyzsh/plugins/emoji-clock  # load a plugin


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
# Oh My Zsh libraries and plugins, without sourcing oh-my-zsh.sh or running a
# second compinit/keymap setup.
if [[ ${Z4H_ENABLE_OH_MY_ZSH} = true ]]; then
	z4h source -c ohmyzsh/ohmyzsh/lib/functions.zsh
	z4h source -c ohmyzsh/ohmyzsh/lib/git.zsh
	#z4h load -c ohmyzsh/ohmyzsh/plugins/pip
	z4h load -c ohmyzsh/ohmyzsh/plugins/sudo
	#z4h load -c ohmyzsh/ohmyzsh/plugins/colored-man-pages
	#z4h load -c ohmyzsh/ohmyzsh/plugins/git
	#z4h load -c ohmyzsh/ohmyzsh/plugins/github
	#z4h load -c ohmyzsh/ohmyzsh/plugins/python
	#z4h load -c ohmyzsh/ohmyzsh/plugins/rsync
	#z4h load -c ohmyzsh/ohmyzsh/plugins/screen
	z4h load -c ohmyzsh/ohmyzsh/plugins/command-not-found
	if [[ $OSTYPE == darwin* ]]; then
		z4h load -c ohmyzsh/ohmyzsh/plugins/brew
		z4h load -c ohmyzsh/ohmyzsh/plugins/macos
	fi
fi

if [[ ${Z4H_USE_FZF_TAB} = true ]]; then
	# fzf-zsh-plugin provides its helpers while z4h remains the sole fzf install.
	export FZF_PATH="${XDG_CACHE_HOME}/zsh4humans/v5/fzf"
	z4h load -c unixorn/fzf-zsh-plugin
	# fzf-tab must wrap the stock completion widget, not z4h-fzf-complete.
	bindkey '^I' expand-or-complete
	z4h load -c Aloxaf/fzf-tab
	
	z4h source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-fzf.plugin.zsh"
fi

#z4h source -c unixorn/jpb.zshplugin/jpb.plugin.zsh
#z4h source -c unixorn/warhol.plugin.zsh/warhol.plugin.zsh
#z4h source -c unixorn/tumult.plugin.zsh/tumult.plugin.zsh
#
#z4h load -c eventi/noreallyjustfuckingstopalready
#z4h load -c djui/alias-tips
#z4h load -c unixorn/git-extra-commands
#compdef _git git
#z4h load -c skx/sysadmin-util
#z4h source -c peterhurford/git-it-on.zsh/git-it-on.plugin.zsh
#z4h load -c StackExchange/blackbox
#z4h source -c sharat87/pip-app/pip-app.sh

# Local plugins. The last file applies final widget and environment settings.
z4h source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-eza.plugin.zsh"
z4h source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-misc.plugin.zsh"
z4h source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-containers.plugin.zsh"
z4h source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-mise.plugin.zsh"

if [[ ${Z4H_ENABLE_AUTO_GENCOMP} = true ]]; then
	z4h source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-gencomp-lazy.plugin.zsh"
fi

if [[ "${Z4H_PROMPT}" == "ohmyposh" ]]; then
	export Z4H_OH_MY_POSH_CONFIG=${Z4H_OH_MY_POSH_CONFIG:="$HOME/.config/oh-my-posh/custom.omp.json"}
	z4h source "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-oh-my-posh.plugin.zsh"
	z4h-init-oh-my-posh
fi

if [[ ${Z4H_USE_FZF_TAB} = true ]]; then
	# Plugins that wrap ZLE widgets are deliberately loaded last.
	z4h load -c zdharma-continuum/fast-syntax-highlighting
	z4h load -c zsh-users/zsh-history-substring-search
	z4h load -c zsh-users/zsh-autosuggestions

	#bindkey '^I' fzf_tab_no_space_after_at
fi

#################################################################

# Define key bindings.
z4h bindkey undo Ctrl+/               # undo the last command line change
z4h bindkey redo Option+/            # redo the last undone command line change

z4h bindkey z4h-cd-back    Shift+Left   # cd into the previous directory
z4h bindkey z4h-cd-forward Shift+Right  # cd into the next directory
z4h bindkey z4h-cd-up      Shift+Up     # cd into the parent directory
z4h bindkey z4h-cd-down    Shift+Down   # cd into a child directory


#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
z4h bindkey up-history Up
z4h bindkey down-history Down

# Make an interrupted command line visibly distinct from an executed command.
TRAPINT() {
	print -n -u2 '^C'
	return $((128 + $1))
}


#################################################################

# Autoload functions.
autoload -Uz zmv

# Define functions and completions.
function md() {
	[[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" 
}
compdef _directories md

# Define named directories: ~w <=> Windows home directory on WSL.
[[ -z $z4h_win_home ]] || hash -d w=$z4h_win_home

# Define aliases.
alias tree='tree -a -I .git'

# Add flags to existing aliases.
alias ls="${aliases[ls]:-ls} -A"

# Set shell options: http://zsh.sourceforge.net/Doc/Release/Options.html.
setopt glob_dots     # no special treatment for file names with a leading dot
setopt no_auto_menu  # require an extra TAB press to open the completion menu

#++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
setopt AUTO_CD  # If a command is issued that can’t be executed as a normal command,
								# and the command is the name of a directory, perform the cd command
								# to that directory.
setopt AUTO_PARAM_SLASH  # If completed parameter is a directory, add a trailing slash.
setopt COMPLETE_IN_WORD  # Complete from both ends of a word.
setopt pushd_ignore_dups
setopt interactive_comments

## Long running processes should return time after they complete. Specified
## in seconds.
REPORTTIME=${REPORTTIME:-2}

TIMEFMT="%U user %S system %P cpu %*Es total"

# deal with screen, if we're using it - courtesy MacOSXHints.com
# Login greeting ------------------
if [ "$TERM" = "screen" -a ! "$SHOWED_SCREEN_MESSAGE" = "true" ]; then
	detached_screens=$(screen -list | grep Detached)
	if [ ! -z "$detached_screens" ]; then
		echo "+---------------------------------------+"
		echo "| Detached screens are available:       |"
		echo "$detached_screens"
		echo "+---------------------------------------+"
	fi
fi


print -n $'\e[9999;1H'

if [[ -o interactive && ${Z4H_SHOW_FASTFETCH:-false} == true && -z ${Z4H_FASTFETCH_SHOWN:-} ]]; then
	# Exported markers are inherited by nested shells and tmux children, so
	# Fastfetch is displayed only once for the terminal/session.
	export Z4H_FASTFETCH_SHOWN=1
	if (( $+commands[fastfetch] )); then
		parent_cmd=$(ps -o comm= -p $PPID 2>/dev/null)
		case "${parent_cmd:l}" in
			*zed*|*code*|*micro*|*nvim*|*vim*|*idea*|*clion*|*goland*|*phpstorm*|*pycharm*|*tmux*|*fresh*|*helix*|*terminal*) ;;
			*) fastfetch --pipe false ;;
		esac
		unset parent_cmd
	else
		print -u2 "fastfetch not found. See $DOTFILES_DIR/Readme.md"
	fi
fi

if [[ -f ${ZDOTDIR:-$HOME}/.z4h-zprof-enabled ]]; then
  zprof
fi
#################################################################
