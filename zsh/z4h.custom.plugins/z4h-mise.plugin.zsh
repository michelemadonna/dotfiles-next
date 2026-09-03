#!/usr/bin/env zsh
# mise plugin for zsh
# this plugin integrates mise (https://github.com/mise/mise) into zsh shell

# TODO: 2024-01-03 remove rtx support
local __mise=mise
if (( ! $+commands[mise] )); then
  if (( $+commands[rtx] )); then
    __mise=rtx
  else
    return
  fi
fi

#this is needed by powerlevel10k to show the mise segment using asdf segment configuration
export ASDF_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/asdf"

# Cache mise's static activation script. The sourced script still installs the
# normal precmd/chpwd hook, so hook-env keeps running when the environment may
# have changed.
local mise_binary=${commands[$__mise]}
local mise_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
local mise_activate_cache="$mise_cache_dir/${__mise}-activate-lazy.zsh"
local mise_activate_tmp="$mise_activate_cache.${$}.tmp"
local mise_activate_raw_tmp="$mise_activate_cache.${$}.raw"
local mise_initial_hook_deferred=0
local -a mise_path_before_activation=($path)

if [[ ! -s $mise_activate_cache || $mise_binary -nt $mise_activate_cache ]]; then
  [[ -d $mise_cache_dir ]] || command mkdir -p "$mise_cache_dir"
  if command "$mise_binary" --quiet activate zsh >| "$mise_activate_raw_tmp"; then
    while IFS= read -r line; do
      # Keep the hook function and its precmd/chpwd registration, but defer
      # the initial hook-env call until the first prompt.
      [[ $line == _mise_hook ]] && continue
      print -r -- "$line"
    done < "$mise_activate_raw_tmp" >| "$mise_activate_tmp"
    command mv -f "$mise_activate_tmp" "$mise_activate_cache"
    command rm -f "$mise_activate_raw_tmp"
  else
    command rm -f "$mise_activate_tmp"
    command rm -f "$mise_activate_raw_tmp"
  fi
fi

if [[ -s $mise_activate_cache ]]; then
  source "$mise_activate_cache"
  mise_initial_hook_deferred=1
else
  eval "$(command "$mise_binary" --quiet activate zsh)"
fi

# `mise activate` embeds the PATH from cache-generation time. Keep its shims
# first, but do not let a cache prepared by the installer discard paths added
# later by shell startup (notably ~/.local/bin and Homebrew on macOS).
path=(${path:|mise_path_before_activation} $mise_path_before_activation)
typeset -gU path PATH
rehash

