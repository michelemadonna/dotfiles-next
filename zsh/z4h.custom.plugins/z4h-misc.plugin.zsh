#!/usr/bin/env zsh
# Final interactive-shell customizations. Load after the other custom plugins.
alias _dig=dogggo _ping=gping _hex=hexyl _curl=http _ps=procs _top=btop
alias _ls='command ls' nodejs='command node'

z4h-reset-zsh-cache() {
  emulate -L zsh
  setopt extended_glob

  local dry_run=false assume_yes=false restart=true
  local argument answer target

  for argument in "$@"; do
    case $argument in
      --dry-run) dry_run=true ;;
      -y|--yes) assume_yes=true ;;
      --no-restart) restart=false ;;
      -h|--help)
        print -r -- 'Usage: z4h-reset-zsh-cache [--dry-run] [--yes] [--no-restart]'
        return 0
        ;;
      *)
        print -u2 -r -- "z4h-reset-zsh-cache: unknown option: $argument"
        return 2
        ;;
    esac
  done

  if [[ -z ${HOME:-} || $HOME != /* ]]; then
    print -u2 -r -- 'z4h-reset-zsh-cache: refusing to use an empty or relative HOME'
    return 1
  fi

  local home_dir=${HOME:A}
  local cache_home=${XDG_CACHE_HOME:-$home_dir/.cache}
  local state_home=${XDG_STATE_HOME:-$home_dir/.local/state}
  local temporary_dir=${TMPDIR:-/tmp}

  if [[ $cache_home != /* || $state_home != /* ]]; then
    print -u2 -r -- 'z4h-reset-zsh-cache: XDG cache and state paths must be absolute'
    return 1
  fi

  cache_home=${cache_home:A}
  state_home=${state_home:A}
  temporary_dir=${temporary_dir:A}

  if [[ $cache_home == / || $state_home == / ||
        $cache_home == $home_dir || $state_home == $home_dir ]]; then
    print -u2 -r -- 'z4h-reset-zsh-cache: refusing an unsafe cache or state root'
    return 1
  fi

  local expected_z4h_root="$cache_home/zsh4humans/v5"
  local z4h_root=${Z4H:-$expected_z4h_root}
  if [[ ${z4h_root:A} != ${expected_z4h_root:A} ]]; then
    print -u2 -r -- "z4h-reset-zsh-cache: refusing unexpected Z4H path: $z4h_root"
    return 1
  fi

  local dotfiles_dir=${DOTFILES_DIR:-$home_dir/.dotfiles}
  if [[ $dotfiles_dir != /* || ${dotfiles_dir:A} == / ||
        ! -r ${dotfiles_dir:A}/zsh/z4h.custom.plugins/z4h-misc.plugin.zsh ]]; then
    print -u2 -r -- "z4h-reset-zsh-cache: refusing unexpected dotfiles path: $dotfiles_dir"
    return 1
  fi
  dotfiles_dir=${dotfiles_dir:A}

  local -aU targets
  local -a directory_targets
  directory_targets=(
    "$cache_home/zsh"
    "$expected_z4h_root"
    "$state_home/zsh/fzf-tab"
    "$state_home/dotfiles-next"
  )

  for target in "${directory_targets[@]}"; do
    [[ -e $target || -L $target ]] && targets+=("$target")
  done

  targets+=(
    "$home_dir"/.zcompdump*(N.)
    "$home_dir/.ssh/ssh-agent"(N.)
    "$dotfiles_dir"/**/*.zwc(N.)
    "$dotfiles_dir"/**/.*.zwc(N.)
    "$temporary_dir"/fzf-tab-hidden-*(N.U)
  )

  print -r -- 'dotfiles-next cache and state targets:'
  if (( ${#targets} )); then
    for target in "${targets[@]}"; do
      print -r -- "  - $target"
    done
  else
    print -r -- '  - no files currently exist'
  fi

  print -u2 -r -- 'This preserves shell history and removes the installer package marker.'
  print -u2 -r -- 'The next Zsh startup needs network access to download z4h again.'
  print -u2 -r -- 'The saved SSH agent environment is removed; the running agent is not stopped.'

  [[ $dry_run == true ]] && return 0

  if [[ $assume_yes != true ]]; then
    print -n -u2 -r -- 'Continue? [y/N] '
    IFS= read -r answer || return 1
    case ${answer:l} in
      y|yes) ;;
      *)
        print -r -- 'Cleanup cancelled.'
        return 1
        ;;
    esac
  fi

  local -i failed=0
  for target in "${targets[@]}"; do
    if command rm -rf -- "$target"; then
      print -r -- "Removed: $target"
    else
      print -u2 -r -- "Failed to remove: $target"
      failed=1
    fi
  done
  (( failed )) && return 1

  if [[ $restart == true ]]; then
    print -r -- 'Cleanup complete; restarting Zsh...'
    exec "${commands[zsh]:-/bin/zsh}" -l
  fi

  print -r -- 'Cleanup complete. Run: exec zsh -l'
}


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
Ctrl+K                        │ Open the searchable keybinding reference
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
Ctrl+F                        │ Cycle fzf height: 33%, 50%, 66%, 99% prompt-safe
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
