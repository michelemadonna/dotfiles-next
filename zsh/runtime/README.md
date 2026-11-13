# Standalone Zsh runtime

Extracted from the local upstream v5 checkout at revision
`c0c29f999635f58e2b1bdb442e633c01a1b9ecc2`. Roman Perepelitsa's MIT notice is retained
in `LICENSE`. This source tree is self-contained; it does not source or require
the original checkout, framework dispatcher, bootstrap, or cache.

`../dotsh-startup.zsh` owns the options, startup policy, compiled source
loader, dependency loading, and initialization API. Call it first in `.zshrc`,
configure styles and `fpath`, then call `dotsh_init`. Plugin dependencies live
in `../vendor/packages`; runtime state lives in the XDG Zsh cache/state roots.
`dotsh_prepare_runtime` explicitly prepares autoload wordcode; startup does not
recompile the whole tree. `.zwc` files are generated artifacts.

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
- Powerlevel10k instant prompt and Git status cache; downloads are disabled
  during startup, so explicit dependency preparation must install gitstatus.
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
- Standalone terminal UI helpers and the legacy-style fzf widgets for the
  applicable non-fzf-tab configuration. User plugins supply fzf-tab, FSH,
  history substring search, and the optional fast profile separately.

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
