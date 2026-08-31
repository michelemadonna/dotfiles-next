run-fastfetch() {

	if [[ -o interactive && ${Z4H_SHOW_FASTFETCH:-false} != false && -z ${Z4H_FASTFETCH_SHOWN:-} ]]; then
	export Z4H_FASTFETCH_SHOWN=1
	show_fastfetch=true

	if [[ $Z4H_SHOW_FASTFETCH == first ]]; then
		active_terminals=$(ps -axo tty= 2>/dev/null | awk '
			$1 ~ /^ttys[0-9]+$/ || $1 ~ /^pts\/[0-9]+$/ { seen[$1] = 1 }
			END { for (tty in seen) count++; print count + 0 }
		')
		(( active_terminals <= 1 )) || show_fastfetch=false
	fi
	if [[ $show_fastfetch == true ]] && (( $+commands[fastfetch] )); then
		parent_cmd=$(ps -o comm= -p $PPID 2>/dev/null)
		case "${parent_cmd:l}" in
			*zed*|*code*|*micro*|*nvim*|*vim*|*idea*|*clion*|*goland*|*phpstorm*|*pycharm*|*tmux*|*fresh*|*helix*|*terminal*) ;;
			*) fastfetch --pipe false ;;
		esac
		unset parent_cmd
	elif [[ $show_fastfetch == true ]]; then
		print -u2 "fastfetch not found. See $DOTFILES_DIR/Readme.md"
	fi
		unset active_terminals show_fastfetch
	fi
}
