install-fzf-bootstrap() {
if [[ ${Z4H_USE_FZF_FROM_Z4H} = false ]]; then
  # Use a current fzf build independently of Homebrew, APT, and z4h.
  export FZF_LOCAL_REPO="$XDG_DATA_HOME/fzf"
  export FZF_LOCAL_BIN="$HOME/.local/bin/fzf"
  export FZF_PATH="$FZF_LOCAL_REPO"

  if [[ ! -x "$FZF_LOCAL_BIN" && -n ${commands[git]-} && -n ${commands[make]-} ]]; then
    mkdir -p -- "$XDG_DATA_HOME" "$HOME/.local/bin" 2>/dev/null || true
    if [[ ! -d "$FZF_LOCAL_REPO/.git" ]]; then
      command git clone --depth=1 https://github.com/junegunn/fzf.git "$FZF_LOCAL_REPO" >/dev/null 2>&1 || true
    fi
    if [[ -d "$FZF_LOCAL_REPO/.git" ]]; then
      command make -C "$FZF_LOCAL_REPO" >/dev/null 2>&1 || true
      [[ -x "$FZF_LOCAL_REPO/bin/fzf" ]] && command cp -- "$FZF_LOCAL_REPO/bin/fzf" "$FZF_LOCAL_BIN" 2>/dev/null || true
    fi
  fi
fi
}
