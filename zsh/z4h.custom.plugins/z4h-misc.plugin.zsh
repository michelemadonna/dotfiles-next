#!/usr/bin/env zsh
# Final interactive-shell customizations. Load after the other custom plugins.
alias _dig=dogggo _ping=gping _hex=hexyl _curl=http _ps=procs _top=btop
alias _ls='command ls' nodejs='command node'


if [[ ${Z4H_ENABLE_ALLAFINE:-false} == true ]]; then
  allafine() {
    zle accept-line
    print -n $'\e[9999;1H'
  }
  zle -N allafine
  bindkey '^M' allafine

  #if (( $+functions[_fzf-tab-apply] )); then
  #  functions[_zqs_orig_fzf_tab_apply]=$functions[_fzf-tab-apply]
  #  _fzf-tab-apply() {
  #    local -a prompt_lines=("${(@f)PS1}")
  #    print -n "\e[${#prompt_lines}A\e[2K\e[9999;1H"
  #    _zqs_orig_fzf_tab_apply "$@"
  #  }
  #fi
fi



if (( $+commands[fzf] )); then

  __keybinds() {
    local data
    read -r -d '' data <<'EOF'
----------------------------------------------------------------------------------
🐚 Zsh
----------------------------------------------------------------------------------
Ctrl+R                        │ Search history (fzf)
Esc Esc                       │ Insert sudo before the last command
Ctrl+T                        │ Fuzzy file path completion (fzf)
Alt+C / Esc+C                 │ cd into a selected subdirectory (fzf)
Tab                           │ Open autocomplete menu with fzf-tab
Ctrl+H                        │ Toggle hidden files in FZF search

----------------------------------------------------------------------------------
🔍 fzf
----------------------------------------------------------------------------------
↑ / ↓                         │ Move up/down
Tab                           │ Cycle selection
Ctrl+Space                    │ Mark / unmark item
Ctrl+A                        │ Toggle all marked / unmarked
Enter                         │ Select current item(s)
Ctrl+P                        │ Toggle / move preview window
Ctrl+J / K                    │ Scroll preview down / up
< / >                         │ Switch group (fzf-tab)
Ctrl+G then ?                 │ Show all available fzf-git shortcuts
Ctrl+G then F                 │ fzf-git select files
Ctrl+G then B                 │ fzf-git select branches
Ctrl+G then T                 │ fzf-git select tags
Ctrl+G then R                 │ fzf-git select remotes
Ctrl+G then H                 │ fzf-git select commit hashes
Ctrl+G then S                 │ fzf-git select stashes
Ctrl+G then L                 │ fzf-git select reflogs
Ctrl+G then W                 │ fzf-git select worktrees
Ctrl+G then E                 │ fzf-git select refs

----------------------------------------------------------------------------------
🔀 tmux
----------------------------------------------------------------------------------
Alt+A                         │ Prefix key
Prefix then C                 │ New window
Prefix then -                 │ Horizontal split
Prefix then |                 │ Vertical split
Prefix then d                 │ Detach session
Prefix then +                 │ Zoom current pane
Prefix then ↑↓←→              │ Move between panes
Prefix then Alt+Shift ↑↓←→    │ Resize panes
Prefix then R                 │ Reload tmux config
Prefix then Alt+S             │ Sync input to all panes
Prefix then Ctrl+S            │ Hide status bar

----------------------------------------------------------------------------------
✏️ micro
----------------------------------------------------------------------------------
Ctrl+O                        │ Open file
Ctrl+S                        │ Save
Ctrl+Q                        │ Quit
Ctrl+F                        │ Find
Ctrl+Z / Y                    │ Undo / Redo
Ctrl+X/C/V                    │ Cut / Copy / Paste
Ctrl+E                        │ Open command bar
Ctrl+T                        │ New tab
Alt+, / .                     │ Previous / Next tab
Ctrl+R                        │ Toggle line numbers
EOF
    print -r -- "$data" | fzf --ansi --no-multi --cycle --layout=reverse \
      --border=rounded --prompt='Keybinds ❯ ' --delimiter='│' --with-nth=1,2 \
      --preview-window=right:0%:wrap \
      --preview='echo "KEY:\n  {1}\n\nACTION:\n  {2}"'
  }
  zle -N __keybinds
  bindkey '^K' __keybinds
fi
