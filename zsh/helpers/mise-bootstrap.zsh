install-mise-bootstrap() {
if [[ $Z4H_USE_MISE = true ]] && ! command -v mise >/dev/null 2>&1; then
  mkdir -p -- "$HOME/.local/bin" "$XDG_DATA_HOME" 2>/dev/null || true
  if [[ $OSTYPE == darwin* ]] && (( $+commands[brew] )); then
    command brew install -y mise >/dev/null 2>&1 || true
  elif [[ $OSTYPE == linux* ]] && (( $+commands[curl] )); then
    export MISE_INSTALL_PATH="$HOME/.local/bin/mise"
    command curl -fsSL https://mise.run 2>/dev/null | sh >/dev/null 2>&1 || true
  fi
fi
}
