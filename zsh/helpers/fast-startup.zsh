#!/usr/bin/env zsh

# Opt-in startup path. The default profile deliberately keeps the existing
# standalone/fzf load order in zsh/home/.zshrc.

emulate -L zsh

typeset -g DOTSH_FAST_FZF_LOADED=${DOTSH_FAST_FZF_LOADED:-false}
typeset -g DOTSH_FAST_GENCOMP_LOADED=${DOTSH_FAST_GENCOMP_LOADED:-false}
typeset -g DOTSH_FAST_ZLE_LOADED=${DOTSH_FAST_ZLE_LOADED:-false}

dotsh_fast_prepare_fzf() {
	emulate -L zsh
	local fzf_repo=${FZF_LOCAL_REPO:-$DOTSH_PACKAGES/fzf}
	local fzf_bin=${FZF_LOCAL_BIN:-$DOTSH_PACKAGES/fzf/bin/fzf}

	if [[ -x $fzf_bin && -r $fzf_repo/shell/key-bindings.zsh ]]; then
		typeset -g FZF_LOCAL_BIN=$fzf_bin
		typeset -g FZF_PATH=$fzf_repo
	elif [[ -x $fzf_repo/bin/fzf && -r $fzf_repo/shell/key-bindings.zsh ]]; then
		fzf_bin=$fzf_repo/bin/fzf
		typeset -g FZF_LOCAL_BIN=$fzf_bin
		typeset -g FZF_PATH=$fzf_repo
	else
		return 1
	fi

	path=("${fzf_bin:h}" $path)
	typeset -gU path PATH
	rehash
	[[ -x $fzf_bin ]]
}

dotsh_fast_load_fzf() {
	emulate -L zsh
	[[ $DOTSH_FAST_FZF_LOADED == true ]] && return 0

	dotsh_fast_prepare_fzf || {
		print -u2 -r -- 'fast startup: local fzf is unavailable; run install.sh to repair it.'
		return 1
	}

	local fzf_bindings=$FZF_PATH/shell/key-bindings.zsh
	[[ -r $fzf_bindings ]] || {
		print -u2 -r -- "fast startup: missing fzf key bindings: $fzf_bindings"
		return 1
	}

	[[ -d $DOTSH_PACKAGES/fzf-tab ]] || { print -u2 -- "Missing prepared dependency: $DOTSH_PACKAGES/fzf-tab"; return 1; }

	source "$fzf_bindings"
	bindkey '^I' expand-or-complete
	dotsh_load -c "$DOTSH_PACKAGES/fzf-tab" || return 1

	if [[ ${DOTSH_FZF_GIT_VENDOR_LOADED:-false} != true ]]; then
		typeset -g DOTSH_FZF_GIT_VENDOR_LOADED=true
		dotsh_source --compile "$DOTFILES_DIR/zsh/vendor/fzf-git.sh" || return 1
	fi
	dotsh_source --compile "$DOTFILES_DIR/zsh/helpers/fzf-git.zsh" || return 1
	dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-fzf.plugin.zsh" || return 1

	typeset -g DOTSH_FAST_FZF_LOADED=true
	return 0
}

dotsh_fast_load_gencomp() {
	emulate -L zsh
	[[ $DOTSH_FAST_GENCOMP_LOADED == true ]] && return 0

	dotsh_fast_load_fzf || return 1
	[[ -d $DOTSH_PACKAGES/zsh-completion-generator ]] || { print -u2 -- "Missing prepared dependency: $DOTSH_PACKAGES/zsh-completion-generator"; return 1; }
	dotsh_source --compile "$DOTFILES_DIR/zsh/dotsh.custom.plugins/dotsh-gencomp-lazy.plugin.zsh" || return 1
	typeset -g DOTSH_FAST_GENCOMP_LOADED=true
}

dotsh_fast_load_zle_features() {
	emulate -L zsh
	[[ $DOTSH_FAST_ZLE_LOADED == true ]] && return 0

	[[ -d $DOTSH_PACKAGES/fast-syntax-highlighting ]] || { print -u2 -- "Missing prepared dependency: $DOTSH_PACKAGES/fast-syntax-highlighting"; return 1; }
	[[ -d $DOTSH_PACKAGES/zsh-history-substring-search ]] || { print -u2 -- "Missing prepared dependency: $DOTSH_PACKAGES/zsh-history-substring-search"; return 1; }
	dotsh_load_highlighting || return 1
	dotsh_load -c "$DOTSH_PACKAGES/zsh-history-substring-search" || return 1

	typeset -g DOTSH_FAST_ZLE_LOADED=true
	return 0
}

_dotsh_fast_fzf_tab_widget() {
	dotsh_fast_load_fzf || {
		zle expand-or-complete
		return
	}
	if (( $+widgets[_fzf_tab_complete_with_dots] )); then
		zle _fzf_tab_complete_with_dots
	else
		zle expand-or-complete
	fi
}

_dotsh_fast_fzf_history_widget() {
	dotsh_fast_load_fzf || return
	(( $+widgets[fzf-history-widget] )) && zle fzf-history-widget
}

_dotsh_fast_fzf_file_widget() {
	dotsh_fast_load_fzf || return
	(( $+widgets[_dotsh_fzf_file_widget] )) && zle _dotsh_fzf_file_widget
}

_dotsh_fast_fzf_cd_widget() {
	dotsh_fast_load_fzf || return
	(( $+widgets[_dotsh_fzf_cd_widget] )) && zle _dotsh_fzf_cd_widget
}

_dotsh_fast_fzf_git_widget() {
	dotsh_fast_load_fzf || return
	(( $+widgets[_dotsh_fzf_git_prefix_widget] )) && zle _dotsh_fzf_git_prefix_widget
}

_dotsh_fast_gencomp_widget() {
	dotsh_fast_load_gencomp || return
	(( $+widgets[_zqs_gencomp_for_current_command] )) &&
		zle _zqs_gencomp_for_current_command
}

zle -N _dotsh_fast_fzf_tab_widget
zle -N _dotsh_fast_fzf_history_widget
zle -N _dotsh_fast_fzf_file_widget
zle -N _dotsh_fast_fzf_cd_widget
zle -N _dotsh_fast_fzf_git_widget
zle -N _dotsh_fast_gencomp_widget

for _dotsh_fast_keymap in emacs viins vicmd; do
	bindkey -M $_dotsh_fast_keymap '^I' _dotsh_fast_fzf_tab_widget
	bindkey -M $_dotsh_fast_keymap '^R' _dotsh_fast_fzf_history_widget
	bindkey -M $_dotsh_fast_keymap '^T' _dotsh_fast_fzf_file_widget
	bindkey -M $_dotsh_fast_keymap '^[c' _dotsh_fast_fzf_cd_widget
	bindkey -M $_dotsh_fast_keymap '^G' _dotsh_fast_fzf_git_widget
	bindkey -M $_dotsh_fast_keymap '^[[Z' _dotsh_fast_gencomp_widget
done
unset _dotsh_fast_keymap

# The runtime owns zle-line-init, preserving direct prompt dispatch.
# It clears this first-use callback after success and retries failed loading.
typeset -g DOTSH_LINE_INIT_ONCE=dotsh_fast_load_zle_features
