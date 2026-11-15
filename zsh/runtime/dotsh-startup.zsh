# Standalone startup policy extracted from the upstream v5 runtime.
# Source first in .zshrc; user overrides and plugin setup follow before dotsh_init.
# Runtime attribution and license: zsh/runtime/LICENSE.
[[ -z ${_DOTSH_STARTUP_LOADED-} ]] || return 0
typeset -g _DOTSH_STARTUP_LOADED=1

emulate zsh
setopt always_to_end auto_cd auto_param_slash auto_pushd c_bases auto_menu \
  extended_glob extended_history hist_expire_dups_first hist_find_no_dups \
  hist_ignore_dups hist_ignore_space hist_verify interactive_comments multios \
  no_aliases no_bg_nice no_flow_control no_prompt_bang no_prompt_subst \
  prompt_cr prompt_percent prompt_sp share_history typeset_silent \
  hist_save_no_dups no_auto_remove_slash no_list_types no_beep
# Effective overrides from the reference .zshrc.
setopt glob_dots no_auto_menu complete_in_word pushd_ignore_dups no_global_rcs

typeset -g DOTSH_RUNTIME="$DOTFILES_DIR/zsh/runtime"
typeset -g DOTSH_PACKAGES="$DOTFILES_DIR/zsh/vendor/packages"
export DOTSH_USE_FZF=${DOTSH_USE_FZF:-true}
typeset -g DOTSH_CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
typeset -g DOTSH_STATE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh"
typeset -gr _dotsh_opt='emulate -L zsh &&
  setopt typeset_silent pipe_fail extended_glob prompt_percent no_prompt_subst &&
  setopt no_prompt_bang no_bg_nice no_aliases'
