# Standalone Zsh runtime

The `fn/` tree was extracted from the local upstream v5 checkout at revision
`c0c29f999635f58e2b1bdb442e633c01a1b9ecc2`. Roman Perepelitsa's MIT notice is retained
in `LICENSE`. `dotsh-startup.zsh` is the repository-owned entrypoint around
that extraction. The runtime is self-contained; it does not source or require
the original checkout, framework dispatcher, bootstrap, or cache.

`dotsh-startup.zsh` owns the options, generic shell defaults, compiled source
loader, dependency loading, and initialization API. Source it first in
`.zshrc`, then apply user overrides and configure styles and `fpath` before
calling `dotsh_init`. Plugin dependencies live
in `../vendor/packages`; runtime state lives in the XDG Zsh cache/state roots.
`dotsh_prepare_runtime` explicitly prepares autoload wordcode; startup does not
recompile the whole tree. `.zwc` files are generated artifacts.

`dotsh_load` accepts local directories, locked package names, and GitHub
`owner/repo` identifiers, with optional `-c` / `--compile`. Missing packages
are downloaded through the shared package helper. Locked commits are used
exactly; missing revisions resolve to the default branch's HEAD and are
recorded in `../vendor/packages.lock`. Installed packages are reused offline.
New repositories live under `../vendor/packages/owner/repo`; existing lockfile
names retain their original paths. Package preparation and lockfile writes
are serialized across shells and the installer.

`dotsh_bind_default_keys` applies the repository's default keybindings after
plugins load. Call it before user-specific bindings so they can take precedence.

## Retained mechanisms

- The current Zsh executable is retained for child shells through a small local
  launcher when PATH resolves another Zsh.
- Complete option set from the upstream startup policy, with the reference's final
  option overrides and history fcntl locking except on WSL1.
- Unique tied PATH/MANPATH/INFOPATH arrays, cached macOS `path_helper` results
  invalidated by dependency filenames and mtimes, locale/terminfo setup,
  pagers, colors, prompt and history defaults.
- Source wordcode using the original source/+1-second mtime validation,
  atomic publication, and optional explicit runtime precompilation.
- Powerlevel10k instant prompt and Git status cache; package preparation
  installs gitstatus, while its own automatic downloads remain disabled.
- Deferred compsys initialization, queued `compdef` replay, and compiled
  completion dumps invalidated by Zsh version/patchlevel plus completion
  filenames and mtimes. Stock `compinit` replaces the framework-generated
  variant; the effective Tab binding is restored afterward.
- The dynamically registered `zle-line-init`, `zle-line-finish`, and
  `zle-line-pre-redraw` handlers and their transitive runtime dependencies.
- ZLE redraw coalescing through `zle -F`, queued-input handling, prefix-cached
  autosuggestions, selective widget binding and the original redraw/highlight
  integration. These intentionally replace stock autosuggestions behavior.
- Terminal metadata/title caches skip unchanged output for untouched empty
  lines, invalidate on command/widget activity, and refresh for directory or
  identity changes and active jobs. OSC record order is preserved.
- History limits, local/global search, directory history and stack navigation,
  word movement, acceptance, paste, clear-screen, named key translations,
  terminal title/OSC integration, and lazily generated command completions.
- Default completion and history widgets without runtime-owned legacy fzf,
  highlighting, or substring-search modules. The always-enabled fast startup
  helper loads independent fzf-tab, FSH, history search, and generated
  completions on first use.

## Removed framework responsibilities

No install/update/reset dispatcher, package channels, bootstrap, automatic
`chsh`, SSH teleportation, managed tmux process/socket, or welcome lifecycle
is included. `:dotsh:<component> channel none` remains only as a local enable
switch for runtime features; it does not select or download package versions.
Disabled reference direnv lifecycle was not retained. SSH-agent and custom
command integrations remain owned by the existing repository helpers.
Standalone Powerlevel10k owns screen capture; framework tmux/SSH transport
capture functions are inert. Runtime symbols, styles, and preferences use the
standalone `dotsh` namespace.

## Validation boundaries

Source parsing does not prove terminal behavior. Autoload bodies contain
runtime fd redirects, so validate their syntax by compiling or by wrapping
bodies in a function before `zsh -n`; bare `zsh -n fn/file` can reject unresolved
runtime fd variables. Verify completion, deferred first use, autosuggestion
visibility, prompt redraw, and directory widgets in a writable PTY. Run the
project's root `start_benchmark.sh` only from the fake HOME entered through
root `fhome.sh`, and compare every capability flag and latency with the target.
