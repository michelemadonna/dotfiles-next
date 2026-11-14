# Preserve the native macOS Git completion, which includes grouped refs,
# recent commits and descriptions that Homebrew's Bash-backed completion omits.
if (( $+commands[git] )); then
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
