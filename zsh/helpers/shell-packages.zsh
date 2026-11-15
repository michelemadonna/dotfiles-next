# Shared package resolution and preparation for dotsh_load and the installer.

dotsh_resolve_package() {
  emulate -L zsh -o extended_glob
  local requested=$1 identifier name repository revision extra matched=
  local priority match_priority=0 managed_path=false
  local -a match fields package_names
  local manifest="$DOTFILES_DIR/zsh/vendor/packages.lock"
  if [[ $requested == /* || $requested == (./*|../*) ]]; then
    requested=${requested:a}
    [[ $requested == "${DOTSH_PACKAGES:a}/"* ]] || {
      print -ru2 -- "dotsh: missing local plugin: $requested"
      return 1
    }
    identifier=${requested#"${DOTSH_PACKAGES:a}/"}
    managed_path=true
  else
    identifier=$requested
  fi
  # Check every component before using a package name as a filesystem path.
  fields=("${(@s:/:)identifier}")
  for name in "${fields[@]}"; do
    [[ -n $name && $name != (.|..) && $name != *[^a-zA-Z0-9_.-]* ]] || {
      print -ru2 -- "dotsh: invalid package identifier: $identifier"
      return 1
    }
  done
  if [[ -r $manifest ]]; then
    while read -r name repository revision extra || [[ -n $name ]]; do
      [[ -n $name && $name != \#* ]] || continue
      package_names+=("$name")
      local github=${repository#https://github.com/}
      github=${github%.git}
      if [[ $identifier == "$name" ]]; then
        priority=3
      elif [[ ${identifier:l} == ${github:l} ]]; then
        priority=2
      elif [[ $managed_path == true && $identifier == "$name/"* ]]; then
        priority=1
      else
        continue
      fi
      # Prefer exact names/repositories; nested paths use the longest prefix.
      (( priority >= match_priority )) || continue
      if (( priority == match_priority && ${#name} <= ${#matched} )); then
        continue
      fi
      [[ -n $repository && -z $extra ]] || {
        print -ru2 -- "dotsh: invalid lockfile entry: $name"
        return 1
      }
      matched=$name
      match_priority=$priority
      match=("$name" "$repository" "$revision")
    done < "$manifest"
  fi
  if (( $#match )); then
    [[ ${${:-$DOTSH_PACKAGES/$matched}:a} == "${DOTSH_PACKAGES:a}/$matched" ]] || {
      print -ru2 -- "dotsh: invalid lockfile package name: $matched"
      return 1
    }
    local suffix=
    [[ $identifier != "$matched/"* ]] || suffix=/${identifier#"$matched/"}
    reply=("$DOTSH_PACKAGES/$matched$suffix" "${match[@]}")
  elif (( $#fields == 2 )); then
    for name in "${package_names[@]}"; do
      if [[ $identifier == "$name/"* || $name == "$identifier/"* ]]; then
        print -ru2 -- "dotsh: package directory overlaps $name; register $identifier under a separate name in zsh/vendor/packages.lock"
        return 1
      fi
    done
    reply=("$DOTSH_PACKAGES/$identifier" "$identifier"
      "https://github.com/$identifier.git" '')
  else
    print -ru2 -- "dotsh: unknown package: $identifier; add its repository to zsh/vendor/packages.lock or use owner/repo"
    return 1
  fi
}

dotsh_patch_powerlevel10k() {
  emulate -L zsh
  local directory=$1 patch_record=$2
  local patch_file="$DOTFILES_DIR/zsh/vendor/patches/powerlevel10k-dotsh-runtime.patch"
  local previous_patch="$DOTFILES_DIR/zsh/vendor/patches/powerlevel10k-runtime-v1.patch"
  if [[ ! -f $patch_record ]] &&
     ! command git -C "$directory" apply --reverse --check "$patch_file" &>/dev/null &&
     command git -C "$directory" apply --reverse --check "$previous_patch" &>/dev/null; then
    command git -C "$directory" apply --reverse "$previous_patch" || return
  fi
  if [[ -f $patch_record ]] && ! command cmp -s "$patch_file" "$patch_record" &&
     ! command git -C "$directory" apply --reverse --check "$patch_file" &>/dev/null; then
    command git -C "$directory" apply --reverse --check "$patch_record" || return
    command git -C "$directory" apply --reverse "$patch_record" || return
  fi
  if ! command git -C "$directory" apply --reverse --check "$patch_file" &>/dev/null; then
    command git -C "$directory" apply --check "$patch_file" || return
    command git -C "$directory" apply "$patch_file" || return
    command rm -f -- "$directory/internal/p10k.zsh.zwc" || return
  fi
  command cp -- "$patch_file" "$patch_record"
}

dotsh_finish_package() {
  emulate -L zsh
  local name=$1 directory=$2 patch_record=$3
  case $name in
    powerlevel10k)
      dotsh_patch_powerlevel10k "$directory" "$patch_record" || return
      GITSTATUS_CACHE_DIR="$directory/gitstatus/usrbin" \
        command sh "$directory/gitstatus/install" || return
      ;;
    fast-syntax-highlighting)
      local patch_file="$DOTFILES_DIR/zsh/vendor/patches/fast-syntax-highlighting-offline.patch"
      if ! command git -C "$directory" apply --reverse --check "$patch_file" &>/dev/null; then
        command git -C "$directory" apply --check "$patch_file" || return
        command git -C "$directory" apply "$patch_file" || return
        command rm -f -- "$directory/fast-syntax-highlighting.plugin.zsh.zwc" || return
      fi
      ;;
    fzf)
      if [[ ! -x $directory/bin/fzf ]]; then
        command bash "$directory/install" --bin || return
      fi
      [[ -x $directory/bin/fzf ]] || {
        print -ru2 -- 'dotsh: fzf binary installation failed'
        return 1
      }
      ;;
  esac
  return 0
}

# Run preparation in a subshell so kernel locks and cleanup never affect the
# caller's shell. Both installer and loader re-resolve after acquiring the lock.
dotsh_prepare_package() (
  emulate -L zsh -o extended_glob
  local requested=$1 mode=${2:-missing} lock_fd
  local staging= manifest_tmp= backup= destination=
  local manifest="$DOTFILES_DIR/zsh/vendor/packages.lock"
  local -a reply
  command mkdir -p -- "$DOTSH_PACKAGES" || return
  : >> "$DOTSH_PACKAGES/.prepare.lock" || return
  zmodload zsh/system || return
  zsystem flock -t 120 -f lock_fd "$DOTSH_PACKAGES/.prepare.lock" || {
    print -ru2 -- 'dotsh: could not acquire the package preparation lock'
    return 1
  }
  trap '[[ -z $staging ]] || command rm -rf -- "$staging"
        [[ -z $manifest_tmp ]] || command rm -f -- "$manifest_tmp"
        if [[ -n $backup && -d $backup && ! -e $destination ]]; then
          command mv -- "$backup" "$destination"
        fi' EXIT
  trap 'exit 1' HUP INT TERM
  dotsh_resolve_package "$requested" || return
  local directory=$reply[1] name=$reply[2] repository=$reply[3] revision=$reply[4]
  destination="$DOTSH_PACKAGES/$name"
  if [[ $mode == missing && -d $destination ]]; then
    print -r -- "$directory"
    return 0
  fi
  if [[ -n $revision && $revision != latest &&
        $revision != [[:xdigit:]](#c40) && $revision != [[:xdigit:]](#c64) ]]; then
    print -ru2 -- "dotsh: lockfile revision must be a full commit or latest: $name"
    return 1
  fi
  local installed=
  if [[ -d $destination/.git ]]; then
    installed=$(command git -C "$destination" rev-parse HEAD) || return
  fi
  if [[ -n $installed && $installed == $revision ]]; then
    dotsh_finish_package "$name" "$destination" \
      "$DOTSH_PACKAGES/.powerlevel10k-dotsh-runtime.patch" >&2 || return
  else
    staging=$(command mktemp -d "$DOTSH_PACKAGES/.prepare.XXXXXX") || return
    print -ru2 -- "dotsh: preparing $name at ${revision:-latest}"
    command git -C "$staging" init -q || return
    command git -C "$staging" remote add origin "$repository" || return
    local fetch_revision=${revision:-HEAD}
    [[ $fetch_revision != latest ]] || fetch_revision=HEAD
    GIT_TERMINAL_PROMPT=0 command git -C "$staging" fetch -q --depth=1 origin "$fetch_revision" || return
    command git -C "$staging" -c advice.detachedHead=false checkout -q --detach FETCH_HEAD || return
    installed=$(command git -C "$staging" rev-parse HEAD) || return
    if [[ -n $revision && $revision != latest && $installed != $revision ]]; then
      print -ru2 -- "dotsh: fetched revision does not match lockfile: $name"
      return 1
    fi
    dotsh_finish_package "$name" "$staging" \
      "$staging/.powerlevel10k-dotsh-runtime.patch" >&2 || return
  fi
  if [[ -z $revision || $revision == latest ]]; then
    manifest_tmp=$(command mktemp "$DOTFILES_DIR/zsh/vendor/.packages.lock.XXXXXX") || return
    local manifest_input=$manifest
    [[ -f $manifest_input ]] || manifest_input=/dev/null
    command awk -v name="$name" -v repository="$repository" -v revision="$installed" '
      $1 == name { print name, repository, revision; found = 1; next }
      { print }
      END { if (!found) print name, repository, revision }
    ' "$manifest_input" > "$manifest_tmp" || return
    command mv -f -- "$manifest_tmp" "$manifest" || return
    manifest_tmp=
  fi
  if [[ -n $staging ]]; then
    command mkdir -p -- "${destination:h}" || return
    if [[ -e $destination ]]; then
      backup=$staging.previous
      command mv -- "$destination" "$backup" || return
    fi
    command mv -- "$staging" "$destination" || return
    staging=
    [[ -z $backup ]] || command rm -rf -- "$backup" || return
    backup=
    if [[ $name == powerlevel10k ]]; then
      command cp -- "$destination/.powerlevel10k-dotsh-runtime.patch" \
        "$DOTSH_PACKAGES/.powerlevel10k-dotsh-runtime.patch" || return
    fi
  fi
  print -r -- "$directory"
)

# The installer invokes this library as a script to prepare every locked entry.
if [[ $ZSH_EVAL_CONTEXT == toplevel ]]; then
  emulate -L zsh
  typeset -g DOTFILES_DIR=${0:A:h:h:h}
  typeset -g DOTSH_PACKAGES="$DOTFILES_DIR/zsh/vendor/packages"
  local name repository revision extra
  local -a package_names
  [[ -r $DOTFILES_DIR/zsh/vendor/packages.lock ]] || {
    print -ru2 -- 'dotsh: cannot read zsh/vendor/packages.lock'
    exit 1
  }
  while read -r name repository revision extra || [[ -n $name ]]; do
    [[ -z $name || $name == \#* ]] || package_names+=("$name")
  done < "$DOTFILES_DIR/zsh/vendor/packages.lock"
  for name in "${package_names[@]}"; do
    dotsh_prepare_package "$name" install >/dev/null || exit 1
  done
fi
