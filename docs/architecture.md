# Architecture

## Components

- `install.sh` is the only installer and owns package installation, choices,
  generated preferences, backups, links, and z4h-style logs.
- `zsh/.zshenv.init` defines defaults, paths, environment variables, and
  sources `zsh/helpers/tool-bootstrap.zsh` before `.zshenv_z4h`. If
  `zsh/home/.zshenv_z4h` is missing, it is fetched atomically from the pinned
  zsh4humans v5 raw source before being sourced.
- `zsh/home/.zshenv` is generated or retained preferences; `~/.zshenv` points
  to it. `.zshenv_z4h` loads z4h; `.zshrc` loads interactive helpers/plugins.
- `zsh/helpers/` owns SSH, Fastfetch, tool bootstrap, fzf state/preview, Mise
  cache preparation, and the Intel MacPorts/Homebrew coexistence layer.
  `zsh/z4h.custom.plugins/` owns repository plugins.
- Powerlevel10k is the default prompt. Oh My Posh is optional and uses the
  repository JSON theme when selected.

## Startup and state

Startup adds Homebrew paths on Apple Silicon, the installer-selected Homebrew
or MacPorts paths on Intel, and
`$HOME/.local/bin` everywhere, then bootstraps selected tools and links
existing repository configurations for Fastfetch, Mise, and the selected
editor. In a MacPorts-primary Intel setup, startup excludes `/usr/local/bin`
and `/usr/local/sbin`, then loads `pkgmng` interactively before completion
initialization only when both Homebrew and MacPorts are installed. The
persisted `DOTFILES_INTEL_PACKAGE_MANAGER` preference also keeps automatic
non-interactive tool installation on the selected backend. Interactive startup restores
`$HOME/.local/bin` before z4h initialization because macOS's `/etc/zprofile`
can rebuild `PATH` after `.zshenv`. Mise activation/completion caches and ASDF
plugin compatibility data are prepared by
`zsh/helpers/prepare-mise-cache.sh`.
Loading the cached Mise activation preserves any entries already present in
the current startup `PATH`, since the generated activation script contains the
environment that was active when the cache was created.
After z4h initializes completion, `.zshrc` explicitly registers Homebrew's
native `_brew` function so an older compinit dump cannot suppress formula and
cask completion or its fzf-tab preview context.
On macOS Tahoe, the fzf plugin also supplies Homebrew's generated completion
with the local API name indexes when Homebrew 6 returns an empty completion
list, and invalidates only previously serialized empty brew completion caches.
On Intel, `pkgmng` owns Brew execution and provider wrappers; the fzf plugin
owns only completion fallback and previews. Provider state is stored under
`${XDG_STATE_HOME:-$HOME/.local/state}/zsh` and explicit MacPorts selections
survive Homebrew rescans, upgrades, and cleanup.

Persistent sources live in the repository. The zsh4humans bootstrap file is
kept at `zsh/home/.zshenv_z4h`; a missing copy is restored from
`https://raw.githubusercontent.com/romkatv/zsh4humans/v5/.zshenv`. Generated preferences, z4h data,
completion data, compiled files, state markers, and runtime caches are derived
artifacts and must not be edited as source.

Mise/ASDF project runtimes are shown in the right prompt. Each active runtime
has its own light capsule; the right prompt is hidden when it cannot fit.

## Shell contracts

z4h supplies fzf and native `Ctrl-T`, `Ctrl-R`, and `Alt-C`. fzf-tab and native
file widgets share hidden-file and preview state: `Ctrl-P` cycles preview
layout and `Ctrl-H` toggles hidden files. Completion generation is explicitly
requested with `Shift-Tab`.

The vendored `fzf-git.sh` integration is loaded after fzf and fzf-tab, then the
local adapter adds command-aware Git dispatch before the final `z4h-fzf`
widget bindings. Upstream owns picker UI, previews, parsing, and `Ctrl-G`
widgets. A documented vendor patch adds `become` transitions, while the adapter
provides the foreground bridge used by every transition and by contextual TAB.
The bridge writes the final typed selection as private NUL-delimited sidecar
records and returns only a random token through upstream `cut`, `sed`, and
`awk` pipelines. TAB and the upstream ZLE joiner resolve and immediately remove
the sidecar, preserving the original ref type and command-specific quoting.
The separate `fzf-git-action.zsh` helper gives terminal editors a dedicated
PTY, materializes ref contents as temporary regular files, and renders Git
preview input according to the current shared layout. It invokes side-by-side
delta only for `down` and `down90`; right and hidden layouts retain unified
output, including after an in-picker `Ctrl-P` refresh.
Unknown contexts still delegate to fzf-tab. The pinned revision requires fzf
0.66+; older versions use compatible single-mode pickers and fzf-tab fallback.
The upstream executor reads the shared preview and height state at launch;
`Ctrl-P` updates preview geometry in place, while `Ctrl-F` remains a ZLE action
whose persisted height applies to the next picker.
