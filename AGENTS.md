# AGENTS.md

## Project

`dotfiles-next` is a Zsh for Humans based dotfiles environment for macOS and
Ubuntu 26.04. It includes an interactive/non-interactive installer, custom Zsh
plugins, Powerlevel10k as the default prompt, optional Oh My Posh support, and
a complete Docker demo.

Read `README.md`, `install.sh`, and the relevant source files before changing
behavior. Treat the repository contents as the source of truth.

## Repository-specific rules

- Update `README.md` whenever commands, options, defaults, supported
  platforms, installation behavior, Docker usage, or interactive UX changes.

## Repository contracts

- Supported/documented host platforms are macOS and Ubuntu 26.04.
- Powerlevel10k is the default prompt. Oh My Posh is optional; never replace
  or modify Powerlevel10k in order to fix it unless explicitly requested.
- `install.sh` supports interactive mode plus `non-interactive` and
  `--non-interactive`. Preserve their prompt, environment, and idempotency
  contracts.
- Non-interactive installation must not prompt or install Mise. Base package
  installation remains guarded by its versioned, platform-specific state
  marker.
- Docker builds clone the GitHub repository by default. The current directory
  is used only with `--build-arg DOTFILES_SOURCE=local`.
- For the default remote source, `docker run -it` must execute the checkout's
  interactive `install.sh` before starting Zsh. Local-source builds execute
  `install.sh non-interactive` during the build. Do not replace either path
  with hand-written setup logic. Seed the base-package marker only because the
  base stage has already installed those packages.
- Keep expensive Docker downloads, demo repositories, and Mise runtimes before
  the dotfiles source-selection stages so local edits do not invalidate them.
- z4h supplies `fzf`; native fzf bindings provide `Ctrl-T`, `Ctrl-R`, and
  `Alt-C`. Do not reintroduce `unixorn/fzf-zsh-plugin`.
- fzf-tab, `Ctrl-T`, and `Alt-C` share preview and hidden-file state. `Ctrl-P`
  cycles preview right/down/hidden and `Ctrl-H` toggles hidden files.
- Completion generation is explicitly triggered with `Shift-Tab`; do not
  describe or implement it as automatic first-Tab generation.
- Edit persistent repository sources, not generated files or cache artifacts.

## Repository-specific validation and runtime checks

Do not use non-interactive shell startup as proof of ZLE, fzf, prompt, or
terminal behavior. Exercise the exact keys in a real PTY, preferably in the
Docker demo when the issue is Docker-specific.

For temporary macOS shell validation, use
`/Users/michele/Developer/z4u-next/fhome.sh` in a real PTY. This is Michele's
test HOME and launcher; do not use or recreate a repository-local `fhome.sh`
as a substitute.

Use the global validation rules and these repository-specific checks:

- All changes: `git diff --check` and final `git status --short`/diff review.
- POSIX installer: `sh -n install.sh`; run ShellCheck when available. Test
  installer branches with a disposable HOME and stubbed package managers
  rather than changing the host.
- Zsh sources: `/bin/zsh -n` on every modified Zsh file. For bindings,
  completion, previews, prompts, or widgets, also test in a real PTY through
  `/Users/michele/Developer/z4u-next/fhome.sh`.

For fzf binding validation, capture the output of these commands in that real
PTY:

```zsh
bindkey '^T'
bindkey '^[c'
print -r -- "$FZF_CTRL_T_OPTS"
print -r -- "$FZF_ALT_C_OPTS"
```

The reported widget names and option values must be consistent with the
bindings and fzf behavior defined by the repository sources; non-empty output
alone is not sufficient evidence.

- Dockerfile: `docker build --check .`, followed by the affected build mode:
  default remote build or `--build-arg DOTFILES_SOURCE=local`. Use a container
  smoke test when runtime behavior changes.
- README: verify code fences, commands, and local links against current source
  behavior.

If a required validation cannot run, state exactly what was skipped and do not
present the unverified behavior as confirmed.
