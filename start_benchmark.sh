#!/usr/bin/env bash
#tmp=$(mktemp)
#curl -fsSL https://raw.githubusercontent.com/romkatv/zsh4humans/v5/install > "$tmp"
#</dev/tty >/dev/tty 2>/dev/tty sh "$tmp"
#rm -f "$tmp"
[[ -d ~/zsh-bench ]] || git clone https://github.com/romkatv/zsh-bench ~/zsh-bench
~/zsh-bench/zsh-bench | tee ~/current-zsh.benc