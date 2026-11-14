# Load runtime defaults first. Keep personal settings below so they override
# framework defaults before dotsh_init consumes completion and prompt styles.
source "$DOTFILES_DIR/zsh/runtime/dotsh-startup.zsh" || return

# Put framework overrides here, before dotsh_init consumes runtime styles.
# General local shell commands can also go in ~/.env.zsh, sourced below.

[[ $DOTSH_PROMPT != ohmyposh ]] || zstyle ':dotsh:powerlevel10k' channel none

# Plugin and integration loading stays grouped here. Preserve the phase order:
# package-manager paths before dotsh_init, completion/widgets after it.
dotsh_source -c "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-pkgmng.plugin.zsh"

dotsh_init || return

(( $+commands[python3] )) && alias python='command python3'

compdef _directories md
_dotsh_register_brew_completions

# User overrides load before optional and local plugins.
[[ ! -r $HOME/.env.zsh ]] || dotsh_source "$HOME/.env.zsh"

# Optional Oh My Zsh libraries/plugins, without sourcing oh-my-zsh.sh or
# running a second compinit/keymap setup.
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

dotsh_source -c "$DOTFILES_DIR/zsh/helpers/fast-startup.zsh"

# Repository plugins; misc applies the final widget and environment settings.
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-git.plugin.zsh"
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-eza.plugin.zsh"
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-misc.plugin.zsh"
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-containers.plugin.zsh"
if [[ ${DOTSH_USE_MISE} = true ]]; then
	dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-mise.plugin.zsh"
fi

if [[ "${DOTSH_PROMPT}" == "ohmyposh" ]]; then
	export DOTSH_OH_MY_POSH_CONFIG=${DOTSH_OH_MY_POSH_CONFIG:="$HOME/.config/oh-my-posh/custom.omp.json"}
	dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-oh-my-posh.plugin.zsh"
	dotsh-init-oh-my-posh
fi

print -n $'\e[9999;1H'
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-fastfetch.plugin.zsh"

# SSH is the final plugin: it handles optional key loading and display after
# all other startup integrations have run.
dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-ssh.plugin.zsh"

# Apply framework keybinding defaults after plugin bindings. Add user-specific
# keybindings below this call to override them.
dotsh_bind_default_keys

# Add flags to existing aliases.
alias ls="${aliases[ls]:-ls} -A"
ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste)

if [[ -f ${HOME}/.dotsh-zprof-enabled ]]; then
  zprof
fi
