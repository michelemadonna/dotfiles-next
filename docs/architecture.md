# Architecture

## Components

- `install.sh` owns installation, preferences, links, and explicit dependency preparation.
- `zsh/.zshenv.init` defines the environment without a framework bootstrap.
- `zsh/home/.zshrc` sources `zsh/runtime/dotsh-startup.zsh` first, applies
  user overrides, then configures the local runtime and loads custom plugins.
- `zsh/runtime/fn` contains the attributed runtime extraction, while
  `zsh/runtime/dotsh-startup.zsh` owns startup defaults and initialization.
  Package resolution and preparation are shared with the installer through
  `zsh/helpers/shell-packages.zsh`.
- `zsh/vendor/packages.lock` pins independent plugins installed by
  `zsh/helpers/prepare-shell-dependencies.sh`. `dotsh_load` also prepares missing
  packages on demand. Unpinned repositories resolve to the default branch's
  current commit, which is recorded in the lockfile. A kernel file lock
  serializes preparation and atomic lockfile replacement across shells and
  the installer. Prepared packages are published after downloads, patches,
  and package-specific executable setup succeed.
- Powerlevel10k remains the default prompt; Oh My Posh is optional.

See [Standalone Zsh migration](standalone-zsh.md) for runtime boundaries,
performance mechanisms, compatibility, and verification.

## Startup and state

Startup adds Homebrew paths on Apple Silicon, the installer-selected Homebrew
or MacPorts paths on Intel, and
`$HOME/.local/bin` everywhere. Explicit preparation/installation owns tool
installation and configuration links for Fastfetch, Mise, and the selected
editor. In a MacPorts-primary Intel setup, startup excludes `/usr/local/bin`
and `/usr/local/sbin`, then loads the `dotsh-pkgmng` plugin before completion
initialization only when both Homebrew and MacPorts are installed. The
persisted `DOTFILES_INTEL_PACKAGE_MANAGER` preference also keeps explicit
non-interactive tool installation on the selected backend. Interactive startup
restores `$HOME/.local/bin` before runtime initialization. Mise activation/completion caches and a
minimal ASDF compatibility tree for ASDF-compatible installed Mise runtimes
are prepared by `zsh/helpers/prepare-mise-cache.sh`.
Loading the cached Mise activation preserves any entries already present in
the current startup `PATH`, since the generated activation script contains the
environment that was active when the cache was created.
The `dotsh-pkgmng` plugin adds Homebrew completion directories to `fpath` before
runtime initialization and exposes a registration helper that `.zshrc` calls
after `dotsh_init`; this restores native `_brew` completion even when an older
compinit dump predates Homebrew's current paths.
On macOS Tahoe, the fzf plugin also supplies Homebrew's generated completion
with the local API name indexes when Homebrew 6 returns an empty completion
list, and invalidates only previously serialized empty brew completion caches.
The `dotsh-git` plugin restores native macOS Git completion when available and
removes candidate filters that hide Git refs and commits.
On Intel, `dotsh-pkgmng` owns Brew execution and provider wrappers; the fzf plugin
owns only completion fallback and previews. The plugin also provides the
metadata-only `brew-bottle-check` preflight for requested formulae and their
recursive required/recommended dependencies. Provider state is stored under
`${XDG_STATE_HOME:-$HOME/.local/state}/zsh` and explicit MacPorts selections
survive Homebrew rescans, upgrades, and cleanup.

Persistent sources live in the repository. Generated preferences, completion
caches, compiled files, and state are derived artifacts. The extracted runtime
uses XDG Zsh cache/state paths, independently of the former dotsh cache.

Mise/ASDF project runtimes are shown in the right prompt. Each active runtime
has its own light capsule; the right prompt is hidden when it cannot fit.

Startup defers enabled fzf-tab, picker widgets, fzf-git, and generated
completion until first use; highlighting and history substring search load at
the first ZLE line. The local runtime handles autosuggestions and redraw.
The runtime does not register its legacy fzf widgets or source its own
highlighting/history-search plugins. Startup does not load the framework or
update installed packages. Missing packages requested through `dotsh_load`
are downloaded before loading, including deferred plugin loading on first use.

## Shell contracts

`DOTSH_USE_FZF` defaults to `true` and gates the fzf loaders, widget registration,
fzf-tab configuration, fzf-git, command-specific previews, the fuzzy keybinding
reference, and Mise's fuzzy version selector. With `false`, the shell uses
native keybindings and completion. Highlighting, history substring search,
autosuggestions, native Git/Brew completion, and optional `Shift-Tab` generation
operate independently. The installer owns migration of the previous flag name.

When enabled, the shell provides `Ctrl-T`, `Ctrl-R`, and `Alt-C` through independent fzf.
fzf-tab and the file widgets share hidden-file and preview state: `Ctrl-P`
cycles preview layout and `Ctrl-H` toggles hidden files. Completion generation
is explicitly requested with `Shift-Tab`.

The vendored `fzf-git.sh` integration is loaded after fzf and fzf-tab, then the
local adapter adds command-aware Git dispatch before the final `dotsh-fzf`
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