if [[ $EUID == 0 && ! -O $HOME && $DOTSH_CACHE == $HOME/* ]]; then
  typeset -gri _dotsh_dangerous_root=1
else
  typeset -gri _dotsh_dangerous_root=0
fi
if [[ -n ${ZSH_SCRIPT+X}${ZSH_EXECUTION_STRING+X} ]]; then
  typeset -gri _dotsh_zle=0
else
  typeset -gri _dotsh_zle=1
fi
typeset -gri _dotsh_custom_histfile=${${HISTFILE:+1}:-0}
if [[ -x /proc/self/exe ]]; then
  typeset -gr _dotsh_exe=${${:-/proc/self/exe}:A}
elif (( ! _dotsh_zle )) && [[ ${DOTSH_EXE:-} == /* && -x $DOTSH_EXE ]]; then
  # In a child script $0 names the script, not Zsh. The parent runtime exports
  # its resolved executable for these noninteractive preparation/check paths.
  typeset -gr _dotsh_exe=${DOTSH_EXE:A}
else
  () {
    emulate zsh -o posix_argzero -c 'local exe=${0#-}'
    if [[ $SHELL == /* && ${SHELL:t} == $exe && -x $SHELL ]]; then
      exe=$SHELL
    elif (( $+commands[$exe] )); then
      exe=$commands[$exe]
    elif [[ -x $exe ]]; then
      exe=${exe:a}
    else
      print -u2 -- 'dotsh: cannot determine the current Zsh executable'
      return 1
    fi
    typeset -gr _dotsh_exe=${exe:A}
  } || return
fi

zmodload zsh/{datetime,langinfo,parameter,system,terminfo,zutil,zselect} || return
zmodload -F zsh/files b:{zf_mkdir,zf_mv,zf_rm,zf_rmdir,zf_ln} || return
zmodload -F zsh/stat b:zstat || return
zf_mkdir -m 0700 -p -- "$DOTSH_CACHE" "$DOTSH_CACHE/tmp" "$DOTSH_STATE" || return

export -T MANPATH=${MANPATH:-:} manpath
export -T INFOPATH=${INFOPATH:-:} infopath
typeset -gaU cdpath fpath mailpath path manpath infopath
fpath+=("$DOTSH_RUNTIME/fn")
autoload -Uz -- "$DOTSH_RUNTIME"/fn/[^.]#~*.zwc(N:t)
functions -Ms _dotsh_err
# Declare redraw state once; line-init can reset it with plain assignments.
typeset -g _ZSH_HIGHLIGHT_PRIOR_BUFFER=
typeset -gi _ZSH_HIGHLIGHT_PRIOR_CURSOR=0
typeset -gi _dotsh_terminal_dirty=1

# Environment preparation precedes caller package-manager and fpath setup,
# matching the original bootstrap order without loading the framework.
() {
  if [[ $OSTYPE == darwin* ]]; then
    [[ -r $DOTSH_CACHE/init-darwin-paths ]] && source "$DOTSH_CACHE/init-darwin-paths" || {
      -dotsh-gen-init-darwin-paths && source "$DOTSH_CACHE/init-darwin-paths"
    }
  elif [[ $OSTYPE == linux-* && -r /proc/version && ( -v commands[cmd.exe] || -e /mnt/c/Windows/System32/cmd.exe ) ]]; then
    -dotsh-init-wsl
  fi
  # Keep Homebrew's environment and package-manager manuals available without
  # launching brew shellenv or path_helper on every shell startup.
  if [[ -z ${HOMEBREW_PREFIX:-} ]]; then
    local -a brew_bins=(/opt/homebrew/bin/brew(N) /usr/local/bin/brew(N)
      /home/linuxbrew/.linuxbrew/bin/brew(N) "$HOME"/.linuxbrew/bin/brew(N))
    if (( $#brew_bins )); then
      export HOMEBREW_PREFIX=${brew_bins[1]:h:h}
    fi
  fi
  if [[ -n ${HOMEBREW_PREFIX:-} ]]; then
    export HOMEBREW_CELLAR="$HOMEBREW_PREFIX/Cellar"
    if [[ -e $HOMEBREW_PREFIX/Homebrew/Library ]]; then
      export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX/Homebrew"
    else
      export HOMEBREW_REPOSITORY="$HOMEBREW_PREFIX"
    fi
    local -a candidates=("$HOMEBREW_PREFIX/bin" "$HOMEBREW_PREFIX/sbin")
    path=(${candidates:|path} $path)
  fi
  local -a candidates=(/opt/local/sbin(N-/) /opt/local/bin(N-/)
    /usr/local/sbin(N-/) /usr/local/bin(N-/))
  path=(${candidates:|path} $path)
  manpath=(${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/man}(-/N)
    /opt/local/share/man(-/N) $manpath '')
  infopath=(${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/info}(-/N)
    /opt/local/share/info(-/N) $infopath '')
}

# Preserve the original source/wordcode pairing and +1-second mtime contract.
# .zwc files are derived artifacts; never edit or commit them as source.
dotsh_source() {
  local file compile=0
  if [[ ${1-} == (-c|--compile) ]]; then compile=1; shift; fi
  [[ ${1-} != -- ]] || shift
  for file in "$@"; do
    if [[ $file != /* || ! -r $file ]]; then
      print -ru2 -- "dotsh: missing source: $file"
      return 1
    fi
    # A read-only checkout must still run without compiled artifacts.
    (( ! compile )) || -dotsh-compile "$file" || true
    builtin source -- "$file" || return
  done
}

# Explicit dependency preparation can precompile the autoload tree once.
# Shell startup only autoloads functions; it does not recompile every file.
dotsh_prepare_runtime() {
  local file
  for file in "$DOTSH_RUNTIME"/fn/[^.]#~*.zwc(N); do
    -dotsh-compile "$file" || return
  done
  for file in "$DOTFILES_DIR/zsh/runtime/dotsh-startup.zsh" \
      "$DOTFILES_DIR/zsh/home/.zshrc" "$DOTFILES_DIR/zsh/.zshenv.init"; do
    -dotsh-compile "$file" || return
  done
}

dotsh_load() {
  local requested directory entry
  local -a flags reply
  if [[ ${1-} == (-c|--compile) ]]; then flags=(-c); shift; fi
  [[ ${1-} != -- ]] || shift
  for requested in "$@"; do
    directory=$requested
    if [[ ! -d $directory ]]; then
      (( $+functions[dotsh_resolve_package] )) ||
        builtin source "$DOTFILES_DIR/zsh/helpers/shell-packages.zsh" || return
      dotsh_resolve_package "$requested" || return
      directory=$reply[1]
      if [[ ! -d $directory ]]; then
        directory=$(dotsh_prepare_package "$requested") || return
      fi
    fi
    [[ -d $directory ]] || { print -ru2 -- "dotsh: missing plugin: $directory"; return 1; }
    directory=${directory:a}
    fpath+=("$directory" "$directory"/functions(N-/))
    local -a funcs=("$directory"/functions/^([_.]*|prompt_*_setup|README*|*~|*.zwc)(N-.:t))
    (( ! $#funcs )) || autoload -Uz -- $funcs
    if [[ -r $directory/init.zsh ]]; then
      entry=$directory/init.zsh
    elif [[ -r $directory/${directory:t}.plugin.zsh ]]; then
      entry=$directory/${directory:t}.plugin.zsh
    elif [[ -r $directory/${directory:t}.zsh ]]; then
      entry=$directory/${directory:t}.zsh
    else
      print -ru2 -- "dotsh: missing plugin entrypoint: $directory"
      return 1
    fi
    dotsh_source "${flags[@]}" "$entry" || return
  done
}

dotsh_bindkey() { -dotsh-cmd-bindkey "$@" }

dotsh_bind_default_keys() {
  dotsh_bindkey undo Ctrl+/
  dotsh_bindkey redo Option+/
  dotsh_bindkey dotsh-cd-back Shift+Left
  dotsh_bindkey dotsh-cd-forward Shift+Right
  dotsh_bindkey dotsh-cd-up Shift+Up
  dotsh_bindkey up-history Up
  dotsh_bindkey down-history Down
}

# Select abstract key names from the keyboard layout, independently of the OS.
# The platform supplies a default; an Apple keyboard on Linux can override it.
dotsh_configure_keyboard() {
  local keyboard=${DOTSH_KEYBOARD:-}
  case $keyboard in
    '')
      if [[ $OSTYPE == darwin* ]]; then keyboard=mac; else keyboard=pc; fi
      ;;
    mac|pc) ;;
    *) print -ru2 -- 'dotsh: DOTSH_KEYBOARD must be mac or pc'; return 1 ;;
  esac
  zstyle ':dotsh:bindkey' keyboard "$keyboard"
}

# FSH uses the runtime's coalesced redraw instead of wrapping every widget and
# highlighting the same buffer again during zle-line-pre-redraw. Keep isearch
# notifications, which happen outside that redraw path.
dotsh_load_highlighting() {
  () {
    local -hA widgets=(
      zle-line-finish user:_zsh_highlight_widget_zle-line-finish
      zle-isearch-update user:_zsh_highlight_widget_zle-isearch-update
    )
    dotsh_load -c "$DOTSH_PACKAGES/fast-syntax-highlighting"
  } || return
  if (( $+widgets[zle-isearch-update] )); then
    zle -A zle-isearch-update -dotsh-orig-isearch-update
  fi
  zle -N zle-isearch-update -dotsh-isearch-update
}

function -dotsh-isearch-update() {
  if (( $+widgets[-dotsh-orig-isearch-update] )); then
    zle -- -dotsh-orig-isearch-update "$@"
  fi
  _zsh_highlight
}

dotsh_init() {
  [[ -z ${_DOTSH_INITIALIZED-} ]] || { print -ru2 -- 'dotsh: use exec zsh instead of sourcing .zshrc again'; return 1; }
  typeset -g _DOTSH_INITIALIZED=1
  autoload -Uz add-zsh-hook
  export LESS='-iRFXMx4'
  (( ! $+commands[less] )) || export PAGER=less
  if (( $+commands[lesspipe] || $+commands[lesspipe.sh] )); then
    export LESSOPEN="| /usr/bin/env ${(q)${commands[lesspipe]:-${commands[lesspipe.sh]}}} %s 2>/dev/null"
  fi
  export LS_COLORS='fi=00:mi=00:mh=00:ln=01;36:or=01;31:di=01;34:ow=04;01;34:st=34:tw=04;34:'
  LS_COLORS+='pi=01;33:so=01;33:do=01;33:bd=01;33:cd=01;33:su=01;35:sg=01;35:ca=01;35:ex=01;32'
  export LSCOLORS='ExGxDxDxCxDxDxFxFxexEx'
  export TREE_COLORS=${LS_COLORS//04;}
  [[ $langinfo[CODESET] == (utf|UTF)(-|)8 ]] || -dotsh-fix-locale
  [[ -n $COLORTERM || $terminfo[Tc] != yes ]] || export COLORTERM=truecolor
  [[ $TERMINFO == ~/.terminfo || ! -e ~/.terminfo/$TERM[1]/$TERM ]] || export TERMINFO=~/.terminfo
  (( ! $+commands[less] )) || READNULLCMD=less
  (( $+commands[less] || ! $+commands[more] )) || READNULLCMD=more
  (( $+commands[less] || $+commands[more] || ! $+commands[cat] )) || READNULLCMD=cat
  : ${DIRSTACKSIZE:=10000}
  : ${ZLE_RPROMPT_INDENT:=0}
  # The daemon is an explicitly prepared dependency, retained across cache resets.
  export GITSTATUS_CACHE_DIR="$DOTSH_PACKAGES/powerlevel10k/gitstatus/usrbin"
  export GITSTATUS_AUTO_INSTALL=0
  typeset -g ZSH="$DOTSH_PACKAGES/ohmyzsh"
  typeset -g ZSH_CUSTOM="$ZSH/custom"
  typeset -g ZSH_CACHE_DIR="$DOTSH_CACHE/ohmyzsh"
  zf_mkdir -m 0700 -p -- "$ZSH_CACHE_DIR" "$DOTSH_CACHE/powerlevel10k" || return
  fpath=(
    ${^${(M)fpath:#*/$ZSH_VERSION/functions}/%$ZSH_VERSION\/functions/site-functions}(-/N)
    ${HOMEBREW_PREFIX:+$HOMEBREW_PREFIX/share/zsh/site-functions}(-/N)
    /opt/homebrew/share/zsh/site-functions(-/N)
    /usr{/local,}/share/zsh/{site-functions,vendor-completions}(-/N)
    $fpath)
  path=(~/bin(N-/) ~/.local/bin(N-/) ~/.cargo/bin(N-/) $path /snap/bin(N-/))
  export DOTSH_EXE=$_dotsh_exe
  if [[ ${commands[zsh]:-} != $_dotsh_exe ]]; then
    path=("$DOTSH_RUNTIME/bin" $path)
  fi
  typeset -gaU path fpath
  if [[ -w $TTY ]]; then
    typeset -gi _dotsh_tty_fd
    sysopen -o cloexec -rwu _dotsh_tty_fd -- "$TTY" || return
  elif [[ -w /dev/tty ]]; then
    typeset -gi _dotsh_tty_fd
    sysopen -o cloexec -rwu _dotsh_tty_fd -- /dev/tty 2>/dev/null || unset _dotsh_tty_fd
  fi
  # Standalone p10k owns its screen management. Runtime terminal metadata uses
  # direct OSC output; no tmux process, socket, bootstrap, or teleportation.
  typeset -gri _dotsh_can_save_restore_screen=0
  if (( _dotsh_zle )); then
    local -a required
    local pkg
    for pkg in powerlevel10k zsh-autosuggestions; do
      zstyle -t :dotsh:$pkg channel none || required+=($pkg)
    done
    for pkg in $required; do
      [[ -d $DOTSH_PACKAGES/$pkg ]] || { print -ru2 -- "dotsh: required dependency missing: $pkg; prepare dependencies before startup"; return 1; }
    done
    if ! zstyle -t :dotsh:powerlevel10k channel none; then
      local user=${(%):-%n}
      local instant="$DOTSH_CACHE/powerlevel10k/p10k-instant-prompt-$user.zsh"
      [[ ! -r $instant ]] || source "$instant"
    fi
    -dotsh-init-zle || return
  else
    function compdef() {}
    function complete() {}
  fi
  function compinit() {}
  function bashcompinit() {}
  [[ ${dotsh_no_flock:-0} == 1 ]] || setopt hist_fcntl_lock
  if (( $+commands[dircolors] )); then
    [[ ${${:-diff}:c:A:t} == busybox* ]] || alias diff='diff --color=auto'
    [[ ${${:-ls}:c:A:t} == busybox* ]] || alias ls='ls --color=auto'
  else
    [[ ${${:-ls}:c:A:t} == busybox* ]] || alias ls='ls -G'
  fi
  [[ ${${:-grep}:c:A:t} == busybox* ]] || alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn}'
}
setopt aliases