typeset -ga precmd_functions chpwd_functions
if (( $+functions[_mise_hook_precmd] && $+functions[_mise_hook_chpwd] )); then
  # Current Mise already prevents chpwd from being followed by a duplicate
  # precmd refresh. Use its hooks directly instead of adding a second pair.
  precmd_functions=(${precmd_functions:#_zqs_mise_precmd_hook})
  chpwd_functions=(${chpwd_functions:#_zqs_mise_chpwd_hook})
  unfunction _zqs_mise_precmd_hook _zqs_mise_chpwd_hook 2>/dev/null

  # The cached activation omits Mise's initial hook-env call. Its generated
  # first-prompt fast path assumes that call already happened, so bypass that
  # fast path once and let the native hook initialize the environment.
  (( mise_initial_hook_deferred )) && typeset -gx __MISE_ZSH_PRECMD_RUN=1

  # Avoid starting Mise for every prompt when nothing relevant changed. Keep
  # chpwd immediate, refresh after every Mise command, detect PATH changes,
  # and retain a short periodic check for externally edited configs or env.
  zmodload zsh/datetime
  local mise_refresh_seconds=${Z4H_MISE_REFRESH_SECONDS:-5}
  [[ $mise_refresh_seconds == <-> ]] || mise_refresh_seconds=5
  typeset -gi _ZQS_MISE_REFRESH_SECONDS=$mise_refresh_seconds
  typeset -gi _ZQS_MISE_REFRESH_REQUIRED=$mise_initial_hook_deferred
  typeset -gF _ZQS_MISE_LAST_REFRESH=$EPOCHREALTIME
  typeset -g _ZQS_MISE_LAST_PATH=$PATH

  _zqs_mise_precmd_hook() {
    emulate -L zsh
    local -F now=$EPOCHREALTIME

    if [[ ${__MISE_ZSH_CHPWD_RAN:-0} == 1 ]]; then
      # Let Mise consume its chpwd marker without invoking hook-env twice.
      _mise_hook_precmd || return
    elif (( ! ${_ZQS_MISE_REFRESH_REQUIRED:-0} &&
            ${_ZQS_MISE_REFRESH_SECONDS:-5} > 0 &&
            now - ${_ZQS_MISE_LAST_REFRESH:-0} <
              ${_ZQS_MISE_REFRESH_SECONDS:-5} )) &&
        [[ $PATH == ${_ZQS_MISE_LAST_PATH:-} ]]; then
      return 0
    else
      _mise_hook_precmd || return
    fi

    typeset -g _ZQS_MISE_LAST_PATH=$PATH
    typeset -gF _ZQS_MISE_LAST_REFRESH=$EPOCHREALTIME
    typeset -gi _ZQS_MISE_REFRESH_REQUIRED=0
  }

  precmd_functions=(${precmd_functions/_mise_hook_precmd/_zqs_mise_precmd_hook})
else
  # Compatibility fallback for older activation scripts that register the
  # same `_mise_hook` function for chpwd and precmd.
  _zqs_mise_chpwd_hook() {
    _mise_hook || return
    typeset -g _ZQS_MISE_CHPWD_PWD=$PWD
    typeset -gi _ZQS_MISE_SKIP_NEXT_PRECMD=1
  }

  _zqs_mise_precmd_hook() {
    if (( ${_ZQS_MISE_SKIP_NEXT_PRECMD:-0} )) &&
        [[ ${_ZQS_MISE_CHPWD_PWD:-} == $PWD ]]; then
      unset _ZQS_MISE_SKIP_NEXT_PRECMD _ZQS_MISE_CHPWD_PWD
      return 0
    fi

    unset _ZQS_MISE_SKIP_NEXT_PRECMD _ZQS_MISE_CHPWD_PWD
    _mise_hook
  }

  precmd_functions=(
    _zqs_mise_precmd_hook
    ${precmd_functions:#_mise_hook}
  )
  chpwd_functions=(
    _zqs_mise_chpwd_hook
    ${chpwd_functions:#_mise_hook}
  )
fi

unset mise_binary mise_cache_dir mise_activate_cache mise_activate_tmp mise_activate_raw_tmp
unset mise_initial_hook_deferred mise_refresh_seconds mise_path_before_activation

asdf() {
  command mise --quiet "$@"
}

# Cache the generated completion, then source it directly. Using `autoload +X`
# here only loads mise's autoload trampoline: its first invocation replaces
# `_mise` with the real function and returns no candidates. That both requires
# a second TAB and overwrites our wrapper below.
local mise_completion_dir="$ZSH_CACHE_DIR/completions"
local mise_completion_file="$mise_completion_dir/_$__mise"
local mise_completion_tmp="$mise_completion_file.${$}.tmp"
local mise_completion_binary=${commands[$__mise]}

if [[ ! -s $mise_completion_file || $mise_completion_binary -nt $mise_completion_file ]]; then
  [[ -d $mise_completion_dir ]] || command mkdir -p "$mise_completion_dir"
  if command "$mise_completion_binary" --quiet completion zsh >| "$mise_completion_tmp"; then
    command mv -f "$mise_completion_tmp" "$mise_completion_file"
  else
    command rm -f "$mise_completion_tmp"
  fi
fi

typeset -g -A _comps
if [[ -s $mise_completion_file ]]; then
  source "$mise_completion_file"
  functions[_mise_orig]=$functions[_mise]
else
  autoload -Uz _$__mise
fi
_comps[$__mise]=_$__mise

unset mise_completion_dir mise_completion_file mise_completion_tmp
unset mise_completion_binary

mise-install-usage() {
  command mise list -q -i usage | grep -q usage || command mise use usage
}


# Wrap mise to update .tool-versions on `mise use`. tool versions are
# translated to asdf format and saved in .tool-versions in the current
# directory or in $HOME/.tool-versions if `mise use -g` is used for global
# version changes. This is needed by powerlevel10k to show the current
# versions in the prompt using the asdf segment.
# The function also adds fzf-based version selection that lists only the
# versions installed for the specified runtime when the user types `mise use
# <runtime>@` and presses tab for completion.
if (( $+functions[mise] )); then
  functions[mise_orig]=$functions[mise]
fi

_zqs_mise_native_completion() {
  if (( ! $+functions[_mise_orig] )); then
    # Fallback for a missing/unwritable cache: invoke the autoload trampoline
    # in the real completion context, capture the function it installs, then
    # restore our wrapper. Candidates are returned on this same first TAB.
    unfunction _mise 2>/dev/null
    autoload -Uz _mise
    _mise "$@"
    local completion_status=$?
    functions[_mise_orig]=$functions[_mise]
    functions[_mise]=$functions[_zqs_mise_completion]
    return $completion_status
  fi

  _mise_orig "$@"
}

_zqs_mise_completion() {
  if [[ $words[2] == use ]]; then
    local idx=3
    [[ $words[3] == -g ]] && idx=4

    if [[ ${words[$idx]} == *@* ]]; then
      local chosen runtime=${words[$idx]%%@*} versions

      versions=$(command mise ls --installed --quiet "$runtime" |
        awk '{print $2}' | sort -V)

      if command mise exec "$runtime@system" -- true >/dev/null 2>&1; then
        versions=$(printf "%s\n" $versions | grep -vx system)
        versions="system"$'\n'"$versions"
      fi

      if [[ -z $versions ]]; then
        echo "⚠️ No versions installed for '$runtime'."
        echo "👉 Install with: mise install ${runtime}@<version>"
        return 1
      fi

      if (( $+commands[fzf] )); then
        chosen=$(print -r -- "$versions" |
          fzf --ansi --prompt="Select version > " --height=20 --reverse)
        if [[ -n $chosen ]]; then
          compadd -Q -S '' -- "${runtime}@${chosen}"
        fi
      else
        compadd -Q -S '' -- ${(f)versions}
      fi
      return 0
    fi

    # For `mise use`, offer only tools that are actually installed. Append
    # `@` so the following TAB enters the installed-version/system selector.
    local tool_prefix=${words[$idx]}
    local -a installed_tools installed_specs
    installed_tools=("${(@f)$(command mise ls --installed --quiet |
      awk -v prefix="$tool_prefix" 'NF && index($1, prefix) == 1 {print $1}' |
      sort -u)}")
    (( ${#installed_tools} )) || return 0
    installed_specs=(${^installed_tools}'@')
    compadd -Q -S '' -- "${installed_specs[@]}"
    return 0
  fi
  _zqs_mise_native_completion "$@"
}

functions[_mise]=$functions[_zqs_mise_completion]

# Translate mise runtime@version to asdf format and save to .tool-versions
_mise_runtime_to_asdf() {
  local spec="$1"
  local runtime="${spec%@*}"
  local version="${spec#*@}"
  local file=".tool-versions"

  if [[ "$2" == "-g" ]]; then
    file="$HOME/$file"
  fi

  if [[ "$runtime" == "$version" ]]; then
    # `mise use node` has no explicit version. Read only the selected
    # version from `mise current`; the runtime name must not leak into the
    # value written to .tool-versions.
    version=$(mise_orig current "$runtime" | awk 'NF {print $NF; exit}')
  fi

  if [[ "$runtime" == "node" ]]; then
    runtime="nodejs"
  fi

  [[ -n "$version" ]] || return 0
  [[ -f "$file" ]] || touch "$file"

  if [ $(uname -a | grep -ci Darwin) = 1 ]; then
    # macOS
    sed -i '' "/^$runtime /d" "$file"
  else  
    # Linux
    sed -i "/^$runtime /d" "$file"
  fi  

  print -r -- "$runtime $version" >> "$file"
}
export MISE_QUIET=1
mise () {
  if [[ "$1" == "use" ]]; then
    shift
    local global_flag=""
    if [[ "$1" == "-g" ]]; then
      global_flag="-g"
      shift
    fi
    local runtime_spec="$1"
    shift

    mise_orig use ${global_flag:+"$global_flag"} "$runtime_spec" "$@" || return "$?"

    if [[ -n "$runtime_spec" ]]; then
      _mise_runtime_to_asdf "$runtime_spec" "$global_flag"
    fi
    typeset -gi _ZQS_MISE_REFRESH_REQUIRED=1
  elif [[ "$1" == "install" ]]; then
    export MISE_QUIET=0
    mise_orig "$@"
    local mise_status=$?
    export MISE_QUIET=1
    (( mise_status == 0 )) && typeset -gi _ZQS_MISE_REFRESH_REQUIRED=1
    return $mise_status
  else
    mise_orig "$@"
    local mise_status=$?
    (( mise_status == 0 )) && typeset -gi _ZQS_MISE_REFRESH_REQUIRED=1
    return $mise_status
  fi
}

unset __mise
