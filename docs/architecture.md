# Architecture

## Components

- `install.sh` is the only installer and owns package installation, choices,
  generated preferences, backups, links, and z4h-style logs.
- `zsh/.zshenv.init` defines defaults, paths, environment variables, and
  sources `zsh/helpers/tool-bootstrap.zsh` before `.zshenv_z4h`.
- `zsh/home/.zshenv` is generated or retained preferences; `~/.zshenv` points
  to it. `.zshenv_z4h` loads z4h; `.zshrc` loads interactive helpers/plugins.
- `zsh/helpers/` owns SSH, Fastfetch, tool bootstrap, fzf state/preview, and
  Mise cache preparation. `zsh/z4h.custom.plugins/` owns repository plugins.
- Powerlevel10k is the default prompt. Oh My Posh is optional and uses the
  repository JSON theme when selected.

## Startup and state

Startup adds Homebrew paths on macOS and `$HOME/.local/bin` everywhere, then
bootstraps selected tools and links existing repository configurations for
Fastfetch, Mise, and the selected editor. Mise activation/completion caches and
ASDF plugin compatibility data are prepared by
`zsh/helpers/prepare-mise-cache.sh`.

Persistent sources live in the repository. Generated preferences, z4h data,
completion data, compiled files, state markers, and runtime caches are derived
artifacts and must not be edited as source.

Mise/ASDF project runtimes are shown in the right prompt. Each active runtime
has its own light capsule; the right prompt is hidden when it cannot fit.

## Shell contracts

z4h supplies fzf and native `Ctrl-T`, `Ctrl-R`, and `Alt-C`. fzf-tab and native
file widgets share hidden-file and preview state: `Ctrl-P` cycles preview
layout and `Ctrl-H` toggles hidden files. Completion generation is explicitly
requested with `Shift-Tab`.
