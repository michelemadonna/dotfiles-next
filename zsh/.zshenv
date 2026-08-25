
if [[ -f ${ZDOTDIR:-$HOME}/.z4h-zprof-enabled ]]; then
  zmodload zsh/zprof
fi

if [ -n "${ZSH_VERSION-}" ]; then
  export Z4H_PROMPT=${Z4U_PROMPT:="powerlevel10k"} # powerlevel10k/ohmyposh
  export Z4H_SHOW_FASTFETCH=${Z4H_SHOW_FASTFETCH:=false} #false/true
  export Z4H_ENABLE_ALLAFINE=false
  export Z4H_USE_FZF_TAB=true
  export Z4H_ENABLE_AUTO_GENCOMP=false
  export Z4H_ENABLE_OH_MY_ZSH=true
  export Z4H_SSH_LOAD_KEY=${Z4H_SSH_LOAD_KEY:=true} #false/true
  export Z4H_SSH_SHOW_KEY=${Z4H_SSH_SHOW_KEY:=true} #false/true
  export Z4H_SSH_ASKPASS_REQUIRE=${Z4H_SSH_ASKPASS_REQUIRE:=true} #false/true

  export DOTFILES_DIR="$HOME/.dotfiles" #${DOTFILES_DIR:="$HOME/.dotfiles"} 
  export ZDOTDIR="$DOTFILES_DIR/zsh/home"


  #mkdir -p "$HOME/.cache/zsh" "$HOME/.local/state/zsh" "$HOME/.ssh"
  #ln -sfn "$DOTFILES_DIR"/{micro,git,fastfetch,mise,fresh,oh-my-posh,ghostty} "$HOME/.config/"
  #ln -sfn "$DOTFILES_DIR"/ssh/config "$HOME/.ssh/config"
  
  export HISTFILE=${HISTFILE:="$HOME/.local/state/zsh/history"}
  export ZSH_COMPDUMP=${ZSH_COMPDUMP:="$HOME/.cache/zsh/.zcompdump-${HOST}-${ZSH_VERSION}"}

  export XDG_CACHE_HOME=${XDG_CACHE_HOME:="$HOME/.cache"}
  export XDG_CONFIG_HOME=${XDG_CONFIG_HOME:="$HOME/.config"}
  export XDG_DATA_HOME=${XDG_DATA_HOME:="$HOME/.local/share"}

  . ${ZDOTDIR}/.zshenv

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

  : ${ZDOTDIR:=~}
fi



## Miscellaneous settings
#setopt INTERACTIVE_COMMENTS  # Enable comments in interactive shell.
#
#setopt extended_glob # Enable more powerful glob features
#
#

#
## Fix bracketed paste issue
## Closes #73
#ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=(bracketed-paste)
#
## Load iTerm shell integrations if found.
#test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"