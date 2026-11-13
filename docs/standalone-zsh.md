# Standalone Zsh migration

The shell uses an independent local runtime. The extracted runtime is stored in
`zsh/runtime`, with its original MIT license and source revision recorded in
its README. `zsh/dotsh-startup.zsh` is the first source in `.zshrc` and
owns startup options, source compilation, runtime preparation, and initialization.
The supporting autoload functions retain completion caching, redraw scheduling,
and prefix-cached autosuggestions; this is not a stock-plugin substitution.

The [namespace validation report](dotsh-namespace-validation.md) records current
checks and benchmarks. The [earlier migration report](standalone-validation.md)
preserves the extraction's terminal checks and full benchmark history.

## Preparation and startup

From this project's fake-home root, enter `./fhome.sh`. Check that HOME,
ZDOTDIR, HISTFILE, XDG paths, TMPDIR, and any application output directories
stay inside the project. The root `.zshenv` selects the migrated `dotfiles-old`
configuration. The launcher also isolates Mise paths and SSH agents; fake-home
SSH loading does not import the host's macOS Keychain or keychain-managed agent.

Prepare dependencies explicitly inside that shell:

```sh
sh "$DOTFILES_DIR/zsh/helpers/prepare-shell-dependencies.sh"
exec zsh -l
```

The preparation script downloads the exact Git revisions in
`zsh/vendor/packages.lock`, prepares the fzf binary and gitstatus daemon, and
compiles the extracted autoload functions. Matching revisions are reused.
`install.sh` invokes the same step and migrates existing generated
preferences in place, preserving custom settings and saving a one-time backup
of the legacy file. New installations use the current template. The known
legacy bootstrap and automatic tool-bootstrap call are removed.

The installer detects a previous preference namespace from the saved startup
profile and converts it to `DOTSH_*` before reading or generating preferences.
It preserves choices and custom settings without exporting legacy aliases.

No framework package manager, update dispatcher, automatic installer, `chsh`,
SSH teleportation, or managed tmux startup is loaded. Missing dependencies
require explicit preparation. Gitstatus automatic downloads are disabled.
Powerlevel10k remains the default; Oh My Posh remains available.

## Runtime interface

User preferences use `DOTSH_*` names, and custom plugins and functions use the
`dotsh` namespace. Runtime APIs are `dotsh_source`, `dotsh_load`,
`dotsh_bindkey`, and `dotsh_init`; internal runtime symbols/styles use `dotsh`.
The `dotsh-reset-zsh-cache` command preserves prepared plugins and does not
request a framework download on restart.

`DOTSH_KEYBOARD` selects named-key conventions: `mac` on macOS or `pc` on
other systems by default. Set it to `mac` when using an Apple keyboard on Linux,
or to `pc` for a PC keyboard on macOS. Both select terminal escape sequences;
the physical keyboard and terminal must generate the expected sequences.

The separate `macos-option-as-alt` style retains its existing behavior: it is
enabled unless set to `no`, and maps several characters produced by the Option
key to widgets. On a PC layout where those characters should be inserted as
text, set `zstyle ':dotsh:bindkey' macos-option-as-alt no` before `dotsh_init`.
Selecting `keyboard pc` alone does not change that separate style.

## Optimization inventory

The source reference is revision `c0c29f999635f58e2b1bdb442e633c01a1b9ecc2`
of the supplied upstream checkout. The original MIT notice by Roman Perepelitsa
is retained in `zsh/runtime/LICENSE`. Migrated functions use the `dotsh`
namespace in `zsh/runtime/fn`.

| Reference mechanism | Standalone implementation |
| --- | --- |
| Option reset and defaults | `dotsh-startup.zsh`; final reference overrides remain effective |
| Early suppression of global startup scripts | `.zshenv.init` sets `no_global_rcs` before `/etc/zprofile`; startup policy reapplies it after `emulate` |
| Module loading, unique tied path arrays, executable selection | `dotsh-startup.zsh`, with `runtime/bin/zsh` for matching child shells |
| Cached macOS paths | `-dotsh-gen-init-darwin-paths`, including dependency names and mtimes |
| Compiled source/load helpers | `-dotsh-compile`, `dotsh_source`, `dotsh_load`; atomic wordcode and original source identity |
| Autoloaded runtime functions | Local autoload tree; explicit preparation compiles it once |
| Instant prompt and load order | `-dotsh-init-zle`, independently prepared Powerlevel10k and Git status daemon |
| Deferred `compinit`, `compdef` queue, compiled dumps | `-dotsh-compinit`, with version/patchlevel and completion file/mtime invalidation; no second plugin `compinit` |
| ZLE line handlers and redraw | `-dotsh-zle-line-*` and `-dotsh-redraw-buffer` retain event flow and `zle -F` input coalescing; skip lexical work only for an empty editable buffer without a multiline prefix |
| Autosuggestions and widget rebinding | Extracted prefix cache, suggestion invalidation, acceptance and highlighting integration |
| Terminal integration and title handling | Extracted handlers, ordered OSC records, cached unchanged metadata and titles with command/widget/job invalidation |
| Existing fast profile and custom integrations | Local `fast-startup.zsh`, fzf widgets and completion generator; no download on first use |
| Existing Mise activation cache | Existing custom Mise plugin retained; launcher confines its output directories |

The original framework's executable installer, package updates, self-update,
managed tmux and SSH transport lifecycle are intentionally excluded. Ordinary
terminal integration, directory history and SSH-agent helper behavior remain.
The fake HOME uses a separate agent and avoids importing host Keychain keys.

Both `default` and `fast` startup profiles remain supported. The fast profile
loads the fzf integrations and generated-completion helper on first use; FSH
and history substring search load through a one-time callback in the runtime's
existing line-init handler. First use never downloads
dependencies. Shared preview/hidden-file state and Shift-Tab generation remain
owned by the existing custom plugins.

## Verification

In an interactive `fhome.sh` shell, from the fake-home root:

```zsh
source "$DOTFILES_DIR/tests/test-standalone.zsh"
sh "$DOTFILES_DIR/tests/test-installer-platforms.sh"
zsh "$DOTFILES_DIR/tests/test-pkgmng.zsh"
zsh -df "$DOTFILES_DIR/tests/test-terminal-packets.zsh"
zsh -df "$DOTFILES_DIR/tests/test-cold-highlighting.zsh"
./start_benchmark.sh
python3 "$DOTFILES_DIR/tests/check-benchmark.py" target-zsh.benc current-zsh.benc
```

The standalone check covers retained options, event handlers, fake-home state,
completion registration, deferred integrations, compiled helper source identity,
and source-cache invalidation. It complements actual terminal checks of picker
keys, cancellation, autosuggestion redraw, and prompt behavior.

Compare all flags and every latency in `current-zsh.benc` with the immutable
root `target-zsh.benc`. A successful startup is not proof of performance parity.
The comparison command fails on any missing flag or latency above its target;
it applies no tolerance and does not average away regressions.
Record repeated results and any execution-environment limitations. On this
machine, the filesystem sandbox blocks the benchmark's `/dev/fd` access;
running it outside that sandbox must still enter the fake HOME through
`fhome.sh` and retain all its confined paths.