# Framework defaults. Because this file is sourced before the user's .zshrc
# layer, later assignments and zstyles can override these values.
if [[ -o interactive ]]; then
  dotsh_configure_keyboard || return
  zstyle ':dotsh:' term-shell-integration yes
  zstyle ':dotsh:autosuggestions' forward-char accept
  if [[ $DOTSH_USE_FZF == true ]]; then
    zstyle ':dotsh:fzf-complete' recurse-dirs no
  fi
  zstyle ':dotsh:compinit' dump-path "$DOTSH_CACHE/zcompdump-${EUID}-${ZSH_VERSION}"
  zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
  zstyle ':completion:*:descriptions' format '[%d]'
  zstyle ':completion:*:git-checkout:*' sort false

  # General shell defaults migrated from the repository's former .zshrc.
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

  if [[ $TERM == screen && ${SHOWED_SCREEN_MESSAGE:-} != true ]]; then
    typeset detached_screens=$(screen -list 2>/dev/null | grep Detached)
    if [[ -n $detached_screens ]]; then
      print -r -- '+---------------------------------------+' '| Detached screens are available:       |' "$detached_screens" '+---------------------------------------+'
    fi
    unset detached_screens
  fi

  export GPG_TTY=$TTY
  autoload -Uz zmv

  function md() {
    [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1"
  }

  [[ -z $dotsh_win_home ]] || hash -d w=$dotsh_win_home
  alias tree='tree -a -I .git'

  setopt glob_dots no_auto_menu complete_in_word pushd_ignore_dups interactive_comments
  REPORTTIME=${REPORTTIME:-2}
  TIMEFMT="%U user %S system %P cpu %*Es total"

  TRAPINT() {
    print -n -u2 '^C'
    return $((128 + $1))
  }
fi
