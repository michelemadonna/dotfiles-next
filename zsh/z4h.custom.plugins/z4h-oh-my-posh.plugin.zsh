#!/usr/bin/env zsh

if (( ! $+commands[oh-my-posh] )); then
  echo "oh-my-posh not found. Please refer to $DOTFILES_DIR/README.md for installation instructions."
  return
fi



typeset -g Z4H_OMP_PLUGIN_FILE="${(%):-%x}"

_z4h_omp_generate_init_cache() {
  emulate -L zsh
  setopt local_options err_return

  local omp_binary=$1
  local config_file=$2
  local cache_file=$3
  local cache_tmp="${cache_file}.${$}.tmp"
  local init_command init_file secondary_eval line
  local -i replacements=0

  init_command=$(command "$omp_binary" init zsh --config "$config_file") || return
  if [[ $init_command != *'source '* ]]; then
    print -u2 -r -- "oh-my-posh: unsupported init output; using the standard loader"
    return 1
  fi

  init_file=${(Q)${init_command##*source }}
  [[ -r $init_file ]] || return 1
  secondary_eval=$(command "$omp_binary" print secondary --shell=zsh --eval --config "$config_file") || return

  {
    print -r -- 'zmodload zsh/datetime 2>/dev/null'
    print -r -- "printf -v POSH_SESSION_ID '%08x-%04x-%04x-%04x-%04x%08x' \$(( (RANDOM << 16) | RANDOM )) \$RANDOM \$RANDOM \$RANDOM \$RANDOM \$(( (RANDOM << 16) | RANDOM ))"
    print -r -- 'export POSH_SESSION_ID'
    print -r -- "export POSH_CONFIG=${(qqq)config_file}"

    while IFS= read -r line || [[ -n $line ]]; do
      case $line in
        'eval "$($_omp_executable print secondary --shell=zsh --eval)"')
          print -r -- "$secondary_eval"
          (( ++replacements ))
          ;;
        *)
          print -r -- "$line"
          ;;
      esac
    done < "$init_file"
  } >| "$cache_tmp" || {
    command rm -f -- "$cache_tmp"
    return 1
  }

  if (( replacements != 1 )) || ! command zsh -n "$cache_tmp"; then
    command rm -f -- "$cache_tmp"
    return 1
  fi

  command mv -f -- "$cache_tmp" "$cache_file"
}

z4h-init-oh-my-posh() {
  emulate -L zsh

  local omp_binary=${commands[oh-my-posh]}
  local config_file=$Z4H_OH_MY_POSH_CONFIG
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
  local config_key=${config_file:A}
  config_key=${config_key//\//_}
  config_key=${config_key//[^A-Za-z0-9_.-]/_}
  local cache_file="$cache_dir/oh-my-posh-init-${ZSH_VERSION}-${config_key}.zsh"
  local rebuild=false

  if [[ ! -s $cache_file || $omp_binary -nt $cache_file || \
        $config_file -nt $cache_file || $Z4H_OMP_PLUGIN_FILE -nt $cache_file ]]; then
    rebuild=true
  fi

  if [[ $rebuild == true ]]; then
    [[ -d $cache_dir ]] || command mkdir -p -- "$cache_dir"
    _z4h_omp_generate_init_cache "$omp_binary" "$config_file" "$cache_file" || {
      eval "$(command "$omp_binary" init zsh --config "$config_file")"
      return
    }
  fi

  source "$cache_file"
}
