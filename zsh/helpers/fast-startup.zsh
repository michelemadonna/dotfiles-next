#!/usr/bin/env zsh

# Opt-in startup path. The default profile deliberately keeps the existing
# z4h/fzf load order in zsh/home/.zshrc.

emulate -L zsh

typeset -g Z4H_FAST_FZF_LOADED=${Z4H_FAST_FZF_LOADED:-false}
typeset -g Z4H_FAST_GENCOMP_LOADED=${Z4H_FAST_GENCOMP_LOADED:-false}
typeset -g Z4H_FAST_ZLE_LOADED=${Z4H_FAST_ZLE_LOADED:-false}

z4h_fast_prepare_fzf() {
	emulate -L zsh
	local fzf_repo=${FZF_LOCAL_REPO:-$HOME/.local/share/fzf}
	local fzf_bin=${FZF_LOCAL_BIN:-$HOME/.local/bin/fzf}

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

z4h_fast_load_fzf() {
	emulate -L zsh
	[[ $Z4H_FAST_FZF_LOADED == true ]] && return 0

	z4h_fast_prepare_fzf || {
		print -u2 -r -- 'fast startup: local fzf is unavailable; run install.sh to repair it.'
		return 1
	}

	local fzf_bindings=$FZF_PATH/shell/key-bindings.zsh
	[[ -r $fzf_bindings ]] || {
		print -u2 -r -- "fast startup: missing fzf key bindings: $fzf_bindings"
		return 1
	}

	if [[ ! -d $Z4H/Aloxaf/fzf-tab ]]; then
		z4h install Aloxaf/fzf-tab || return 1
	fi

	source "$fzf_bindings"
	bindkey '^I' expand-or-complete
	z4h load -c Aloxaf/fzf-tab || return 1

	if [[ ${Z4H_FZF_GIT_VENDOR_LOADED:-false} != true ]]; then
		typeset -g Z4H_FZF_GIT_VENDOR_LOADED=true
		z4h source --compile "$DOTFILES_DIR/zsh/vendor/fzf-git.sh" || return 1
	fi
	z4h source --compile "$DOTFILES_DIR/zsh/helpers/fzf-git.zsh" || return 1
	z4h source --compile "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-fzf.plugin.zsh" || return 1

	typeset -g Z4H_FAST_FZF_LOADED=true
	return 0
}

z4h_fast_load_gencomp() {
	emulate -L zsh
	[[ $Z4H_FAST_GENCOMP_LOADED == true ]] && return 0

	z4h_fast_load_fzf || return 1
	if [[ ! -d $Z4H/RobSis/zsh-completion-generator ]]; then
		z4h install RobSis/zsh-completion-generator || return 1
	fi
	z4h source --compile "$DOTFILES_DIR/zsh/z4h.custom.plugins/z4h-gencomp-lazy.plugin.zsh" || return 1
	typeset -g Z4H_FAST_GENCOMP_LOADED=true
}

z4h_fast_load_zle_features() {
	emulate -L zsh
	[[ $Z4H_FAST_ZLE_LOADED == true ]] && return 0

	if [[ ! -d $Z4H/zdharma-continuum/fast-syntax-highlighting ]]; then
		z4h install zdharma-continuum/fast-syntax-highlighting || return 1
	fi
	if [[ ! -d $Z4H/zsh-users/zsh-history-substring-search ]]; then
		z4h install zsh-users/zsh-history-substring-search || return 1
	fi
	z4h load -c zdharma-continuum/fast-syntax-highlighting || return 1
	z4h load -c zsh-users/zsh-history-substring-search || return 1

	typeset -g Z4H_FAST_ZLE_LOADED=true
	return 0
}

_z4h_fast_fzf_tab_widget() {
	z4h_fast_load_fzf || {
		zle expand-or-complete
		return
	}
	if (( $+widgets[_fzf_tab_complete_with_dots] )); then
		zle _fzf_tab_complete_with_dots
	else
		zle expand-or-complete
	fi
}

_z4h_fast_fzf_history_widget() {
	z4h_fast_load_fzf || return
	(( $+widgets[fzf-history-widget] )) && zle fzf-history-widget
}

_z4h_fast_fzf_file_widget() {
	z4h_fast_load_fzf || return
	(( $+widgets[_z4h_fzf_file_widget] )) && zle _z4h_fzf_file_widget
}

_z4h_fast_fzf_cd_widget() {
	z4h_fast_load_fzf || return
	(( $+widgets[_z4h_fzf_cd_widget] )) && zle _z4h_fzf_cd_widget
}

_z4h_fast_fzf_git_widget() {
	z4h_fast_load_fzf || return
	(( $+widgets[_z4h_fzf_git_prefix_widget] )) && zle _z4h_fzf_git_prefix_widget
}

_z4h_fast_gencomp_widget() {
	z4h_fast_load_gencomp || return
	(( $+widgets[_zqs_gencomp_for_current_command] )) &&
		zle _zqs_gencomp_for_current_command
}

zle -N _z4h_fast_fzf_tab_widget
zle -N _z4h_fast_fzf_history_widget
zle -N _z4h_fast_fzf_file_widget
zle -N _z4h_fast_fzf_cd_widget
zle -N _z4h_fast_fzf_git_widget
zle -N _z4h_fast_gencomp_widget

for _z4h_fast_keymap in emacs viins vicmd; do
	bindkey -M $_z4h_fast_keymap '^I' _z4h_fast_fzf_tab_widget
	bindkey -M $_z4h_fast_keymap '^R' _z4h_fast_fzf_history_widget
	bindkey -M $_z4h_fast_keymap '^T' _z4h_fast_fzf_file_widget
	bindkey -M $_z4h_fast_keymap '^[c' _z4h_fast_fzf_cd_widget
	bindkey -M $_z4h_fast_keymap '^G' _z4h_fast_fzf_git_widget
	bindkey -M $_z4h_fast_keymap '^[[Z' _z4h_fast_gencomp_widget
done
unset _z4h_fast_keymap

z4h_fast_zle_line_init() {
	z4h_fast_load_zle_features
}

zle -N zle-line-init z4h_fast_zle_line_init
